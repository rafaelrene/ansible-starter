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

assert_not_contains() {
  local needle=$1
  local haystack=$2
  local message=$3

  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'FAIL: %s\nunexpected: %s\noutput: %s\n' "$message" "$needle" "$haystack" >&2
    exit 1
  fi
}

if bash -lc 'exec </dev/tty' >/dev/null 2>&1; then
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
fi

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

homebrew_hydration_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-homebrew-test.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    fake_prefix="$test_root/homebrew"
    fake_bin="$fake_prefix/bin"
    mkdir -p "$fake_bin"

    cat >"$fake_bin/brew" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "shellenv" ]]; then
  printf "export HOMEBREW_PREFIX=%q\n" "$fake_prefix"
  printf "export PATH=%q\n" "$fake_bin:\$PATH"
  exit 0
fi
if [[ "\${1:-}" == "list" ]]; then
  exit 1
fi
if [[ "\${1:-}" == "install" ]]; then
  printf "installed:%s\n" "\$*" >>"$test_root/brew.log"
  exit 0
fi
exit 0
EOF
    chmod +x "$fake_bin/brew"

    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/platform.sh"

    homebrew_candidate_paths() {
      printf "%s\n" "$fake_bin/brew"
    }
    command_exists() {
      if [[ "$1" == "brew" ]]; then
        command -v brew >/dev/null 2>&1
        return $?
      fi
      command -v "$1" >/dev/null 2>&1
    }
    PATH=/usr/bin:/bin
    ensure_homebrew
    command -v brew
    printf "%s\n" "$HOMEBREW_PREFIX"
  '
)
assert_contains "/brew" "$homebrew_hydration_output" "ensure_homebrew should hydrate Homebrew into PATH"

brew_prerequisite_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-homebrew-prereq.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    fake_prefix="$test_root/homebrew"
    fake_bin="$fake_prefix/bin"
    mkdir -p "$fake_bin"

    cat >"$fake_bin/brew" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "shellenv" ]]; then
  printf "export HOMEBREW_PREFIX=%q\n" "$fake_prefix"
  printf "export PATH=%q\n" "$fake_bin:\$PATH"
  exit 0
fi
if [[ "\${1:-}" == "list" ]]; then
  exit 1
fi
if [[ "\${1:-}" == "install" ]]; then
  printf "installed:%s\n" "\$*" >>"$test_root/brew.log"
  exit 0
fi
exit 0
EOF
    chmod +x "$fake_bin/brew"

    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/platform.sh"

    homebrew_candidate_paths() {
      printf "%s\n" "$fake_bin/brew"
    }
    PATH=/usr/bin:/bin
    ensure_brew_prerequisites age python
    cat "$test_root/brew.log"
  '
)
assert_contains "installed:install age python" "$brew_prerequisite_output" "ensure_brew_prerequisites should batch missing formula installs"

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

selector_defaults_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-selector-defaults.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/config.sh"

    catalog_default_ids() {
      printf "fd\n"
      printf "tmux\n"
    }
    tty_print() { :; }
    tty_println() { :; }
    printf "\n\n" >"$test_root/responses"
    tty_read_line() {
      local response=""
      IFS= read -r response <"$test_root/responses" || true
      tail -n +2 "$test_root/responses" >"$test_root/responses.next"
      mv "$test_root/responses.next" "$test_root/responses"
      printf "%s" "$response"
    }

    interactive_package_selection
  ' 2>&1
)
assert_eq "fd,tmux" "$selector_defaults_output" "blank package selection input should accept defaults"
assert_not_contains "Unknown selection command" "$selector_defaults_output" "blank package selection input should not warn"

selector_toggle_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-selector-toggle.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/config.sh"

    catalog_default_ids() {
      printf "fd\n"
      printf "tmux\n"
    }
    tty_print() { :; }
    tty_println() { :; }
    printf "toggle 2\ndone\nbrew:watch\n" >"$test_root/responses"
    tty_read_line() {
      local response=""
      IFS= read -r response <"$test_root/responses" || true
      tail -n +2 "$test_root/responses" >"$test_root/responses.next"
      mv "$test_root/responses.next" "$test_root/responses"
      printf "%s" "$response"
    }

    interactive_package_selection
  '
)
assert_eq "fd,brew:watch" "$selector_toggle_output" "package selection should still support toggle and extra packages"

