#!/bin/bash
# filepath: /home/jorran/Desktop/run_presets.sh

CONFIG_FILE="$HOME/.custom_commands"
PRESETS_DIR="$HOME/.command_presets"

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'   # No Color

# Create presets directory if it doesn't exist
mkdir -p "$PRESETS_DIR"

# Detect the OS
OS=$(uname)

# Function to prompt the user to select a directory using Zenity or osascript
select_directory() {
    local title="$1"
    if [ "$OS" = "Darwin" ]; then
        directory=$(osascript <<EOF
tell application "Finder"
    set selectedFolder to choose folder with prompt "$title"
    POSIX path of selectedFolder
end tell
EOF
)
        echo "$directory"
    else
        zenity --file-selection --directory --title="$title" 2>/dev/null
    fi
}

# Function to save custom commands to the config file
save_config() {
    # Save the CUSTOM_COMMANDS variable while preserving newlines
    printf "CUSTOM_COMMANDS=%q\n" "$CUSTOM_COMMANDS" > "$CONFIG_FILE"
}

# Function to add a custom command along with a directory where it should run
add_command() {
    local custom_command directory full_command
    if [ "$OS" = "Darwin" ]; then
        custom_command=$(osascript -e 'tell application "System Events" to display dialog "Enter the command to run:" default answer ""' -e 'text returned of result' 2>/dev/null)
    else
        custom_command=$(zenity --entry --title="Add Custom Command" --text="Enter the command to run:" 2>/dev/null)
    fi
    if [ -n "$custom_command" ]; then
        directory=$(select_directory "Select directory for the custom command")
        if [ -n "$directory" ]; then
            full_command="cd \"$directory\" && $custom_command"
            if [ -z "$CUSTOM_COMMANDS" ]; then
                CUSTOM_COMMANDS="${full_command}"
            else
                CUSTOM_COMMANDS="${CUSTOM_COMMANDS}"$'\n'"${full_command}"
            fi
            save_config
        else
            if [ "$OS" = "Darwin" ]; then
                osascript -e 'display dialog "No directory selected. Command not added." buttons {"OK"} default button 1 with icon caution'
            else
                zenity --error --text="No directory selected. Command not added." 2>/dev/null
            fi
        fi
    fi
    select_commands_to_run
}

# Function to import a preset from a user-selected file
import_preset() {
    local file preset_content
    if [ "$OS" = "Darwin" ]; then
        file=$(osascript -e 'tell application "System Events" to display dialog "Select a preset file to import (enter full path):" default answer ""' -e 'text returned of result' 2>/dev/null)
    else
        file=$(zenity --file-selection --title="Select a Preset File to Import" 2>/dev/null)
    fi
    if [ -n "$file" ]; then
        if [ -f "$file" ]; then
            preset_content=$(cat "$file")
            if [ "$OS" = "Darwin" ]; then
                response=$(osascript -e 'display dialog "Overwrite current commands with the imported preset?" buttons {"No", "Yes"} default button "Yes"' -e 'button returned of result')
                if [ "$response" = "Yes" ]; then
                    CUSTOM_COMMANDS="$preset_content"
                else
                    CUSTOM_COMMANDS="${CUSTOM_COMMANDS}"$'\n'"${preset_content}"
                fi
            else
                if zenity --question --title="Import Preset" --text="Overwrite current commands with the imported preset?" 2>/dev/null; then
                    CUSTOM_COMMANDS="$preset_content"
                else
                    CUSTOM_COMMANDS="${CUSTOM_COMMANDS}"$'\n'"${preset_content}"
                fi
            fi
            save_config
            if [ "$OS" = "Darwin" ]; then
                osascript -e 'display dialog "Preset imported successfully." buttons {"OK"} default button 1'
            else
                zenity --info --text="Preset imported successfully." 2>/dev/null
            fi
        else
            if [ "$OS" = "Darwin" ]; then
                osascript -e 'display dialog "Selected file not found." buttons {"OK"} default button 1 with icon caution'
            else
                zenity --error --text="Selected file not found." 2>/dev/null
            fi
        fi
    fi
}

