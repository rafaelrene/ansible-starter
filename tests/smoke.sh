#!/usr/bin/env bash

set -euo pipefail

ROOT=$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P
)
TMPDIR_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-tests.XXXXXX")
trap 'rm -rf "$TMPDIR_ROOT"' EXIT INT TERM

assert_eq() {
  local expected=$1
  local actual=$2
  local message=$3

  if [[ "$expected" != "$actual" ]]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

HOME="$TMPDIR_ROOT/home"
mkdir -p "$HOME"
DOTFORGE_ROOT=$ROOT
DOTFORGE_CONFIG_DIR="$HOME/.config/dotforge"
DOTFORGE_CONFIG_FILE="$DOTFORGE_CONFIG_DIR/config"
DOTFORGE_STATE_DIR="$HOME/.local/state/dotforge"
DOTFORGE_INSTALL_HOME="$HOME/.local/share/dotforge"
DOTFORGE_HELPER_DIR="$ROOT/libexec"
DOTFORGE_ASSETS_DIR="$ROOT/assets"
DOTFORGE_CATALOG_DIR="$ROOT/catalog"

# shellcheck source=../lib/common.sh
. "$ROOT/lib/common.sh"
# shellcheck source=../lib/catalog.sh
. "$ROOT/lib/catalog.sh"
# shellcheck source=../lib/config.sh
. "$ROOT/lib/config.sh"
# shellcheck source=../lib/state.sh
. "$ROOT/lib/state.sh"
# shellcheck source=../lib/assets.sh
. "$ROOT/lib/assets.sh"

DOTFORGE_PLATFORM=macos

normalized=$(normalize_package_csv 'fd, fd,brew:watch,fd')
assert_eq 'fd,brew:watch' "$normalized" 'package normalization should dedupe and trim tokens'

empty_normalized=$(normalize_package_csv '')
assert_eq '' "$empty_normalized" 'package normalization should allow an empty package list'

resolved=$(resolve_package_token 'go-task')
assert_eq 'catalog|brew|formula|go-task/tap|go-task|go-task' "$resolved" 'catalog lookup should resolve macOS package metadata'

secrets_dir="$TMPDIR_ROOT/secrets"
mkdir -p "$secrets_dir"
printf 'ssh-secret\n' >"$secrets_dir/SSH_BITBUCKET_WORK"
printf 'ssh-secret\n' >"$secrets_dir/SSH_HETZNER"
printf 'ssh-secret\n' >"$secrets_dir/SSH_PERSONAL"

deploy_managed_assets "$secrets_dir"

[[ -L "$HOME/.config/opencode" ]] || {
  printf 'FAIL: opencode config directory was not deployed as a symlink\n' >&2
  exit 1
}
grep -F 'x-gs-mcp-token:{file:~/.local/state/dotforge/secrets/OPENCODE_GSMCP_TOKEN}' "$HOME/.config/opencode/opencode.jsonc" >/dev/null || {
  printf 'FAIL: opencode config does not reference the expected local secret file\n' >&2
  exit 1
}
[[ "$(readlink "$HOME/.config/opencode")" == "$DOTFORGE_ASSETS_DIR/config/opencode" ]] || {
  printf 'FAIL: opencode config directory points to the wrong source\n' >&2
  exit 1
}

printf 'smoke tests passed\n'
