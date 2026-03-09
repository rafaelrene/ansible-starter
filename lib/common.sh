#!/usr/bin/env bash

DOTFORGE_INSTALL_HOME=${DOTFORGE_INSTALL_HOME:-"$HOME/.local/share/dotforge"}
DOTFORGE_HOME=${DOTFORGE_HOME:-"$DOTFORGE_ROOT"}
DOTFORGE_CONFIG_DIR=${DOTFORGE_CONFIG_DIR:-"$HOME/.config/dotforge"}
DOTFORGE_CONFIG_FILE=${DOTFORGE_CONFIG_FILE:-"$DOTFORGE_CONFIG_DIR/config"}
DOTFORGE_STATE_DIR=${DOTFORGE_STATE_DIR:-"$HOME/.local/state/dotforge"}
DOTFORGE_ASSETS_DIR=${DOTFORGE_ASSETS_DIR:-"$DOTFORGE_ROOT/assets"}
DOTFORGE_CATALOG_DIR=${DOTFORGE_CATALOG_DIR:-"$DOTFORGE_ROOT/catalog"}
DOTFORGE_SECRETS_BUNDLE=${DOTFORGE_SECRETS_BUNDLE:-"$DOTFORGE_ROOT/secrets/bundle.tar.age"}
DOTFORGE_BIN_DIR=${DOTFORGE_BIN_DIR:-"$DOTFORGE_ROOT/bin"}
DOTFORGE_HELPER_DIR=${DOTFORGE_HELPER_DIR:-"$DOTFORGE_ROOT/libexec"}

DOTFORGE_PLATFORM=${DOTFORGE_PLATFORM:-""}
DOTFORGE_NONINTERACTIVE=${DOTFORGE_NONINTERACTIVE:-0}
DOTFORGE_AGE_PASSPHRASE=${DOTFORGE_AGE_PASSPHRASE:-""}
DOTFORGE_SUDO_KEEPALIVE_PID=${DOTFORGE_SUDO_KEEPALIVE_PID:-""}

DOTFORGE_MANAGED_PACKAGES_FILE="$DOTFORGE_STATE_DIR/managed-packages.txt"
DOTFORGE_SECRETS_HASHES_FILE="$DOTFORGE_STATE_DIR/secrets.sha256"
DOTFORGE_UNPACKED_DIR_FILE="$DOTFORGE_STATE_DIR/unpacked-dir"

DOTFORGE_CLEANUP_COMMANDS=""

init_paths() {
  DOTFORGE_HOME=$DOTFORGE_ROOT
  DOTFORGE_BIN_DIR=$DOTFORGE_ROOT/bin
}

log() {
  printf '%s\n' "$*"
}