selector_none_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-selector-none.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/config.sh"

    catalog_default_ids() {
      printf "fd\n"
      printf "tmux\n"
    }
    tty_print() { :; }
    tty_println() { :; }
    printf "none\n\n" >"$test_root/responses"
    tty_read_line() {
      local response=""
      IFS= read -r response <"$test_root/responses" || true
      tail -n +2 "$test_root/responses" >"$test_root/responses.next"
      mv "$test_root/responses.next" "$test_root/responses"
      printf "%s" "$response"
    }

    interactive_package_selection
  '
)
assert_eq "" "$selector_none_output" "package selection should allow choosing no packages"

empty_state_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-empty-state.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    DOTFORGE_ROOT="'"$ROOT"'"
    DOTFORGE_STATE_DIR="$test_root/state"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/state.sh"
    . "'"$ROOT"'/lib/packages.sh"

    DOTFORGE_MANAGED_PACKAGES_FILE="$DOTFORGE_STATE_DIR/managed-packages.txt"
    resolve_csv_to_specs() { :; }
    uninstall_state_lines() { :; }

    uninstall_removed_packages ""
    printf "ok\n"
  '
)
assert_eq "ok" "$empty_state_output" "package uninstall should tolerate an empty managed state file"

passphrase_output=$(
  printf "stdin-should-not-be-used\n" | bash -lc '
    set -euo pipefail
    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/secrets.sh"
    tty_print() { :; }
    tty_read_secret() {
      printf "expected-passphrase"
    }
    prompt_for_age_passphrase
  '
)
assert_eq "expected-passphrase" "$passphrase_output" "prompt_for_age_passphrase should read via tty_read_secret"

config_migration_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-config-migrate.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    DOTFORGE_ROOT="'"$ROOT"'"
    DOTFORGE_CONFIG_DIR="$test_root/config"
    DOTFORGE_CONFIG_FILE="$DOTFORGE_CONFIG_DIR/config"
    mkdir -p "$DOTFORGE_CONFIG_DIR"
    printf "%s\n" "DOTFORGE_PACKAGES=\"fd,tmux\"" >"$DOTFORGE_CONFIG_FILE"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/config.sh"
    auto_migrate_package_tokens
    printf "%s\n" "$DOTFORGE_PACKAGES"
    auto_migrate_package_tokens
    printf "%s\n" "$DOTFORGE_PACKAGES"
  '
)
assert_eq $'fd,tmux,fzf,starship\nfd,tmux,fzf,starship' "$config_migration_output" "config migration should append fzf and starship exactly once"

preflight_output=$(
  bash -lc '
    set -euo pipefail
    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/config.sh"
    . "'"$ROOT"'/lib/platform.sh"
    . "'"$ROOT"'/lib/secrets.sh"
    . "'"$ROOT"'/lib/preflight.sh"
    steps=()
    collect_config_inputs_if_needed() { steps+=("config"); }
    ensure_sudo_session() { steps+=("sudo"); }
    start_sudo_keepalive() { steps+=("keepalive"); }
    bootstrap_platform_prerequisites() { steps+=("bootstrap"); }
    ensure_age_passphrase_ready() { steps+=("passphrase"); }
    detect_shell_context() { steps+=("shell"); }
    validate_age_bundle_passphrase() { steps+=("validate"); }
    info() { :; }
    dotforge_preflight_collect apply
    printf "%s\n" "${steps[*]}"
  '
)
assert_eq "config sudo keepalive bootstrap passphrase shell validate" "$preflight_output" "preflight should front-load config, sudo, bootstrap, passphrase, shell detection, and validation"

