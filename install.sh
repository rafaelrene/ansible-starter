#!/usr/bin/env bash

set -euo pipefail

DOTFORGE_GIT_REPOSITORY=${DOTFORGE_GIT_REPOSITORY:-rafaelrene/dotforge}
DOTFORGE_GIT_BRANCH=${DOTFORGE_GIT_BRANCH:-master}
DOTFORGE_INSTALL_HOME=${DOTFORGE_INSTALL_HOME:-"$HOME/.local/share/dotforge"}

die() {
  local what=$1
  local cause=$2
  local fix=$3
  {
    printf 'ERROR: %s\n' "$what"
    printf 'Cause: %s\n' "$cause"
    printf 'Fix: %s\n' "$fix"
  } >&2
  exit 1
}

detect_platform() {
  case "$(uname -s)" in
    Darwin)
      printf 'macos\n'
      ;;
    Linux)
      if [[ -r /etc/os-release ]] && grep -Eq '^ID=arch$|^ID_LIKE=.*arch' /etc/os-release; then
        printf 'arch\n'
      else
        printf 'unsupported\n'
      fi
      ;;
    *)
      printf 'unsupported\n'
      ;;
  esac
}

ensure_git() {
  local platform=$1

  if command -v git >/dev/null 2>&1; then
    return 0
  fi

  case "$platform" in
    macos)
      if ! xcode-select -p >/dev/null 2>&1; then
        xcode-select --install >/dev/null 2>&1 || true
        die \
          "git is not available because Xcode Command Line Tools are missing." \
          "macOS does not provide git until Command Line Tools are installed." \
          "Complete the GUI installer started by 'xcode-select --install', then rerun install.sh."
      fi
      die \
        "git is still unavailable after verifying Command Line Tools." \
        "The system should provide git once Command Line Tools are installed, but it is not on PATH." \
        "Open a new shell or fix the Command Line Tools installation, then rerun install.sh."
      ;;
    arch)
      sudo pacman -Sy --needed --noconfirm git || die \
        "Failed to install git with pacman." \
        "install.sh needs git before it can clone dotforge." \
        "Fix the pacman error above and rerun install.sh."
      ;;
    *)
      die \
        "Unsupported operating system." \
        "install.sh only supports macOS and Arch Linux." \
        "Run install.sh on macOS or Arch Linux."
      ;;
  esac
}

clone_url_from_slug() {
  printf 'https://github.com/%s.git\n' "$1"
}

update_checkout() {
  local repo_dir=$1
  local branch=$2

  [[ -d "$repo_dir/.git" ]] || die \
    "The install directory '$repo_dir' already exists but is not a git checkout." \
    "install.sh only knows how to update dotforge when the directory is a git repository." \
    "Remove or rename '$repo_dir', then rerun install.sh."

  if [[ -n "$(git -C "$repo_dir" status --porcelain)" ]]; then
    die \
      "The existing dotforge checkout is dirty." \
      "install.sh refuses to overwrite local changes in '$repo_dir'." \
      "Commit, stash, or discard the local changes, then rerun install.sh."
  fi

  git -C "$repo_dir" fetch origin "$branch" || die \
    "Failed to fetch dotforge updates." \
    "git could not fetch the configured branch from origin." \
    "Verify network access and the configured repository/branch, then rerun install.sh."
  git -C "$repo_dir" checkout "$branch" >/dev/null 2>&1 || git -C "$repo_dir" checkout -B "$branch" "origin/$branch" >/dev/null 2>&1 || die \
    "Failed to check out branch '$branch'." \
    "git could not switch the existing checkout to the requested branch." \
    "Verify that the branch exists on origin, then rerun install.sh."
  git -C "$repo_dir" reset --hard "origin/$branch" >/dev/null 2>&1 || die \
    "Failed to fast-forward the dotforge checkout." \
    "git could not reset the clean checkout to the requested remote branch." \
    "Verify that origin/$branch exists and rerun install.sh."
}

main() {
  local platform
  local clone_url

  platform=$(detect_platform)
  [[ "$platform" != "unsupported" ]] || die \
    "Unsupported operating system." \
    "install.sh only supports macOS and Arch Linux." \
    "Run install.sh on macOS or Arch Linux."

  ensure_git "$platform"

  mkdir -p "$(dirname -- "$DOTFORGE_INSTALL_HOME")"
  clone_url=$(clone_url_from_slug "$DOTFORGE_GIT_REPOSITORY")

  if [[ -d "$DOTFORGE_INSTALL_HOME" ]]; then
    update_checkout "$DOTFORGE_INSTALL_HOME" "$DOTFORGE_GIT_BRANCH"
  else
    git clone --branch "$DOTFORGE_GIT_BRANCH" "$clone_url" "$DOTFORGE_INSTALL_HOME" || die \
      "Failed to clone dotforge." \
      "git could not clone the configured repository and branch into '$DOTFORGE_INSTALL_HOME'." \
      "Verify DOTFORGE_GIT_REPOSITORY/DOTFORGE_GIT_BRANCH and rerun install.sh."
  fi

  export PATH="$DOTFORGE_INSTALL_HOME/bin:$PATH"
  exec "$DOTFORGE_INSTALL_HOME/bin/dotforge"
}

main "$@"
