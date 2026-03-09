use std/util "path add"

path add ($env.HOME | path join ".local" "share" "dotforge" "bin")
path add ($env.XDG_CONFIG_HOME | path join "volta" "bin")
path add ($env.XDG_CONFIG_HOME | path join "diversion" "bin")
path add ($env.XDG_CONFIG_HOME | path join "pnpm" "bin")
path add ($env.XDG_CONFIG_HOME | path join "go" "bin")
path add ($env.HOME | path join ".spin" "bin")

let brew_cmd = (which brew | get 0.path? | default "")
if $brew_cmd != "" {
  let brew_prefix = (^brew --prefix | str trim)
  $env.HOMEBREW_PREFIX = $brew_prefix
  $env.HOMEBREW_CELLAR = ($env.HOMEBREW_PREFIX | path join "Cellar")
  $env.HOMEBREW_REPOSITORY = $env.HOMEBREW_PREFIX

  path add ($env.HOMEBREW_PREFIX | path join "sbin") ($env.HOMEBREW_PREFIX | path join "bin")
}