secrets_pack_prompt_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-secrets-pack.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    DOTFORGE_ROOT="'"$ROOT"'"
    DOTFORGE_SECRETS_BUNDLE="$test_root/bundle.tar.age"
    mkdir -p "$test_root/source/ssh"
    : >"$test_root/source/ssh/key"
    : >"$test_root/prompt.log"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/secrets.sh"
    prompt_for_age_passphrase() {
      printf "prompt\n" >>"$test_root/prompt.log"
      printf "expected-passphrase"
    }
    age_run() { return 0; }
    deploy_ssh_assets() { :; }
    info() { :; }
    prepare_runtime_secrets_dir() {
      ensure_age_passphrase_ready
      printf "%s\n" "$test_root/source"
    }
    secrets_pack "$test_root/source"
    wc -l <"$test_root/prompt.log" | awk "{print \$1}"
  '
)
assert_eq "1" "$secrets_pack_prompt_output" "secrets_pack should only prompt for the age passphrase once per run"

sudo_output=$(
  bash -lc '
    set -euo pipefail
    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/platform.sh"
    sudo_calls=()
    sudo() {
      sudo_calls+=("$*")
      if [[ "$1" == "-n" ]]; then
        return 1
      fi
      return 0
    }
    run_with_interactive_tty() {
      printf "tty:%s\n" "$*"
      "$@"
    }
    DOTFORGE_NONINTERACTIVE=0
    ensure_sudo_session
    printf "%s\n" "${sudo_calls[*]}"
  '
)
assert_contains "tty:sudo -v" "$sudo_output" "ensure_sudo_session should use the tty helper when sudo prompts are required"
assert_contains "-n true" "$sudo_output" "ensure_sudo_session should preserve the non-interactive sudo fast path check"

tmux_install_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-tmux-install.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    export HOME="$test_root/home"
    mkdir -p "$HOME/.config/tmux/tpm/bin"
    : >"$HOME/.config/tmux/tmux.conf"
    cat >"$HOME/.config/tmux/tpm/bin/install_plugins" <<EOF
#!/usr/bin/env bash
printf "installer\n" >>"$HOME/tmux.log"
EOF
    chmod +x "$HOME/.config/tmux/tpm/bin/install_plugins"
    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/config.sh"
    . "'"$ROOT"'/lib/platform.sh"
    . "'"$ROOT"'/lib/assets.sh"
    command_exists() {
      [[ "$1" == "tmux" ]] && return 0
      command -v "$1" >/dev/null 2>&1
    }
    tmux() {
      printf "tmux:%s\n" "$*" >>"$HOME/tmux.log"
      if [[ "${1:-}" == "ls" ]]; then
        return 1
      fi
      return 0
    }
    install_tmux_plugins
    cat "$HOME/tmux.log"
  '
)
assert_contains "tmux:new-session -d -s" "$tmux_install_output" "install_tmux_plugins should start a temporary tmux server when needed"
assert_contains "tmux:source-file" "$tmux_install_output" "install_tmux_plugins should source the tmux config"
assert_contains "installer" "$tmux_install_output" "install_tmux_plugins should run the TPM installer"
assert_contains "tmux:kill-session -t" "$tmux_install_output" "install_tmux_plugins should clean up the temporary tmux session"

shell_switch_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-shell-switch.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    fake_bin="$test_root/bin"
    mkdir -p "$fake_bin"
    cat >"$fake_bin/zsh" <<EOF
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$fake_bin/zsh"
    export PATH="$fake_bin:$PATH"
    DOTFORGE_ROOT="'"$ROOT"'"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/platform.sh"
    : >"$test_root/sudo.log"
    detect_shell_context() {
      DOTFORGE_LOGIN_SHELL=/bin/bash
    }
    sudo() {
      printf "sudo:%s\n" "$*" >>"$test_root/sudo.log"
      return 0
    }
    ensure_login_shell_is_zsh
    cat "$test_root/sudo.log"
  '
)
assert_contains "sudo:chsh -s" "$shell_switch_output" "ensure_login_shell_is_zsh should attempt to switch the login shell with sudo chsh"

printf 'platform tests passed\n'
