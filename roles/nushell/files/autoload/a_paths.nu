use std/util "path add"

path add ($env.XDG_CONFIG_HOME | path join "volta" "bin")
path add ($env.XDG_CONFIG_HOME | path join "diversion" "bin")
path add ($env.XDG_CONFIG_HOME | path join "pnpm" "bin")
path add ($env.XDG_CONFIG_HOME | path join "go" "bin")
path add ($env.HOME | path join ".spin" "bin")

if ("/opt/homebrew/bin/brew" | path exists) {
  $env.HOMEBREW_PREFIX = "/opt/homebrew"
  $env.HOMEBREW_CELLAR = "/opt/homebrew/Cellar"
  $env.HOMEBREW_REPOSITORY = "/opt/homebrew"

  path add ($env.HOMEBREW_PREFIX | path join "sbin") ($env.HOMEBREW_PREFIX | path join "bin")
}
