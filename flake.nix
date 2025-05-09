{
  description = "Platform-specific Selenium test environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Define platform-specific configurations
      mkConfig = system: let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
        };
        isDarwin = pkgs.stdenv.isDarwin;
        isLinux = pkgs.stdenv.isLinux;

        # Common packages for both platforms
        commonPackages = with pkgs; [
          python3Full
          coreutils
          bash
          zlib
          gcc
        ];

        # Linux-specific packages
        linuxPackages = with pkgs; [
          chromedriver
          chromium
        ];

        # Platform-specific shell configuration
        mkShell = pkgs.mkShell {
          name = "selenium-poc-devshell";
          packages = commonPackages ++ (if isLinux then linuxPackages else []);
          shellHook = ''
            echo "Standalone Selenium POC Dev Shell"
            
            test -d .venv || ${pkgs.python3}/bin/python -m venv .venv
            export VIRTUAL_ENV="$(pwd)/.venv"
            export PATH="$VIRTUAL_ENV/bin:$PATH"
            
            ${if isLinux then "export LD_LIBRARY_PATH=\"${pkgs.lib.makeLibraryPath linuxPackages}:$LD_LIBRARY_PATH\"" else ""}
            
            pip install --upgrade pip
            pip install selenium webdriver-manager
            
            export EFFECTIVE_OS="${if isDarwin then "darwin" else "linux"}"
            echo "EFFECTIVE_OS for manual testing: $EFFECTIVE_OS"
            echo "Run: python ./test_selenium.py"
          '';
        };

        # Platform-specific package configuration
        mkPackage = pkgs.stdenv.mkDerivation {
          name = "run-selenium-poc";
          buildInputs = commonPackages ++ (if isLinux then linuxPackages else []);
          builder = pkgs.writeShellScript "run-selenium-test.sh" ''
            source $stdenv/setup
            set -e o pipefail

            echo "--- Starting ${if isDarwin then "Mac" else "Linux"} Selenium Test Runner ---"

            export PATH="${pkgs.python3}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin:$PATH"
            ${if isLinux then "export PATH=\"${pkgs.chromedriver}/bin:${pkgs.chromium}/bin:$PATH\"" else ""}
            ${if isLinux then "export LD_LIBRARY_PATH=\"${pkgs.lib.makeLibraryPath linuxPackages}:$LD_LIBRARY_PATH\"" else ""}

            export EFFECTIVE_OS="${if isDarwin then "darwin" else "linux"}"
            WORK_DIR=$(mktemp -d)
            cd "$WORK_DIR"
            python ${./test_selenium.py}
            mkdir -p $out/bin
            cp ${./test_selenium.py} $out/bin/standalone-selenium-test
          '';
          phases = [ "installPhase" ];
          installPhase = "$builder";
        };

      in {
        packages = {
          default = mkPackage;
          testBrowserSelenium = mkPackage;
        };
        apps = {
          default = flake-utils.lib.mkApp { drv = mkPackage; };
          testBrowserSelenium = flake-utils.lib.mkApp { drv = mkPackage; };
        };
        devShells = {
          default = mkShell;
        };
      };

    in
    flake-utils.lib.eachDefaultSystem (system:
      mkConfig system
    );
} 