# Function to save current custom commands as a preset
save_preset() {
    local preset_name preset_file
    if [ "$OS" = "Darwin" ]; then
        preset_name=$(osascript -e 'tell application "System Events" to display dialog "Enter a name for this preset:" default answer ""' -e 'text returned of result' 2>/dev/null)
    else
        preset_name=$(zenity --entry --title="Save Preset" --text="Enter a name for this preset:" 2>/dev/null)
    fi
    if [ -n "$preset_name" ]; then
        preset_file="$PRESETS_DIR/${preset_name}.preset"
        echo "$CUSTOM_COMMANDS" > "$preset_file"
        if [ "$OS" = "Darwin" ]; then
            osascript -e "display dialog \"Preset saved as '$preset_name'.\" buttons {\"OK\"} default button \"OK\""
        else
            zenity --info --text="Preset saved as '$preset_name'." 2>/dev/null
        fi
    fi
}

# Function to select and load a preset from saved presets
select_preset() {
    local preset_file preset_content selected_preset
    local -a preset_names=()
    while IFS= read -r line; do
        preset_names+=("$line")
    done < <(find "$PRESETS_DIR" -maxdepth 1 -type f -name "*.preset" -exec basename {} .preset \; 2>/dev/null)

    if [ "${#preset_names[@]}" -eq 0 ]; then
        if [ "$OS" = "Darwin" ]; then
            osascript -e 'display dialog "No presets found. Please save a preset first." buttons {"OK"} default button 1'
        else
            zenity --info --text="No presets found. Please save a preset first." 2>/dev/null
        fi
        return
    fi

    if [ "$OS" = "Darwin" ]; then
        IFS=$'\n' preset_list="${preset_names[*]}"
        selected_preset=$(osascript <<EOF
set theList to paragraphs of "$preset_list"
choose from list theList with prompt "Select a preset to load:" without multiple selections allowed
EOF
)
        selected_preset=$(echo "$selected_preset" | tr -d ',')
    else
        selected_preset=$(zenity --list --title="Select Preset" --text="Select a preset to load:" --column="Preset" "${preset_names[@]}" 2>/dev/null)
    fi

    if [ -n "$selected_preset" ] && [ "$selected_preset" != "false" ]; then
        preset_file="$PRESETS_DIR/${selected_preset}.preset"
        if [ -f "$preset_file" ]; then
            preset_content=$(cat "$preset_file")
            if [ "$OS" = "Darwin" ]; then
                response=$(osascript -e "display dialog \"Overwrite current commands with preset '$selected_preset'?\" buttons {\"No\", \"Yes\"} default button \"Yes\"" -e 'button returned of result')
                if [ "$response" = "Yes" ]; then
                    CUSTOM_COMMANDS="$preset_content"
                else
                    CUSTOM_COMMANDS="${CUSTOM_COMMANDS}"$'\n'"${preset_content}"
                fi
            else
                if zenity --question --title="Load Preset" --text="Overwrite current commands with preset '$selected_preset'?" 2>/dev/null; then
                    CUSTOM_COMMANDS="$preset_content"
                else
                    CUSTOM_COMMANDS="${CUSTOM_COMMANDS}"$'\n'"${preset_content}"
                fi
            fi
            SELECTED_PRESET="$selected_preset"
            save_config
            if [ "$OS" = "Darwin" ]; then
                osascript -e "display dialog \"Preset '$selected_preset' loaded successfully.\" buttons {\"OK\"} default button \"OK\""
            else
                zenity --info --text="Preset '$selected_preset' loaded successfully." 2>/dev/null
            fi
        else
            if [ "$OS" = "Darwin" ]; then
                osascript -e 'display dialog "Preset file not found." buttons {"OK"} default button 1 with icon caution'
            else
                zenity --error --text="Preset file not found." 2>/dev/null
            fi
        fi
    fi
}

# Function to display the preset management menu
manage_presets() {
    local choice
    if [ "$OS" = "Darwin" ]; then
        choice=$(osascript -e 'set theChoice to button returned of (display dialog "Select a preset action:" buttons {"Select Preset", "Import Preset", "Save Preset"} default button "Select Preset")' 2>/dev/null)
    else
        choice=$(zenity --list --title="Preset Management" --text="Select a preset action:" --column="Option" "Select Preset" "Import Preset" "Save Preset" 2>/dev/null)
    fi
    case "$choice" in
        "Select Preset")
            select_preset
            ;;
        "Import Preset")
            import_preset
            ;;
        "Save Preset")
            save_preset
            ;;
        *)
            ;;
    esac
    select_commands_to_run
}

