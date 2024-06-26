# @yaml
# signature: choose_lines <start_line>:<end_line>
# docstring: choose lines <start_line> through <end_line> (inclusive) to edit.
# arguments:
#   start_line:
#     type: integer
#     description: the line number to start the selection at
#     required: true
#   end_line:
#     type: integer
#     description: the line number to end the selection at (inclusive)
#     required: true
choose_lines() {
    if [ -z "$CURRENT_FILE" ]; then
        echo 'No file open. Use the `open` command first.'
        return
    fi

    local start_line="$(echo $1: | cut -d: -f1)"
    local end_line="$(echo $1: | cut -d: -f2)"

    if [ -z "$start_line" ] || [ -z "$end_line" ]; then
        echo "Usage: choose_lines <start_line>:<end_line>"
        return
    fi

    local re='^[0-9]+$'
    if ! [[ $start_line =~ $re ]]; then
        echo "Usage: choose_lines <start_line>:<end_line>"
        echo "Error: start_line must be a number"
        return
    fi
    if ! [[ $end_line =~ $re ]]; then
        echo "Usage: choose_lines <start_line>:<end_line>"
        echo "Error: end_line must be a number"
        return
    fi

    echo "Selected lines ${start_line}:${end_line}, lines you selected are follow:"

    # Bash array starts at 0, so let's adjust
    start_line=$((start_line - 1))
    end_line=$((end_line))

    # Read the file line by line into an array
    mapfile -t lines < "$CURRENT_FILE"

    # Output the selected lines
    echo "edit"
    for ((i=start_line; i<end_line; i++)); do
        echo "${lines[i]}"
    done
    echo "end_of_edit"
    echo ""
    echo "TIPS: 1) If you selected the wrong lines, use \`choose_lines\` again to adjust. 2) \`edit\` to replace the lines above."

    export SELECTED_START_LINE=$start_line
    export SELECTED_END_LINE=$end_line
}

# @yaml
# signature: |-
#   edit
#   <replacement_text>
#   end_of_edit
# docstring: replaces the lines previously chosen with the `choose_lines` command with the given text. The replacement text is terminated by a line with only end_of_edit on it. All of the <replacement_text> will be entered, so make sure your indentation is formatted properly. Python files will be checked for syntax errors after the edit. If the system detects a syntax error, the edit will not be executed. Simply try to edit the file again, but make sure to read the error message and modify the edit command you issue accordingly. Issuing the same command a second time will just lead to the same error message again.
# end_name: end_of_edit
# arguments:
#   replacement_text:
#     type: string
#     description: the text to replace the current selection with
#     required: true
edit() {
    if [ -z "$CURRENT_FILE" ]
    then
        echo 'No file open. Use the `open` command first.'
        return
    fi

    if [ -z "$SELECTED_START_LINE" ] || [ -z "$SELECTED_END_LINE" ]
    then
        echo 'No lines selected. Use the `choose_lines <start_line>:<end_line>` command first.'
        return
    fi

    local start_line=$SELECTED_START_LINE
    local end_line=$SELECTED_END_LINE

    local line_count=0
    local replacement=()
    while IFS= read -r line
    do
        replacement+=("$line")
        ((line_count++))
    done

    # Create a backup of the current file
    cp "$CURRENT_FILE" "/root/$(basename "$CURRENT_FILE")_backup"

    # Read the file line by line into an array
    mapfile -t lines < "$CURRENT_FILE"
    local new_lines=("${lines[@]:0:$start_line}" "${replacement[@]}" "${lines[@]:$((end_line))}")
    # Write the new stuff directly back into the original file
    printf "%s\n" "${new_lines[@]}" >| "$CURRENT_FILE"
    
    # Run linter
    if [[ $CURRENT_FILE == *.py ]]; then
        lint_output=$(flake8 --isolated --select=F821,F822,F831,E111,E112,E113,E999,E902 "$CURRENT_FILE" 2>&1)
    else
        # do nothing
        lint_output=""
    fi

    # if there is no output, then the file is good
    if [ -z "$lint_output" ]; then
        export CURRENT_LINE=$start_line
        _constrain_line
        _print

        echo "File updated. Please review the changes and make sure they are correct (correct indentation, no duplicate lines, etc). Edit the file again if necessary."
        echo ""
        echo "TIPS: If you believe you have fixed the bug and verifying the fix requires a complex environment, you may just \`submit\`."
        echo ""

        choose_lines $((start_line+1)):$((start_line+line_count))
    else
        echo "Your proposed edit has introduced new syntax error(s). Please read this error message carefully and then retry editing the file."
        echo ""
        echo "ERRORS:"
        _split_string "$lint_output"
        echo ""

        # Save original values
        original_current_line=$CURRENT_LINE
        original_window=$WINDOW

        # Update values
        export CURRENT_LINE=$(( (line_count / 2) + start_line )) # Set to "center" of edit
        export WINDOW=$((line_count + 10)) # Show +/- 5 lines around edit

        echo "This is how your edit would have looked if applied"
        echo "-------------------------------------------------"
        _constrain_line
        _print
        echo "-------------------------------------------------"
        echo ""

        # Restoring CURRENT_FILE to original contents.
        cp "/root/$(basename "$CURRENT_FILE")_backup" "$CURRENT_FILE"

        export CURRENT_LINE=$(( ((end_line - start_line + 1) / 2) + start_line ))
        export WINDOW=$((end_line - start_line + 10))

        echo "This is the original code before your edit"
        echo "-------------------------------------------------"
        _constrain_line
        _print
        echo "-------------------------------------------------"

        # Output the selected lines
        echo "This is the lines you selected to edit:"
        echo "\`\`\`"
        for ((i=start_line; i<end_line; i++)); do
            echo "${lines[i]}"
        done
        echo "\`\`\`"

        # Restore original values
        export CURRENT_LINE=$original_current_line
        export WINDOW=$original_window

        echo "Your changes have NOT been applied. Please fix your edit command and try again."
        echo "You either need to 1) Select the correct start/end line arguments using \`choose_lines\` or 2) Correct your edit code or 3) Open the correct file, maybe you need \`open <path> [<line_number>] to open the right file\`."
        echo "DO NOT re-run the same failed edit command. Running it again will lead to the same error."
    fi

    # Remove backup file
    rm -f "/root/$(basename "$CURRENT_FILE")_backup"
}