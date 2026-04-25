try-rs() {
    # Pass flags/options directly to stdout without capturing
    for arg in "$@"; do
        case "$arg" in
            -*) command try-rs "$@"; return ;;
        esac
    done

    # Captures the output of the binary (stdout) which is the "cd" command
    # The TUI is rendered on stderr, so it doesn't interfere.
    local output
    output=$(command try-rs "$@")

    if [ -n "$output" ]; then
        eval "$output"
    fi
}

# try-rs tab completion for directory names
_try_rs_get_tries_path() {
    # Check TRY_PATH environment variable first
    if [[ -n "${TRY_PATH}" ]]; then
        if [[ "${TRY_PATH}" == *","* ]]; then
            echo "${TRY_PATH}" | tr ',' '\n'
        else
            echo "${TRY_PATH}"
        fi
        return
    fi
    
    # Try to read from config file
    local config_paths=("$HOME/.config/try-rs/config.toml" "$HOME/.try-rs/config.toml")
    for config_path in "${config_paths[@]}"; do
        if [[ -f "$config_path" ]]; then
            # Try tries_path (supports single or multiple paths with comma)
            local tries_path=$(grep -E '^[[:space:]]*tries_path[[:space:]]*=' "$config_path" 2>/dev/null | sed -E 's/.*=[[:space:]]*"?([^"]*)"?.*/\1/' | sed "s|~|$HOME|" | tr -d '[:space:]')
            if [[ -n "$tries_path" ]]; then
                if [[ "$tries_path" == *","* ]]; then
                    echo "$tries_path" | tr ',' '\n'
                else
                    echo "$tries_path"
                fi
                return
            fi
        fi
    done
    
    # Default path
    echo "$HOME/work/tries"
}

_try_rs_complete() {
    local -a dirs=()
    local tries_path

    while IFS= read -r tries_path; do
        if [[ -d "$tries_path" ]]; then
            local -a entries=("$tries_path"/*(N-/))
            dirs+=("${entries[@]:t}")
        fi
    done < <(_try_rs_get_tries_path)

    compadd -a dirs
}

compdef _try_rs_complete try-rs