# Function to parse a full command and extract the directory and the actual command
# Assumes format: cd "directory" && <command>
parse_command() {
    local full_command="$1"
    local dir="" cmd=""
    local regex='^cd\ "([^"]+)"[[:space:]]*&&[[:space:]]*(.+)$'
    if [[ $full_command =~ $regex ]]; then
        dir="${BASH_REMATCH[1]}"
        cmd="${BASH_REMATCH[2]}"
    else
        cmd="$full_command"
    fi
    echo "$cmd|||$dir"
}

# Modified select_commands_to_run for Darwin using AppleScript as a Zenity-like interface.
select_commands_to_run() {
    if [ "$OS" = "Darwin" ]; then
        # Build an array with extra actions and the list items
        local -a fullCommands=() index=0 listItems=()
        IFS=$'\n' read -rd '' -a fullCommands <<< "$CUSTOM_COMMANDS"
        for line in "${fullCommands[@]}"; do
            [ -z "$line" ] && continue
            parsed=$(parse_command "$line")
            cmd="${parsed%%|||*}"
            path="${parsed#*|||}"
            listItems+=( "$index) $cmd [$path]" )
            index=$((index+1))
        done
        # Append extra actions
        listItems+=( "Add Command" "Remove Command" "Manage Presets" )
        # Show choose-from-list dialog (allows multiple selection)
        selected=$(osascript <<EOF
set listItems to {$(printf '"%s", ' "${listItems[@]}" | sed 's/, $//')}
set chosen to choose from list listItems with prompt "Select commands to run (multiple selections allowed):" with multiple selections allowed
if chosen is false then return ""
return chosen as string
EOF
)
        # Process selection: if empty, exit
        if [ -z "$selected" ]; then
            exit 0
        fi
        # Handle actions if any extra button was picked (assuming user picks one extra action at a time)
        if [[ "$selected" == *"Add Command"* ]]; then
            add_command
            return
        elif [[ "$selected" == *"Manage Presets"* ]]; then
            manage_presets
            return
        elif [[ "$selected" == *"Remove Command"* ]]; then
            delete_commands_window
            return
        fi
        # Replace splitting to use comma as separator and trim whitespace
        IFS=',' read -ra chosenItems <<< "$selected"
        for item in "${chosenItems[@]}"; do
            item=$(echo "$item" | xargs)  # trim whitespace
            idx=$(echo "$item" | cut -d')' -f1)
            full_cmd="${fullCommands[$idx]}"
            if [ -n "$full_cmd" ]; then
                # Remove "in front window" so that new terminal windows open for each command
                osascript -e "tell application \"Terminal\" to do script \"${full_cmd//\"/\\\"}; exit\""
            fi
        done
        select_commands_to_run
    else
        # ...existing Linux code...
        local options=() CHOICES
        local -a fullCommands=()
        local IFS_old="$IFS" index=0 line parsed cmd path
        local selected_preset_label="Selected Preset: ${SELECTED_PRESET:-None}"
        IFS=$'\n' read -rd '' -a fullCommands <<< "$CUSTOM_COMMANDS"
        IFS="$IFS_old"
        for line in "${fullCommands[@]}"; do
            [ -z "$line" ] && continue
            parsed=$(parse_command "$line")
            cmd="${parsed%%|||*}"
            path="${parsed#*|||}"
            options+=( "TRUE" "$index" "$cmd" "$path" )
            index=$((index + 1))
        done
        CHOICES=$(zenity --list --checklist --print-column=2 \
            --title="Custom Commands" \
            --text="$selected_preset_label\n\nSelect commands to run:" \
            --column="" --column="ID" --column="Command" --column="Path" \
            --width=1200 --height=600 \
            "${options[@]}" \
            --extra-button="Add Command" \
            --extra-button="Remove Command" \
            --extra-button="Manage Presets" \
            --separator="|" 2>/dev/null)
      
        if [ "$CHOICES" == "Add Command" ]; then
            add_command
            return
        elif [ "$CHOICES" == "Manage Presets" ]; then
            manage_presets
            return
        elif [ "$CHOICES" == "Remove Command" ]; then
            delete_commands_window
            return
        fi
      
        [ -z "$CHOICES" ] && exit 0
        IFS='|' read -ra selectedIDs <<< "$CHOICES"
        for id in "${selectedIDs[@]}"; do
            full_cmd="${fullCommands[$id]}"
            [ -n "$full_cmd" ] && gnome-terminal --tab -- bash -c "$(printf "%s; exec bash" "$full_cmd")"
        done
        select_commands_to_run
    fi
}

