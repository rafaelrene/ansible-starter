[ -f "/opt/homebrew/bin/brew" ] && eval "$(/opt/homebrew/bin/brew shellenv)"

# [ -x "$(command -v conda)" ] && eval "$(conda "shell.$(basename "${SHELL}")" hook)"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/rafael/.local/share/mise/installs/python/miniconda3-3.13-26.3.2-2/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/rafael/.local/share/mise/installs/python/miniconda3-3.13-26.3.2-2/etc/profile.d/conda.sh" ]; then
        . "/Users/rafael/.local/share/mise/installs/python/miniconda3-3.13-26.3.2-2/etc/profile.d/conda.sh"
    else
        export PATH="/Users/rafael/.local/share/mise/installs/python/miniconda3-3.13-26.3.2-2/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

[ -x "$(command -v direnv)" ] && eval "$(direnv hook zsh)"

[ -x "/opt/homebrew/bin/mise" ] && eval "$(mise activate zsh)"

[ -r "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
[ -r "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env"
[ -r "$HOME/.opam/opam-init/init.zsh" ] && source "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null
