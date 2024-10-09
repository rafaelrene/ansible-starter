# PATHS
export VOLTA_HOME="$XDG_CONFIG_HOME/volta"
export DIVERSION_HOME="$XDG_CONFIG_HOME/diversion"
export PNPM_HOME="$XDG_CONFIG_HOME/pnpm"
export GOPATH="$XDG_CONFIG_HOME/go"

export PATH="$GOPATH/bin:$DIVERSION_HOME/bin:$PNPM_HOME/bin:$VOLTA_HOME/bin:$HOME/.bin:$PATH"

# FZF - Theme (Catpuccin Macchiato wo/ bg)
export FZF_DEFAULT_OPTS=" \
--color=bg+:#363a4f,spinner:#f4dbd6,hl:#ed8796 \
--color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
--color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796"

# VARIABLES
export ZSH_HOME="$HOME/.config/zsh"
export ANTIDOTE_HOME="$ZSH_HOME/.cache/antidote"
export CXXFLAGS="-stdlib=libc++"

export EDITOR="nvim"

export GIT_CONFIG_SYSTEM="$XDG_CONFIG_HOME/git/.gitconfig"

# ZSH History
export HISTFILE="$ZSH_HOME/.zsh_history"
export HISTSIZE=1000000
export SAVEHIST=1000000

setopt appendhistory
