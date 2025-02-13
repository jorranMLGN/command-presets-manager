#!/bin/bash

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

# --- Helper Functions for Dialogs ---
get_user_input() {
    local title="$1"
    local prompt="$2"
    local result=""
    if [ "$OS" = "Darwin" ]; then
        result=$(osascript -e "tell application \"System Events\" to display dialog \"$prompt\" default answer \"\"" -e 'text returned of result' 2>/dev/null)
    else
        result=$(zenity --entry --title="$title" --text="$prompt" 2>/dev/null)
    fi
    echo "$result"
}

display_info() {
    local title="$1"
    local message="$2"
    if [ "$OS" = "Darwin" ]; then
        osascript -e "display dialog \"$message\" buttons {\"OK\"} default button \"OK\"" 2>/dev/null
    else
        zenity --info --title="$title" --text="$message" 2>/dev/null
    fi
}

display_error() {
    local title="$1"
    local message="$2"
    if [ "$OS" = "Darwin" ]; then
        osascript -e "display dialog \"$message\" buttons {\"OK\"} default button \"OK\" with icon caution" 2>/dev/null
    else
        zenity --error --title="$title" --text="$message" 2>/dev/null
    fi
}

ask_question() {
    local title="$1"
    local question="$2"
    if [ "$OS" = "Darwin" ]; then
        response=$(osascript -e "display dialog \"$question\" buttons {\"No\", \"Yes\"} default button \"Yes\"" -e 'button returned of result' 2>/dev/null)
        [ "$response" = "Yes" ] && return 0 || return 1
    else
        zenity --question --title="$title" --text="$question" 2>/dev/null
        return $?
    fi
}
# --- End Helper Functions ---

# Function to prompt the user to select a directory using Zenity or osascript
select_directory() {
    local title="$1"
    local directory=""
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
    local custom_command directory full_command result dir_input status
    if [ "$OS" = "Darwin" ]; then
        # macOS branch remains unchanged
        while true; do
            result=$(osascript <<'EOF'
set dialogResult to display dialog "Enter the custom command and directory path separated by a newline:" default answer "" buttons {"Browse", "OK", "Cancel"} default button "OK"
if button returned of dialogResult is "Browse" then
    set chosenFolder to choose folder with prompt "Select Directory"
    set dirPath to POSIX path of chosenFolder
    set currentText to text returned of dialogResult
    display dialog "Enter the custom command and directory path separated by a newline:" default answer (currentText & return & dirPath) buttons {"OK", "Cancel"} default button "OK"
    return result
else
    return text returned of dialogResult
end if
EOF
)
            if [ $? -ne 0 ] || [ -z "$result" ]; then
                select_commands_to_run
                return
            fi
            custom_command="${result%%|||*}"
            directory="${result#*|||}"
            custom_command=$(printf "%s" "$custom_command" | head -n1)
            directory=$(printf "%s" "$directory" | tail -n1)
            if [ -n "$custom_command" ] && [ -n "$directory" ]; then
                break
            else
                osascript -e 'display dialog "Both command and directory must be provided. Please try again." buttons {"OK"} default button "OK"'
            fi
        done
    else
        # Linux branch using zenity forms with an extra Browse button.
        while true; do
            result=$(zenity --forms --title="Add Custom Command 🚀" \
                --text="Enter both the command and the directory path:" \
                --add-entry="Command to run" \
                --add-entry="Directory path" \
                --extra-button="Browse Directory" 2>/dev/null)
            status=$?
            # First, check if the extra button was pressed.
            if [ "$result" = "Browse Directory" ]; then
                directory=$(zenity --file-selection --directory --title="Select Directory" 2>/dev/null)
                if [ -z "$directory" ]; then
                    continue
                fi
                # Reopen the form, showing the chosen directory in the prompt.
                result=$(zenity --forms --title="Add Custom Command 🚀" \
                    --text="Enter both the command and the directory path:\n[Chosen Directory: $directory]\nLeave the Directory field empty to use selected directory." \
                    --add-entry="Command to run" \
                    --add-entry="Directory path" 2>/dev/null)
                status=$?
                if [ $status -ne 0 ]; then
                    select_commands_to_run
                    return
                fi
                custom_command=$(echo "$result" | cut -d'|' -f1)
                dir_input=$(echo "$result" | cut -d'|' -f2)
                if [ -z "$dir_input" ]; then
                    directory="$directory"
                else
                    directory="$dir_input"
                fi
            elif [ $status -ne 0 ]; then
                # If the form was canceled (and not via extra button) return to main menu.
                select_commands_to_run
                return
            else
                custom_command=$(echo "$result" | cut -d'|' -f1)
                directory=$(echo "$result" | cut -d'|' -f2)
                if [ -z "$directory" ]; then
                    directory=$(zenity --file-selection --directory --title="Select Directory" 2>/dev/null)
                fi
            fi
            if [ -n "$custom_command" ] && [ -n "$directory" ]; then
                break
            else
                display_error "Add Command" "❌ Both command and directory must be provided. Please try again."
            fi
        done
    fi

    full_command="cd \"$directory\" && $custom_command"
    if [ -z "$CUSTOM_COMMANDS" ]; then
        CUSTOM_COMMANDS="${full_command}"
    else
        CUSTOM_COMMANDS="${CUSTOM_COMMANDS}"$'\n'"${full_command}"
    fi
    save_config
    select_commands_to_run
}