# Modified delete_commands_window for Darwin using a Zenity-like AppleScript interface.
delete_commands_window() {
    if [ "$OS" = "Darwin" ]; then
        local -a fullCommands=() listItems=() index=0
        IFS=$'\n' read -rd '' -a fullCommands <<< "$CUSTOM_COMMANDS"
        for line in "${fullCommands[@]}"; do
            [ -z "$line" ] && continue
            parsed=$(parse_command "$line")
            cmd="${parsed%%|||*}"
            path="${parsed#*|||}"
            listItems+=( "$index) $cmd [$path]" )
            index=$((index+1))
        done
        selected=$(osascript <<EOF
set listItems to {$(printf '"%s", ' "${listItems[@]}" | sed 's/, $//')}
set chosen to choose from list listItems with prompt "Select commands to remove (multiple selections allowed):" with multiple selections allowed
if chosen is false then return ""
return chosen as string
EOF
)
        # If no selection, do nothing
        if [ -z "$selected" ]; then
            select_commands_to_run
            return
        fi
        # Parse selection; filter out chosen indices.
        IFS=", " read -ra chosenItems <<< "$selected"
        local newCommands=() idx
        for idx in "${!fullCommands[@]}"; do
            skip=0
            for item in "${chosenItems[@]}"; do
                sel_index=$(echo "$item" | cut -d')' -f1)
                if [ "$idx" -eq "$sel_index" ]; then
                    skip=1
                    break
                fi
            done
            [ $skip -eq 0 ] && newCommands+=( "${fullCommands[$idx]}" )
        done
        # If no commands remain, explicitly reset CUSTOM_COMMANDS
        if [ ${#newCommands[@]} -eq 0 ]; then
            CUSTOM_COMMANDS=""
        else
            CUSTOM_COMMANDS=$(printf "%s\n" "${newCommands[@]}")
        fi
        save_config
        osascript -e 'display dialog "Selected commands removed." buttons {"OK"} default button "OK"'
        select_commands_to_run
    else
        # ...existing Linux code...
        local options=() CHOICES
        local -a fullCommands=()
        local IFS_old="$IFS" index=0 line parsed cmd path
        IFS=$'\n' read -rd '' -a fullCommands <<< "$CUSTOM_COMMANDS"
        IFS="$IFS_old"
        for line in "${fullCommands[@]}"; do
            [ -z "$line" ] && continue
            parsed=$(parse_command "$line")
            cmd="${parsed%%|||*}"
            path="${parsed#*|||}"
            options+=( "$index" "$cmd" "$path" )
            index=$((index + 1))
        done
        CHOICES=$(zenity --list --checklist --print-column=1 \
            --title="Delete Commands" \
            --text="Select commands to delete:" \
            --column="ID" --column="Command" --column="Path" \
            "${options[@]}" \
            --separator="|" 2>/dev/null)
        [ -z "$CHOICES" ] && exit 0
        local newCommands=() removeFlag
        IFS='|' read -ra removeIDs <<< "$CHOICES"
        for idx in "${!fullCommands[@]}"; do
            removeFlag=0
            for rem in "${removeIDs[@]}"; do
                if [ "$idx" -eq "$rem" ]; then
                    removeFlag=1
                    break
                fi
            done
            [ $removeFlag -eq 0 ] && newCommands+=( "${fullCommands[$idx]}" )
        done
        CUSTOM_COMMANDS=$(printf "%s\n" "${newCommands[@]}" | sed '/^$/d')
        save_config
        zenity --info --text="Selected commands removed." 2>/dev/null
        select_commands_to_run
    fi
}

# Load custom commands from config file if it exists; otherwise, initialize as empty
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    CUSTOM_COMMANDS=""
fi

select_commands_to_run