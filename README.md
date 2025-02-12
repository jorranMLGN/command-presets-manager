
# Multiple Pre-configured Commands Running in 1 click 🚀

This Bash script provides a cross-platform GUI to manage and run custom shell commands with preset working directories. It uses Zenity on Linux and AppleScript on macOS, allowing you to add, remove, import, and save command presets with ease. 🖥️💻

## Features ✨

- **Cross-Platform Interface:** Uses Zenity (Linux) or AppleScript (macOS) for dialogs. 🌍
- **Preset Management:** Save, import, and load command presets. 🔧
- **Custom Commands:** Easily add commands that run in specified directories. 🗂️
- **Config Persistence:** Stores custom commands in `~/.custom_commands` and presets in `~/.command_presets`. 💾

## Prerequisites 📋

- **Linux:** Ensure [Zenity](https://help.gnome.org/users/zenity/stable/) is installed. 🐧
- **macOS:** No additional installation needed (uses built-in AppleScript). 🍏

## Installation 🛠️

1. Clone or download the project. 📥
2. Ensure the script is executable:
```bash
chmod +x command-manager.sh
```
3. (Optional) Move the script to a directory in your PATH for easy access. 📂

## Usage 🏃‍♂️

Run the script directly from your terminal:
```bash
./command-manager.sh
```
Follow the on-screen prompts to add, manage, or remove custom commands and presets. 👨‍💻

### Alias 🔄

1. If you want to use a different command to start it, you can add an alias:
```bash
gedit ~/.bashrc
```
2. Add this at the end of the file:
```
alias command-manager='/home/<full path to script>/command-manager.sh'
```
3. Open a new terminal session or type ```source ~/.bashrc``` in your terminal to apply.

4. Then simply type "command-manager" in your terminal to start the script from everywhere. 🌍

## Configuration ⚙️

* Custom commands are stored in `~/.custom_commands`. 📁
* Presets are saved in the directory `~/.command_presets`. 📂

## License 📜

This project is provided "as is" without warranty of any kind. ⚖️
