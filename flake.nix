{
  description = "Standalone test for Selenium host browser automation with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; }; # Good practice
        };

        # Helper script to find host browsers
        findBrowserScript = pkgs.writeShellScriptBin "find-browser" ''
          #!/usr/bin/env bash
          # set -e # Do not exit on error, allow script to report 'not found'
          BROWSER_NAME=$1
          OS_TYPE=$2 # "linux", "darwin", "wsl"

          HOST_PATH_VAR="HOST_$(echo "$BROWSER_NAME" | tr '[:lower:]' '[:upper:]')_PATH"
          HOST_PATH_VAL=$(printenv "$HOST_PATH_VAR" || true)
          if [[ -n "$HOST_PATH_VAL" && -x "$HOST_PATH_VAL" ]]; then echo "$HOST_PATH_VAL"; exit 0; fi

          if [[ "$OS_TYPE" == "darwin" ]]; then
            if [[ "$BROWSER_NAME" == "chrome" ]]; then
              FP="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; [[ -x "$FP" ]] && echo "$FP" && exit 0
              FP="$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; [[ -x "$FP" ]] && echo "$FP" && exit 0
            fi
          elif [[ "$OS_TYPE" == "linux" ]]; then
            if [[ "$BROWSER_NAME" == "chrome" ]]; then
              TMP_PATH=$(command -v google-chrome-stable || command -v google-chrome || command -v chromium-browser || command -v chromium 2>/dev/null)
              if [[ -n "$TMP_PATH" ]]; then echo "$TMP_PATH"; exit 0; fi
              # Fallback for Nix-provided chromium if not found by generic names by `command -v`
              # This relies on pkgs.chromium being available in the PATH where this script runs.
              # If this script is part of the devShell, pkgs.chromium path will be there.
              if [[ -x "${pkgs.chromium}/bin/chromium" ]]; then echo "${pkgs.chromium}/bin/chromium"; exit 0; fi
            fi
          elif [[ "$OS_TYPE" == "wsl" ]]; then
            if [[ "$BROWSER_NAME" == "chrome" ]]; then
              FP="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"; [[ -f "$FP" ]] && echo "$FP" && exit 0
              FP="/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"; [[ -f "$FP" ]] && echo "$FP" && exit 0
            fi
          fi
          exit 1 # Exit with error if not found, so Python script can check return code
        '';

        # Derivation for the Python test script itself
        testSeleniumPy = pkgs.stdenv.mkDerivation {
          name = "test-selenium-script";
          src = ./test_selenium.py; # Assumes test_selenium.py is in the same directory as flake.nix
          phases = [ "installPhase" ];
          installPhase = ''
            mkdir -p $out/bin
            cp $src $out/bin/test_selenium
            chmod +x $out/bin/test_selenium
          '';
        };

        # The package that sets up the environment and runs the test
        seleniumTestRunner = pkgs.stdenv.mkDerivation {
          name = "run-selenium-poc";
          
          # System dependencies needed to build/run the test environment
          # These are available when the `builder` script runs.
          buildInputs = with pkgs; [
            (python3.withPackages(ps: [ ps.selenium ]))
            coreutils # for mktemp, etc.
            bash      # for running the builder script

            # Tools for Selenium
            chromedriver
            chromium      # Fallback browser for chromedriver
            findBrowserScript
            zlib          # In case any pip package (even deps of selenium) needs it
            gcc           # For compiling any C extensions during pip install
          ];
          
          # This script is the "build" process for this derivation.
          # It sets up a venv, pip installs, and runs the test.
          builder = pkgs.writeShellScript "run-selenium-test.sh" ''
            source $stdenv/setup # Basic Nix build environment setup
            set -e o pipefail    # Exit on error, treat unset variables as an error

            echo "--- Starting Standalone Selenium Test Runner ---"

            # Ensure all buildInputs are available in PATH for this script
            export PATH="${pkgs.python3}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin:${pkgs.chromedriver}/bin:${pkgs.chromium}/bin:${findBrowserScript}/bin:$PATH"
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath (with pkgs; [ python3 coreutils bash chromedriver chromium findBrowserScript zlib gcc ])}:$LD_LIBRARY_PATH"


            # Determine EFFECTIVE_OS for find-browser (used by python script via os.environ)
            if [[ -n "$WSL_DISTRO_NAME" ]]; then
              export EFFECTIVE_OS="wsl"
            elif [[ "${system}" == *darwin* ]]; then # 'system' var is available to builder
              export EFFECTIVE_OS="darwin"
            elif [[ "${system}" == *linux* ]]; then
              export EFFECTIVE_OS="linux"
            else
              export EFFECTIVE_OS="unknown"
            fi
            echo "Builder: EFFECTIVE_OS set to $EFFECTIVE_OS"

            WORK_DIR=$(mktemp -d)
            echo "Builder: Working directory: $WORK_DIR"
            cd "$WORK_DIR"

            echo "Builder: Running the Selenium POC Python script..."
            # The python executable here is from the Nix environment with selenium installed
            python ${testSeleniumPy}/bin/test_selenium 
            
            echo "Builder: Selenium POC script finished."
            
            # Create a dummy output for Nix package requirements
            mkdir -p $out/bin
            cp ${testSeleniumPy}/bin/test_selenium $out/bin/standalone-selenium-test # Make it runnable
            echo "--- Test Runner Finished ---"
          '';
          
          # This derivation doesn't produce much beyond running the test.
          # The builder script itself is the "install phase".
          phases = [ "installPhase" ];
          installPhase = "$builder";
        };

      in
      {
        packages.default = self.outputs.packages.${system}.testBrowserSelenium; # `nix build .`
        packages.testBrowserSelenium = seleniumTestRunner;

        # `nix run .#testBrowserSelenium` or `nix run .`
        apps.default = flake-utils.lib.mkApp { drv = seleniumTestRunner; };
        apps.testBrowserSelenium = flake-utils.lib.mkApp { drv = seleniumTestRunner; };

        # A dev shell for interactive testing / venv setup
        devShells.default = pkgs.mkShell {
          name = "selenium-poc-devshell";
          packages = with pkgs; [
            (python3.withPackages(ps: [ ps.selenium ]))
            chromedriver
            chromium
            findBrowserScript
            zlib
            gcc
          ];
          shellHook = ''
            echo "Standalone Selenium POC Dev Shell"
            echo "Run: python ./test_selenium.py"
            
            if [[ -n "$WSL_DISTRO_NAME" ]]; then
              export EFFECTIVE_OS="wsl"
            elif [[ "${system}" == *darwin* ]]; then
              export EFFECTIVE_OS="darwin"
            elif [[ "${system}" == *linux* ]]; then
              export EFFECTIVE_OS="linux"
            else
              export EFFECTIVE_OS="unknown"
            fi
            echo "EFFECTIVE_OS for manual testing: $EFFECTIVE_OS"
            echo "WebDrivers (chromedriver) and find-browser are in PATH."
          '';
        };
      }
    );
} 