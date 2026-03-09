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

package_skip_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-package-skip.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    DOTFORGE_ROOT="'"$ROOT"'"
    DOTFORGE_STATE_DIR="$test_root/state"
    DOTFORGE_MANAGED_PACKAGES_FILE="$DOTFORGE_STATE_DIR/managed-packages.txt"
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/state.sh"
    . "'"$ROOT"'/lib/packages.sh"

    resolve_csv_to_specs() {
      cat <<EOF
catalog|brew|formula||fd|fd
catalog|brew|formula|oven-sh/bun|bun|bun
catalog|brew|cask|homebrew/cask|ghostty|ghostty
catalog|brew|cask|wez/wezterm|wezterm|wezterm
raw|brew|raw||watch|brew:watch
raw|brew|raw||jq|brew:jq
catalog|yay|pkg||fzf|fzf
catalog|yay|pkg||ripgrep|ripgrep
EOF
    }
    config_package_tokens() {
      printf "desired\n"
    }
    uninstall_removed_packages() { :; }
    : >"$test_root/brew.log"
    : >"$test_root/yay.log"
    : >"$test_root/info.log"
    info() {
      printf "%s\n" "$*" >>"$test_root/info.log"
    }
    brew() {
      if [[ "${1:-}" == "list" ]] && [[ "${2:-}" == "--formula" ]] && [[ "${3:-}" == "fd" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "list" ]] && [[ "${2:-}" == "--cask" ]] && [[ "${3:-}" == "ghostty" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "list" ]] && [[ "${2:-}" == "watch" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "tap" ]]; then
        printf "%s\n" "$*" >>"$test_root/brew.log"
        return 0
      fi
      if [[ "${1:-}" == "install" ]]; then
        printf "%s\n" "$*" >>"$test_root/brew.log"
        return 0
      fi
      return 1
    }
    yay() {
      if [[ "${1:-}" == "-Q" ]] && [[ "${2:-}" == "fzf" ]]; then
        return 0
      fi
      if [[ "${1:-}" == "-S" ]]; then
        printf "%s\n" "$*" >>"$test_root/yay.log"
        return 0
      fi
      return 1
    }

    install_desired_packages desired
    reconcile_packages

    printf "BREW\n"
    cat "$test_root/brew.log"
    printf "YAY\n"
    cat "$test_root/yay.log"
    printf "INFO\n"
    cat "$test_root/info.log"
    printf "STATE\n"
    cat "$DOTFORGE_MANAGED_PACKAGES_FILE"
  '
)
assert_contains $'tap oven-sh/bun\ntap wez/wezterm' "$package_skip_output" "install_desired_packages should tap only missing tapped packages"
assert_not_contains "tap homebrew/cask" "$package_skip_output" "install_desired_packages should not tap repositories for already installed casks"
assert_contains "install --formula bun" "$package_skip_output" "install_desired_packages should install only missing Homebrew formulae"
assert_not_contains "install --formula fd" "$package_skip_output" "install_desired_packages should skip already installed Homebrew formulae"
assert_contains "install --cask wezterm" "$package_skip_output" "install_desired_packages should install only missing Homebrew casks"
assert_not_contains "install --cask ghostty" "$package_skip_output" "install_desired_packages should skip already installed Homebrew casks"
assert_contains "install jq" "$package_skip_output" "install_desired_packages should install only missing raw Homebrew packages"
assert_not_contains "install watch" "$package_skip_output" "install_desired_packages should skip already installed raw Homebrew packages"
assert_contains "-S --needed --noconfirm ripgrep" "$package_skip_output" "install_desired_packages should install only missing Arch packages"
assert_not_contains "-S --needed --noconfirm fzf" "$package_skip_output" "install_desired_packages should skip already installed Arch packages"
assert_contains "Skipping already installed Homebrew formula: fd" "$package_skip_output" "install_desired_packages should summarize skipped Homebrew formulae"
assert_contains "Skipping already installed Homebrew cask: ghostty" "$package_skip_output" "install_desired_packages should summarize skipped Homebrew casks"
assert_contains "Skipping already installed Homebrew package: watch" "$package_skip_output" "install_desired_packages should summarize skipped raw Homebrew packages"
assert_contains "Skipping already installed Arch package: fzf" "$package_skip_output" "install_desired_packages should summarize skipped Arch packages"
assert_contains "brew|formula||fd" "$package_skip_output" "reconcile_packages should still record already installed formulae as managed"
assert_contains "brew|cask|homebrew/cask|ghostty" "$package_skip_output" "reconcile_packages should still record already installed casks as managed"
assert_contains "brew|raw||watch" "$package_skip_output" "reconcile_packages should still record already installed raw brew packages as managed"
assert_contains "yay|pkg||fzf" "$package_skip_output" "reconcile_packages should still record already installed Arch packages as managed"

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

