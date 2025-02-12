# Run Presets Bash Script

This Bash script provides a cross-platform GUI to manage and run custom shell commands with preset working directories. It uses Zenity on Linux and AppleScript on macOS, allowing you to add, remove, import, and save command presets with ease.

## Features

- **Cross-Platform Interface:** Uses Zenity (Linux) or AppleScript (macOS) for dialogs.
- **Preset Management:** Save, import, and load command presets.
- **Custom Commands:** Easily add commands that run in specified directories.
- **Config Persistence:** Stores custom commands in `~/.custom_commands` and presets in `~/.command_presets`.

## Prerequisites

- **Linux:** Ensure [Zenity](https://help.gnome.org/users/zenity/stable/) is installed.
- **macOS:** No additional installation needed (uses built-in AppleScript).

## Installation

1. Clone or download the project.
2. Ensure the script is executable:
   ```bash
   chmod +x run_presets.sh