# Function to import a preset from a user-selected file
import_preset() {
    local file preset_content response
    if [ "$OS" = "Darwin" ]; then
        file=$(get_user_input "Import Preset 📥" "Enter full path of the preset file to import:")
    else
        file=$(zenity --file-selection --title="Select a Preset File to Import 📥" 2>/dev/null)
    fi
    if [ -n "$file" ]; then
        if [ -f "$file" ]; then
            preset_content=$(cat "$file")
            if ask_question "Import Preset" "Overwrite current commands with the imported preset? ⚠️"; then
                CUSTOM_COMMANDS="$preset_content"
            else
                CUSTOM_COMMANDS="${CUSTOM_COMMANDS}"$'\n'"${preset_content}"
            fi
            save_config
            display_info "Import Preset" "✅ Preset imported successfully."
        else
            display_error "Import Preset" "❌ Selected file not found."
        fi
    fi
}

# Function to save current custom commands as a preset
save_preset() {
    local preset_name preset_file
    preset_name=$(get_user_input "Save Preset 💾" "Enter a name for this preset:")
    if [ -n "$preset_name" ]; then
        preset_file="$PRESETS_DIR/${preset_name}.preset"
        echo "$CUSTOM_COMMANDS" > "$preset_file"
        display_info "Save Preset" "✅ Preset saved as '$preset_name'."
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
        display_info "Select Preset" "No presets found. Please save a preset first."
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
        selected_preset=$(zenity --list --title="Select Preset 💠" --text="Select a preset to load:" --column="Preset" "${preset_names[@]}" 2>/dev/null)
    fi

    if [ -n "$selected_preset" ] && [ "$selected_preset" != "false" ]; then
        preset_file="$PRESETS_DIR/${selected_preset}.preset"
        if [ -f "$preset_file" ]; then
            preset_content=$(cat "$preset_file")
            if ask_question "Load Preset" "Overwrite current commands with preset '$selected_preset'? ⚠️"; then
                CUSTOM_COMMANDS="$preset_content"
            else
                CUSTOM_COMMANDS="${CUSTOM_COMMANDS}"$'\n'"${preset_content}"
            fi
            SELECTED_PRESET="$selected_preset"
            save_config
            display_info "Select Preset" "✅ Preset '$selected_preset' loaded successfully."
        else
            display_error "Select Preset" "❌ Preset file not found."
        fi
    fi
}

