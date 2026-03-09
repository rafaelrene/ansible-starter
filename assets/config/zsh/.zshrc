autoload -Uz compinit
compinit

source "$ZSH_HOME/.antidote/antidote.zsh"

antidote load

[ -x "$(command -v starship)" ] && eval "$(starship init zsh)"

source $ZSH_HOME/aliases.sh
source $ZSH_HOME/functions.sh
source $ZSH_HOME/bindings.sh

eval "$(ssh-agent)" >/dev/null 2>&1

[ -x "$(command -v mise)" ] && source "$ZSH_HOME/mise.sh"

# [ -x "$(command -v nu)" ] && SHELL="$(command -v nu)" exec nu
