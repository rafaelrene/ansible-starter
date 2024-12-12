[ -f "/opt/homebrew/bin/brew" ] && eval "$(/opt/homebrew/bin/brew shellenv)"
[ -f '/Users/rafael/code/.sources/google-cloud-sdk/path.zsh.inc' ] && source '/Users/rafael/code/.sources/google-cloud-sdk/path.zsh.inc'
[ -f '/Users/rafael/code/.sources/google-cloud-sdk/completion.zsh.inc' ] && source '/Users/rafael/code/.sources/google-cloud-sdk/completion.zsh.inc'

[ -x "$(command -v conda)" ] && eval "$(conda "shell.$(basename "${SHELL}")" hook)"

[ -r "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
[ -r "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env"
[ -r "$HOME/.opam/opam-init/init.zsh" ] && source "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null
