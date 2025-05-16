autoload -Uz compinit
compinit

source "$ZSH_HOME/.antidote/antidote.zsh"

antidote load

[ -x "$(command -v starship)" ] && eval "$(starship init zsh)"

source $ZSH_HOME/aliases.sh
source $ZSH_HOME/bindings.sh

eval $(ssh-agent) > /dev/null 2> /dev/null

# [ -x /opt/homebrew/bin/nu ] && SHELL=/opt/homebrew/bin/nu exec nu