# New function to remove a preset
remove_preset() {
    local preset_file selected_preset
    local -a preset_names=()
    while IFS= read -r line; do
        preset_names+=("$line")
    done < <(find "$PRESETS_DIR" -maxdepth 1 -type f -name "*.preset" -exec basename {} .preset \; 2>/dev/null)

    if [ ${#preset_names[@]} -eq 0 ]; then
        display_info "Remove Preset" "No presets found to remove."
        return
    fi

    if [ "$OS" = "Darwin" ]; then
        IFS=$'\n' preset_list="${preset_names[*]}"
        selected_preset=$(osascript <<EOF
set theList to paragraphs of "$preset_list"
choose from list theList with prompt "Select a preset to remove:" without multiple selections allowed
EOF
)
        selected_preset=$(echo "$selected_preset" | tr -d ',')
    else
        selected_preset=$(zenity --list --title="Remove Preset ❌" --text="Select a preset to remove:" --column="Preset" "${preset_names[@]}" 2>/dev/null)
    fi

    if [ -n "$selected_preset" ] && [ "$selected_preset" != "false" ]; then
        preset_file="$PRESETS_DIR/${selected_preset}.preset"
        if [ -f "$preset_file" ]; then
            rm -f "$preset_file"
            display_info "Remove Preset" "Preset '$selected_preset' has been removed."
        else
            display_error "Remove Preset" "Preset file not found."
        fi
    fi
}

# Function to display the preset management menu
manage_presets() {
    local choice
    if [ "$OS" = "Darwin" ]; then
        choice=$(osascript -e 'set theChoice to button returned of (display dialog "Select a preset action:" buttons {"Select Preset 🔄", "Import Preset 📥", "Save Preset 💾", "Remove Preset ❌"} default button "Select Preset 🔄")' 2>/dev/null)
    else
        choice=$(zenity --list --title="Preset Management 🎛️" --text="Select a preset action:" --column="Option" "Select Preset 🔄" "Import Preset 📥" "Save Preset 💾" "Remove Preset ❌" 2>/dev/null)
    fi
    case "$choice" in
        "Select Preset 🔄")
            select_preset
            ;;
        "Import Preset 📥")
            import_preset
            ;;
        "Save Preset 💾")
            save_preset
            ;;
        "Remove Preset ❌")
            remove_preset
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

# Modified select_commands_to_run with a unified loop approach using helper functions.
select_commands_to_run() {
    if [ "$OS" = "Darwin" ]; then
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
        # Append extra actions with emojis
        listItems+=( "Add Command ➕" "Remove Command ❌" "Manage Presets ⚙️" )
        selected=$(osascript <<EOF
set listItems to {$(printf '"%s", ' "${listItems[@]}" | sed 's/, $//')}
set chosen to choose from list listItems with prompt "Select commands to run (multiple selections allowed):" with multiple selections allowed
if chosen is false then return ""
return chosen as string
EOF
)
        [ -z "$selected" ] && exit 0
        if [[ "$selected" == *"Add Command ➕"* ]]; then
            add_command
            return
        elif [[ "$selected" == *"Manage Presets ⚙️"* ]]; then
            manage_presets
            return
        elif [[ "$selected" == *"Remove Command ❌"* ]]; then
            delete_commands_window
            return
        fi
        IFS=',' read -ra chosenItems <<< "$selected"
        for item in "${chosenItems[@]}"; do
            item=$(echo "$item" | xargs)
            idx=$(echo "$item" | cut -d')' -f1)
            full_cmd="${fullCommands[$idx]}"
            if [ -n "$full_cmd" ]; then
                osascript -e "tell application \"Terminal\" to do script \"${full_cmd//\"/\\\"}; exit\""
            fi
        done
        select_commands_to_run
    else
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
            --title="Command Manager 🚀" \
            --text="$selected_preset_label\n\nSelect commands to run:" \
            --column="" --column="ID" --column="Command" --column="Path" \
            --width=1200 --height=600 \
            "${options[@]}" \
            --extra-button="Add Command ➕" \
            --extra-button="Remove Command ❌" \
            --extra-button="Manage Presets ⚙️" \
            --separator="|" 2>/dev/null)
      
        if [ "$CHOICES" == "Add Command ➕" ]; then
            add_command
            return
        elif [ "$CHOICES" == "Manage Presets ⚙️" ]; then
            manage_presets
            return
        elif [ "$CHOICES" == "Remove Command ❌" ]; then
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

# Modified delete_commands_window using helper functions.
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
set chosen to choose from list listItems with prompt "Select commands to remove ❌ (multiple selections allowed):" with multiple selections allowed
if chosen is false then return ""
return chosen as string
EOF
)
        [ -z "$selected" ] && { select_commands_to_run; return; }
        IFS=", " read -ra chosenItems <<< "$selected"
        local newCommands=()
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
        if [ ${#newCommands[@]} -eq 0 ]; then
            CUSTOM_COMMANDS=""
        else
            CUSTOM_COMMANDS=$(printf "%s\n" "${newCommands[@]}")
        fi
        save_config
        display_info "Delete Commands" "Selected commands removed."
        select_commands_to_run
    else
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
            --title="Delete Commands ❌" \
            --text="Select commands to delete:" \
            --column="ID" --column="Command" --column="Path" \
            "${options[@]}" \
            --separator="|" 2>/dev/null)
        [ -z "$CHOICES" ] && exit 0
        local newCommands=()
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
        display_info "Delete Commands" "Selected commands removed."
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