info() {
  printf 'INFO: %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

die_with_fix() {
  local what=$1
  local cause=$2
  local fix=$3

  {
    printf 'ERROR: %s\n' "$what"
    printf 'Cause: %s\n' "$cause"
    printf 'Fix: %s\n' "$fix"
  } >&2
  run_cleanups
  exit 1
}

ensure_dir() {
  local path=$1
  if [[ ! -d "$path" ]]; then
    mkdir -p "$path"
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

interactive_tty_path() {
  printf '/dev/tty\n'
}

ensure_interactive_tty_available() {
  local tty_path

  tty_path=$(interactive_tty_path)
  if [[ -n "$tty_path" && -r "$tty_path" && -w "$tty_path" ]]; then
    printf '%s\n' "$tty_path"
    return 0
  fi

  die_with_fix \
    "An interactive terminal is required." \
    "dotforge could not access the controlling terminal for interactive prompts." \
    "Run dotforge from Terminal.app or another interactive shell. For headless runs, install Homebrew first and set DOTFORGE_NONINTERACTIVE=1 with DOTFORGE_PACKAGES and DOTFORGE_AGE_PASSPHRASE as needed."
}

tty_print() {
  local tty_path
  tty_path=$(ensure_interactive_tty_available)
  printf '%s' "$*" >"$tty_path"
}

tty_println() {
  local tty_path
  tty_path=$(ensure_interactive_tty_available)
  printf '%s\n' "$*" >"$tty_path"
}

tty_read_line() {
  local tty_path
  local line=""

  tty_path=$(ensure_interactive_tty_available)
  IFS= read -r line <"$tty_path" || true
  printf '%s' "$line"
}

tty_read_secret() {
  local tty_path
  local passphrase=""
  local stty_state

  tty_path=$(ensure_interactive_tty_available)
  stty_state=$(stty -g <"$tty_path") || die_with_fix \
    "Failed to configure terminal input." \
    "dotforge could not read the current terminal settings before prompting for secret input." \
    "Retry the command in a normal interactive terminal session."

  stty -echo <"$tty_path" || die_with_fix \
    "Failed to disable terminal echo." \
    "dotforge could not switch the terminal into hidden-input mode for secret entry." \
    "Retry the command in a normal interactive terminal session."

  IFS= read -r passphrase <"$tty_path" || true

  stty "$stty_state" <"$tty_path" >/dev/null 2>&1 || die_with_fix \
    "Failed to restore terminal echo." \
    "dotforge could not restore the terminal settings after secret input." \
    "Run 'stty sane' in your terminal if the prompt stays broken, then rerun dotforge."

  printf '\n' >"$tty_path"
  printf '%s' "$passphrase"
}

run_with_interactive_tty() {
  local tty_path
  tty_path=$(ensure_interactive_tty_available)
  "$@" <"$tty_path" >"$tty_path" 2>"$tty_path"
}

terminal_stdin_is_tty() {
  [[ -t 0 ]]
}

restore_interactive_stdin() {
  local tty_path

  [[ "$DOTFORGE_NONINTERACTIVE" == "1" ]] && return 0
  terminal_stdin_is_tty && return 0

  tty_path=$(ensure_interactive_tty_available)
  if [[ -n "$tty_path" ]] && exec <"$tty_path"; then
    terminal_stdin_is_tty && return 0
  fi

  die_with_fix \
    "An interactive terminal is required." \
    "dotforge started without a TTY on stdin and could not reconnect to the current terminal." \
    "Run dotforge from Terminal.app or another interactive shell. For headless runs, install Homebrew first and set DOTFORGE_NONINTERACTIVE=1 with DOTFORGE_PACKAGES and DOTFORGE_AGE_PASSPHRASE as needed."
}

trim() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

join_by_comma() {
  local first=1
  local item
  for item in "$@"; do
    if [[ $first -eq 1 ]]; then
      printf '%s' "$item"
      first=0
    else
      printf ',%s' "$item"
    fi
  done
}

contains_line() {
  local needle=$1
  shift
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

sorted_unique_lines() {
  awk 'NF { print }' | sort -u
}

register_cleanup() {
  local command=$1
  if [[ -n "$DOTFORGE_CLEANUP_COMMANDS" ]]; then
    DOTFORGE_CLEANUP_COMMANDS=$DOTFORGE_CLEANUP_COMMANDS$'\n'"$command"
  else
    DOTFORGE_CLEANUP_COMMANDS=$command
  fi
}

run_cleanups() {
  local line
  if [[ -z "$DOTFORGE_CLEANUP_COMMANDS" ]]; then
    return 0
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    eval "$line" || true
  done <<EOF
$DOTFORGE_CLEANUP_COMMANDS
EOF
  DOTFORGE_CLEANUP_COMMANDS=""
}

with_exit_trap() {
  trap 'run_cleanups' EXIT INT TERM
}

hash_file() {
  local path=$1
  if command_exists sha256sum; then
    sha256sum "$path" | awk '{print $1}'
  elif command_exists shasum; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    die_with_fix \
      "No SHA-256 command is available." \
      "dotforge needs either sha256sum or shasum to verify deployed secrets." \
      "Install coreutils or perl Digest::SHA support, then rerun dotforge."
  fi
}

safe_remove_path() {
  local path=$1
  [[ -e "$path" || -L "$path" ]] || return 0
  rm -rf "$path"
}

best_effort_wipe() {
  local path=$1
  if [[ ! -e "$path" ]]; then
    return 0
  fi

  if command_exists gshred; then
    find "$path" -type f -exec gshred -u {} \; 2>/dev/null || true
  elif command_exists shred; then
    find "$path" -type f -exec shred -u {} \; 2>/dev/null || true
  elif command_exists srm; then
    find "$path" -type f -exec srm {} \; 2>/dev/null || true
  elif rm -P "$path" >/dev/null 2>&1; then
    :
  else
    warn "Secure erase is not guaranteed on this filesystem. Removing '$path' normally."
  fi

  rm -rf "$path"
}
