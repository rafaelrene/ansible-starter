# PATHS
export VOLTA_HOME="$XDG_CONFIG_HOME/volta"
export DIVERSION_HOME="$XDG_CONFIG_HOME/diversion"
export PNPM_HOME="$XDG_CONFIG_HOME/pnpm"

export PATH="$DIVERSION_HOME/bin:$PNPM_HOME/bin:$VOLTA_HOME/bin:$HOME/.bin:$PATH"

# VARIABLES
export ZSH_HOME="$HOME/.config/zsh"
export ANTIDOTE_HOME="$ZSH_HOME/.cache/antidote"
export CXXFLAGS="-stdlib=libc++"

export EDITOR="nvim"