prepare_runtime_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-runtime-secrets.XXXXXX")
    trap "rm -rf \"$test_root\"" EXIT INT TERM
    DOTFORGE_ROOT="'"$ROOT"'"
    DOTFORGE_SECRETS_BUNDLE="$test_root/bundle.tar.age"
    mkdir -p "$test_root/source/ssh"
    printf "secret\n" >"$test_root/source/ssh/key"
    tar -cf "$test_root/archive.tar" -C "$test_root/source" ssh
    . "'"$ROOT"'/lib/common.sh"
    . "'"$ROOT"'/lib/secrets.sh"
    : >"$test_root/age.log"
    age_run() {
      printf "%s\n" "$*" >>"$test_root/age.log"
      local mode=$1
      shift
      if [[ "$mode" == "decrypt" ]]; then
        local output=""
        while [[ $# -gt 0 ]]; do
          if [[ "$1" == "-o" ]]; then
            output=$2
            shift 2
            continue
          fi
          shift
        done
        cp "$test_root/archive.tar" "$output"
      fi
    }
    printf "bundle\n" >"$DOTFORGE_SECRETS_BUNDLE"
    DOTFORGE_AGE_PASSPHRASE=expected-passphrase
    prepare_runtime_secrets_dir
    first_dir=$DOTFORGE_RUNTIME_SECRETS_DIR
    prepare_runtime_secrets_dir
    second_dir=$DOTFORGE_RUNTIME_SECRETS_DIR
    cleanup_lines=$(printf "%s\n" "$DOTFORGE_CLEANUP_COMMANDS" | awk "NF { count++ } END { print count + 0 }")
    age_calls=$(wc -l <"$test_root/age.log" | awk "{print \$1}")
    if [[ "$first_dir" == "$second_dir" ]]; then
      printf "same %s %s\n" "$age_calls" "$cleanup_lines"
    else
      printf "different %s %s\n" "$age_calls" "$cleanup_lines"
    fi
  '
)
assert_eq "same 2 2" "$prepare_runtime_output" "prepare_runtime_secrets_dir should memoize the runtime dir and keep cleanup registrations in the parent shell"

dotforge_apply_prompt_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-apply-prompt.XXXXXX")
    dotforge_lib=$(mktemp "'"$ROOT"'/bin/dotforge-lib.XXXXXX")
    trap "rm -rf \"$test_root\" \"$dotforge_lib\"" EXIT INT TERM
    /usr/bin/sed "\$d" "'"$ROOT"'/bin/dotforge" >"$dotforge_lib"
    DOTFORGE_ROOT="'"$ROOT"'"
    DOTFORGE_STATE_DIR="$test_root/state"
    DOTFORGE_SECRETS_BUNDLE="$test_root/bundle.tar.age"
    mkdir -p "$DOTFORGE_STATE_DIR"
    mkdir -p "$test_root/source/ssh"
    printf "secret\n" >"$test_root/source/ssh/bitbucket_work"
    printf "secret\n" >"$test_root/source/ssh/hetzner"
    printf "secret\n" >"$test_root/source/ssh/personal"
    mkdir -p "$test_root/source/opencode"
    printf "token\n" >"$test_root/source/opencode/gsmcp_token"
    tar -cf "$test_root/archive.tar" -C "$test_root/source" ssh opencode
    printf "bundle\n" >"$DOTFORGE_SECRETS_BUNDLE"
    : >"$test_root/prompt.log"
    . "$dotforge_lib"
    prompt_for_age_passphrase() {
      printf "prompt\n" >>"$test_root/prompt.log"
      printf "expected-passphrase"
    }
    age_run() {
      local mode=$1
      shift
      if [[ "$mode" == "decrypt" ]]; then
        local output=""
        while [[ $# -gt 0 ]]; do
          if [[ "$1" == "-o" ]]; then
            output=$2
            shift 2
            continue
          fi
          shift
        done
        cp "$test_root/archive.tar" "$output"
      fi
    }
    require_supported_platform() { DOTFORGE_PLATFORM=macos; }
    restore_interactive_stdin() { :; }
    collect_config_inputs_if_needed() { :; }
    ensure_sudo_session() { :; }
    start_sudo_keepalive() { :; }
    bootstrap_platform_prerequisites() { :; }
    detect_shell_context() {
      DOTFORGE_CURRENT_SHELL=/bin/zsh
      DOTFORGE_LOGIN_SHELL=/bin/zsh
    }
    ensure_config_ready() { :; }
    reconcile_packages() { :; }
    deploy_managed_assets() { :; }
    run_post_install_steps() { :; }
    doctor_run() { :; }
    info() { :; }
    dotforge_apply
    wc -l <"$test_root/prompt.log" | awk "{print \$1}"
  '
)
assert_eq "1" "$dotforge_apply_prompt_output" "dotforge_apply should prompt for the age passphrase only once per run"

dotforge_unpack_prompt_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-unpack-prompt.XXXXXX")
    dotforge_lib=$(mktemp "'"$ROOT"'/bin/dotforge-lib.XXXXXX")
    trap "rm -rf \"$test_root\" \"$dotforge_lib\"" EXIT INT TERM
    /usr/bin/sed "\$d" "'"$ROOT"'/bin/dotforge" >"$dotforge_lib"
    DOTFORGE_ROOT="'"$ROOT"'"
    DOTFORGE_STATE_DIR="$test_root/state"
    DOTFORGE_SECRETS_BUNDLE="$test_root/bundle.tar.age"
    mkdir -p "$DOTFORGE_STATE_DIR"
    mkdir -p "$test_root/source/ssh"
    printf "secret\n" >"$test_root/source/ssh/key"
    tar -cf "$test_root/archive.tar" -C "$test_root/source" ssh
    printf "bundle\n" >"$DOTFORGE_SECRETS_BUNDLE"
    : >"$test_root/prompt.log"
    . "$dotforge_lib"
    prompt_for_age_passphrase() {
      printf "prompt\n" >>"$test_root/prompt.log"
      printf "expected-passphrase"
    }
    age_run() {
      local mode=$1
      shift
      if [[ "$mode" == "decrypt" ]]; then
        local output=""
        while [[ $# -gt 0 ]]; do
          if [[ "$1" == "-o" ]]; then
            output=$2
            shift 2
            continue
          fi
          shift
        done
        cp "$test_root/archive.tar" "$output"
      fi
    }
    require_supported_platform() { DOTFORGE_PLATFORM=macos; }
    restore_interactive_stdin() { :; }
    collect_config_inputs_if_needed() { :; }
    ensure_sudo_session() { :; }
    start_sudo_keepalive() { :; }
    bootstrap_platform_prerequisites() { :; }
    ensure_config_ready() { :; }
    info() { :; }
    doctor_run() { :; }
    secrets_command unpack
    wc -l <"$test_root/prompt.log" | awk "{print \$1}"
  '
)
assert_eq "1" "$dotforge_unpack_prompt_output" "dotforge secrets unpack should prompt for the age passphrase only once per run"

dotforge_pack_prompt_output=$(
  bash -lc '
    set -euo pipefail
    test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-pack-prompt.XXXXXX")
    dotforge_lib=$(mktemp "'"$ROOT"'/bin/dotforge-lib.XXXXXX")
    trap "rm -rf \"$test_root\" \"$dotforge_lib\"" EXIT INT TERM
    /usr/bin/sed "\$d" "'"$ROOT"'/bin/dotforge" >"$dotforge_lib"
    DOTFORGE_ROOT="'"$ROOT"'"
    DOTFORGE_STATE_DIR="$test_root/state"
    DOTFORGE_SECRETS_BUNDLE="$test_root/bundle.tar.age"
    mkdir -p "$DOTFORGE_STATE_DIR"
    mkdir -p "$test_root/source/ssh"
    printf "secret\n" >"$test_root/source/ssh/key"
    mkdir -p "$test_root/runtime/ssh"
    printf "runtime-secret\n" >"$test_root/runtime/ssh/key"
    tar -cf "$test_root/archive.tar" -C "$test_root/runtime" ssh
    printf "bundle\n" >"$DOTFORGE_SECRETS_BUNDLE"
    : >"$test_root/prompt.log"
    . "$dotforge_lib"
    prompt_for_age_passphrase() {
      printf "prompt\n" >>"$test_root/prompt.log"
      printf "expected-passphrase"
    }
    age_run() {
      local mode=$1
      shift
      local output=""
      while [[ $# -gt 0 ]]; do
        if [[ "$1" == "-o" ]]; then
          output=$2
          shift 2
          continue
        fi
        shift
      done
      if [[ "$mode" == "encrypt" ]]; then
        printf "bundle\n" >"$output"
        return 0
      fi
      if [[ "$mode" == "decrypt" ]]; then
        cp "$test_root/archive.tar" "$output"
        return 0
      fi
    }
    require_supported_platform() { DOTFORGE_PLATFORM=macos; }
    restore_interactive_stdin() { :; }
    collect_config_inputs_if_needed() { :; }
    ensure_sudo_session() { :; }
    start_sudo_keepalive() { :; }
    bootstrap_platform_prerequisites() { :; }
    ensure_config_ready() { :; }
    deploy_ssh_assets() { :; }
    info() { :; }
    doctor_run() { :; }
    secrets_command pack "$test_root/source"
    wc -l <"$test_root/prompt.log" | awk "{print \$1}"
  '
)
assert_eq "1" "$dotforge_pack_prompt_output" "dotforge secrets pack should prompt for the age passphrase only once per run"

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
