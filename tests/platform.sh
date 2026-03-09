#!/usr/bin/env bash

set -euo pipefail

ROOT=$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P
)

assert_eq() {
  local expected=$1
  local actual=$2
  local message=$3

  if [[ "$expected" != "$actual" ]]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_contains() {
  local needle=$1
  local haystack=$2
  local message=$3

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'FAIL: %s\nmissing: %s\noutput: %s\n' "$message" "$needle" "$haystack" >&2
    exit 1
  fi
}

restore_output=$(
  printf 'pipe\n' | bash -lc '
    set -euo pipefail
    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    DOTFORGE_NONINTERACTIVE=0
    restore_interactive_stdin
    if terminal_stdin_is_tty; then
      printf "yes\n"
    else
      printf "no\n"
    fi
  '
)
assert_eq "yes" "$restore_output" "restore_interactive_stdin should reconnect piped stdin to the controlling tty"

noninteractive_output=$(
  printf 'pipe\n' | bash -lc '
    set -euo pipefail
    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    interactive_tty_path() {
      printf "/path/that/does/not/exist\n"
    }
    DOTFORGE_NONINTERACTIVE=1
    restore_interactive_stdin
    if terminal_stdin_is_tty; then
      printf "yes\n"
    else
      printf "no\n"
    fi
  '
)
assert_eq "no" "$noninteractive_output" "restore_interactive_stdin should be a no-op in non-interactive mode"

set +e
noninteractive_homebrew_output=$(
  bash -lc '
    set -euo pipefail
    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/platform.sh"
    command_exists() {
      if [[ "$1" == "brew" ]]; then
        return 1
      fi
      command -v "$1" >/dev/null 2>&1
    }
    DOTFORGE_NONINTERACTIVE=1
    ensure_homebrew
  ' 2>&1
)
noninteractive_homebrew_status=$?
set -e

assert_eq "1" "$noninteractive_homebrew_status" "ensure_homebrew should fail in non-interactive mode when Homebrew is missing"
assert_contains "Homebrew must already be installed for non-interactive macOS runs." "$noninteractive_homebrew_output" "ensure_homebrew should explain the failure"
assert_contains "Install Homebrew manually first" "$noninteractive_homebrew_output" "ensure_homebrew should prescribe manual Homebrew installation"

printf 'platform tests passed\n'
