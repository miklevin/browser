# NixOS & Selenium: Reliable Host Browser Automation with Nix Flakes

A standalone proof-of-concept demonstrating reliable browser automation on NixOS using Selenium and Nix Flakes. This project shows how to control either a user's pre-installed Chrome/Chromium or a Nix-provided Chromium using Selenium 4.x, with Nix managing the WebDriver dependencies.

## Features

- 🔍 Smart browser detection across Linux, macOS, and WSL
- 🔄 Fallback to Nix-provided Chromium if no host browser is found
- 🛡️ Proper handling of browser profiles and sandbox settings
- 🧪 Clean, isolated test environment using Nix Flakes
- 🔧 Cross-platform support (Linux, macOS, WSL)

## Quick Start

1. Clone this repository:
   ```bash
   git clone <your-repo-url>
   cd browser
   ```

2. Run the test:
   ```bash
   nix run .
   ```

   Or enter the development shell:
   ```bash
   nix develop
   python test_selenium.py
   ```

## How It Works

The project consists of two main components:

1. **`flake.nix`**: Sets up the Nix environment with:
   - Python with Selenium
   - ChromeDriver
   - A helper script for finding host browsers
   - Fallback Chromium browser

2. **`test_selenium.py`**: A Python script that:
   - Detects available browsers using the `find-browser` helper
   - Configures Chrome options for reliable automation
   - Runs a simple test navigating to example.com
   - Handles cleanup of temporary browser profiles

## Browser Detection

The system will try to find a browser in this order:
1. User-specified path via environment variable (e.g., `HOST_CHROME_PATH`)
2. Common system locations for Chrome/Chromium
3. Nix-provided Chromium as a fallback

## Development

To modify or extend the project:

1. Enter the development shell:
   ```bash
   nix develop
   ```

2. The environment provides:
   - Python with Selenium
   - ChromeDriver
   - The `find-browser` helper script
   - All necessary system dependencies

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 