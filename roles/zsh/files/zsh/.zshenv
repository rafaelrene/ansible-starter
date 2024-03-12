eval "$(/opt/homebrew/bin/brew shellenv)"

[ -r "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
[ -r "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env"
[ -r "$HOME/.opam/opam-init/init.zsh" ] && source "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null
