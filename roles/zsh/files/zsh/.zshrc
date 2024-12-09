autoload -Uz compinit
compinit

source "$ZSH_HOME/.antidote/antidote.zsh"

antidote load

source $ZSH_HOME/aliases.sh
source $ZSH_HOME/bindings.sh

eval $(ssh-agent) > /dev/null 2> /dev/null
