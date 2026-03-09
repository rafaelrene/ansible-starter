# config.nu
#
# Installed by:
# version = "0.101.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# This file is loaded after env.nu and before login.nu
#
# You can open this file in your default editor using:
# config nu
#
# See `help config nu` for more options
#
# You can remove these comments if you want or leave
# them for future reference.

mkdir ~/.cache/starship
starship init nu | save -f ~/.cache/starship/init.nu

use std/util "path add"

path add ($env.HOME | path join ".local" "share" "dotforge" "bin")
path add ($env.XDG_CONFIG_HOME | path join "volta" "bin")
path add ($env.XDG_CONFIG_HOME | path join "diversion" "bin")
path add ($env.XDG_CONFIG_HOME | path join "pnpm" "bin")
path add ($env.XDG_CONFIG_HOME | path join "go" "bin")
path add ($env.HOME | path join ".spin" "bin")

$env.LANG = "en_US.UTF-8"
$env.LC_ALL = "en_US.UTF-8"

$env.config.buffer_editor = "nvim"

$env.FZF_DEFAULT_OPTS = '
--color=bg+:#363a4f,spinner:#f4dbd6,hl:#ed8796
--color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6
--color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796'

$env.ZSH_HOME = $env.HOME | path join ".config" "zsh"
$env.ANTIDOTE_HOME = $env.ZSH_HOME | path join ".cache" "antidote"

$env.CXXFLAGS = "-stdlib=libc++"
$env.EDITOR = "nvim"

$env.GIT_CONFIG_SYSTEM = $env.XDG_CONFIG_HOME | path join "git" ".gitconfig"
$env.STARSHIP_CONFIG = $env.XDG_CONFIG_HOME | path join "starship" "starship.toml"

let brew_cmd = (which brew | get 0.path? | default "")
if $brew_cmd != "" {
  let brew_prefix = (^brew --prefix | str trim)
  $env.HOMEBREW_PREFIX = $brew_prefix
  $env.HOMEBREW_CELLAR = ($env.HOMEBREW_PREFIX | path join "Cellar")
  $env.HOMEBREW_REPOSITORY = $env.HOMEBREW_PREFIX

  path add ($env.HOMEBREW_PREFIX | path join "sbin") ($env.HOMEBREW_PREFIX | path join "bin")
}

use ~/.cache/starship/init.nu
