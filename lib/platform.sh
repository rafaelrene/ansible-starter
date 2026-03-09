#!/usr/bin/env bash

detect_platform() {
  if [[ -n "$DOTFORGE_PLATFORM" ]]; then
    return 0
  fi

  case "$(uname -s)" in
    Darwin)
      DOTFORGE_PLATFORM=macos
      ;;
    Linux)
      if [[ -r /etc/os-release ]] && grep -Eq '^ID=arch$|^ID_LIKE=.*arch' /etc/os-release; then
        DOTFORGE_PLATFORM=arch
      else
        DOTFORGE_PLATFORM=unsupported
      fi
      ;;
    *)
      DOTFORGE_PLATFORM=unsupported
      ;;
  esac
}

require_supported_platform() {
  detect_platform
  if [[ "$DOTFORGE_PLATFORM" == "unsupported" ]]; then
    die_with_fix \
      "Unsupported operating system." \
      "dotforge currently supports only macOS and Arch Linux." \
      "Run dotforge on macOS or Arch Linux."
  fi
}

homebrew_candidate_paths() {
  printf '/opt/homebrew/bin/brew\n'
  printf '/usr/local/bin/brew\n'
}

hydrate_homebrew_environment() {
  local brew_path=""
  local candidate

  if command_exists brew; then
    brew_path=$(command -v brew)
  else
    while IFS= read -r candidate; do
      [[ -n "$candidate" ]] || continue
      if [[ -x "$candidate" ]]; then
        brew_path=$candidate
        break
      fi
    done <<EOF
$(homebrew_candidate_paths)
EOF
  fi

  [[ -n "$brew_path" ]] || return 1

  eval "$("$brew_path" shellenv)"
  command_exists brew
}

ensure_sudo_session() {
  if sudo -n true >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$DOTFORGE_NONINTERACTIVE" == "1" ]]; then
    die_with_fix \
      "sudo authentication is required." \
      "dotforge is running non-interactively and there is no valid sudo timestamp." \
      "Authenticate with 'sudo -v' first or configure passwordless sudo, then rerun dotforge."
  fi

  info "Requesting sudo access up front."
  run_with_interactive_tty sudo -v || die_with_fix \
    "sudo authentication failed." \
    "dotforge could not obtain administrator privileges needed for package installation." \
    "Retry the command, enter the correct password, and rerun dotforge."
}

start_sudo_keepalive() {
  if [[ -n "$DOTFORGE_SUDO_KEEPALIVE_PID" ]]; then
    return 0
  fi

  (
    while true; do
      sudo -n true >/dev/null 2>&1 || exit 0
      sleep 30
    done
  ) </dev/null &
  DOTFORGE_SUDO_KEEPALIVE_PID=$!
  register_cleanup "kill $DOTFORGE_SUDO_KEEPALIVE_PID >/dev/null 2>&1"
}

bootstrap_platform_prerequisites() {
  require_supported_platform
  case "$DOTFORGE_PLATFORM" in
    macos)
      ensure_macos_command_line_tools
      ensure_homebrew
      ensure_brew_prerequisite age
      ensure_brew_prerequisite python
      ;;
    arch)
      ensure_arch_packages_installed base-devel git age python
      ensure_yay
      ;;
  esac
}

ensure_macos_command_line_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    return 0
  fi

  xcode-select --install >/dev/null 2>&1 || true
  die_with_fix \
    "Xcode Command Line Tools are missing." \
    "macOS requires Command Line Tools before Homebrew and git-based setup can run." \
    "Complete the GUI installer started by 'xcode-select --install', then rerun dotforge."
}

ensure_homebrew() {
  if command_exists brew; then
    hydrate_homebrew_environment || die_with_fix \
      "Homebrew is installed but could not be loaded into the current shell." \
      "dotforge found Homebrew on PATH, but 'brew shellenv' did not complete successfully." \
      "Run 'eval \"$(brew shellenv)\"' manually, verify Homebrew works, and rerun dotforge."
    return 0
  fi

  if hydrate_homebrew_environment; then
    return 0
  fi

  if [[ "$DOTFORGE_NONINTERACTIVE" == "1" ]]; then
    die_with_fix \
      "Homebrew must already be installed for non-interactive macOS runs." \
      "Automatic Homebrew bootstrap requires an interactive terminal session." \
      "Install Homebrew manually first, then rerun dotforge with DOTFORGE_NONINTERACTIVE=1."
  fi

  info "Installing Homebrew."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || die_with_fix \
    "Homebrew installation failed." \
    "The official Homebrew installer exited with an error." \
    "Resolve the Homebrew installer error shown above, then rerun dotforge."

  hydrate_homebrew_environment || die_with_fix \
    "Homebrew was installed but could not be loaded into the current shell." \
    "dotforge completed the Homebrew installer, but the new Homebrew environment could not be imported." \
    "Run 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' or 'eval \"$(/usr/local/bin/brew shellenv)\"' as appropriate, then rerun dotforge."
}

ensure_brew_prerequisite() {
  local package=$1
  hydrate_homebrew_environment || die_with_fix \
    "Homebrew is required but unavailable in the current shell." \
    "dotforge could not locate a working Homebrew installation before checking prerequisite packages." \
    "Verify that Homebrew is installed and working, then rerun dotforge."

  if brew list --formula "$package" >/dev/null 2>&1; then
    return 0
  fi

  brew install "$package" || die_with_fix \
    "Failed to install prerequisite package '$package' with Homebrew." \
    "dotforge requires this tool before it can continue." \
    "Install '$package' manually with Homebrew and rerun dotforge."
}

ensure_arch_packages_installed() {
  local package
  local missing=()
  for package in "$@"; do
    if ! pacman -Q "$package" >/dev/null 2>&1; then
      missing+=("$package")
    fi
  done

  [[ ${#missing[@]} -eq 0 ]] && return 0

  sudo pacman -Sy --needed --noconfirm "${missing[@]}" || die_with_fix \
    "Failed to install Arch bootstrap packages." \
    "pacman could not install the prerequisites dotforge needs." \
    "Review the pacman error output, fix the package manager issue, and rerun dotforge."
}

ensure_yay() {
  if command_exists yay; then
    return 0
  fi

  local temp_dir
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-yay.XXXXXX")
  register_cleanup "best_effort_wipe '$temp_dir'"

  (
    cd "$temp_dir" &&
      git clone https://aur.archlinux.org/yay.git &&
      cd yay &&
      makepkg -si --noconfirm
  ) || die_with_fix \
    "Failed to bootstrap yay." \
    "dotforge could not build or install yay from the AUR." \
    "Ensure base-devel and git are installed and the AUR build succeeds, then rerun dotforge."
}
