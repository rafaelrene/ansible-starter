#!/usr/bin/env bash

doctor_errors=0
doctor_warnings=0

doctor_error() {
  doctor_errors=$((doctor_errors + 1))
  warn "$1"
}

doctor_warning() {
  doctor_warnings=$((doctor_warnings + 1))
  warn "$1"
}

doctor_run() {
  require_supported_platform
  doctor_errors=0
  doctor_warnings=0

  doctor_check_prerequisites
  doctor_check_packages
  doctor_check_symlinks
  doctor_check_opencode
  doctor_check_ssh
  doctor_check_local_secrets
  doctor_check_path_injection
  doctor_check_post_install

  if ((doctor_errors > 0)); then
    die_with_fix \
      "dotforge doctor found $doctor_errors error(s)." \
      "One or more managed resources are missing or inconsistent." \
      "Review the warnings above, fix the reported issues, and rerun 'dotforge doctor'."
  fi

  info "dotforge doctor completed successfully with $doctor_warnings warning(s)."
}

doctor_check_prerequisites() {
  case "$DOTFORGE_PLATFORM" in
    macos)
      command_exists brew || doctor_error "Homebrew is missing."
      command_exists age || doctor_error "age is missing."
      ;;
    arch)
      command_exists yay || doctor_error "yay is missing."
      command_exists age || doctor_error "age is missing."
      ;;
  esac

  [[ -x "$DOTFORGE_BIN_DIR/dotforge" ]] || doctor_error "The dotforge executable is missing from '$DOTFORGE_BIN_DIR/dotforge'."
}

doctor_check_packages() {
  local csv
  local spec source manager kind tap package token

  csv=$(config_package_tokens)
  while IFS= read -r spec; do
    [[ -n "$spec" ]] || continue
    IFS='|' read -r source manager kind tap package token <<EOF
$spec
EOF
    case "$manager:$kind" in
      brew:formula)
        brew list --formula "$package" >/dev/null 2>&1 || doctor_error "Missing Homebrew formula '$package' required by token '$token'."
        ;;
      brew:cask)
        brew list --cask "$package" >/dev/null 2>&1 || doctor_error "Missing Homebrew cask '$package' required by token '$token'."
        ;;
      brew:raw)
        brew list "$package" >/dev/null 2>&1 || doctor_error "Missing Homebrew package '$package' required by token '$token'."
        ;;
      yay:*)
        yay -Q "$package" >/dev/null 2>&1 || doctor_error "Missing Arch package '$package' required by token '$token'."
        ;;
    esac
  done <<EOF
$(resolve_csv_to_specs "$csv")
EOF
}

doctor_check_symlinks() {
  doctor_expect_symlink "$HOME/.config/git" "$DOTFORGE_ASSETS_DIR/config/git"
  doctor_expect_symlink "$HOME/.config/ghostty" "$DOTFORGE_ASSETS_DIR/config/ghostty"
  doctor_expect_symlink "$HOME/.config/graphite" "$DOTFORGE_ASSETS_DIR/config/graphite"
  doctor_expect_symlink "$HOME/.config/nushell" "$DOTFORGE_ASSETS_DIR/config/nushell"
  doctor_expect_symlink "$HOME/.config/nvim" "$DOTFORGE_ASSETS_DIR/config/nvim"
  doctor_expect_symlink "$HOME/.config/custom-nvim-config" "$DOTFORGE_ASSETS_DIR/config/custom-nvim-config"
  doctor_expect_symlink "$HOME/.config/starship" "$DOTFORGE_ASSETS_DIR/config/starship"
  doctor_expect_symlink "$HOME/.config/tmux" "$DOTFORGE_ASSETS_DIR/config/tmux"
  doctor_expect_symlink "$HOME/.config/zsh" "$DOTFORGE_ASSETS_DIR/config/zsh"
  doctor_expect_symlink "$HOME/.zshenv" "$DOTFORGE_ASSETS_DIR/home/.zshenv"
  if [[ "$DOTFORGE_PLATFORM" == "macos" ]]; then
    doctor_expect_symlink "$HOME/.config/sketchybar" "$DOTFORGE_ASSETS_DIR/config/sketchybar"
  fi
}

doctor_check_opencode() {
  local opencode_dir="$HOME/.config/opencode"
  local opencode_config="$opencode_dir/opencode.jsonc"
  local expected_ref="{file:$DOTFORGE_LOCAL_SECRETS_DIR/OPENCODE_GSMCP_TOKEN}"

  doctor_expect_symlink "$opencode_dir" "$DOTFORGE_ASSETS_DIR/config/opencode"
  [[ -f "$opencode_config" ]] || doctor_error "The opencode config '$opencode_config' is missing."
  if [[ -f "$opencode_config" ]]; then
    grep -F "$expected_ref" "$opencode_config" >/dev/null 2>&1 || doctor_error \
      "The opencode config '$opencode_config' does not reference '$expected_ref'."
  fi
}

doctor_expect_symlink() {
  local target=$1
  local expected_source=$2
  if [[ ! -L "$target" ]]; then
    doctor_error "Managed path '$target' is not a symlink."
    return 0
  fi
  if [[ "$(readlink "$target")" != "$expected_source" ]]; then
    doctor_error "Managed path '$target' points to '$(readlink "$target")' instead of '$expected_source'."
  fi
}

doctor_check_ssh() {
  local ssh_dir="$HOME/.ssh"
  local entry
  local target_path expected_hash actual_hash

  [[ -d "$ssh_dir" ]] || doctor_error "The SSH directory '$ssh_dir' is missing."
  [[ -f "$ssh_dir/config" ]] || doctor_error "The SSH config '$ssh_dir/config' is missing."

  if [[ -f "$DOTFORGE_SECRETS_HASHES_FILE" ]]; then
    while IFS= read -r entry; do
      [[ -n "$entry" ]] || continue
      target_path=${entry%%|*}
      expected_hash=${entry#*|}

      if [[ ! -f "$target_path" ]]; then
        doctor_error "Expected secret file '$target_path' is missing."
        continue
      fi

      actual_hash=$(hash_file "$target_path")
      [[ "$actual_hash" == "$expected_hash" ]] || doctor_error "Secret file '$target_path' does not match the last deployed secrets store."
    done <"$DOTFORGE_SECRETS_HASHES_FILE"
  else
    doctor_error "The secrets state file '$DOTFORGE_SECRETS_HASHES_FILE' is missing."
  fi

  if [[ -f "$ssh_dir/config" ]] && [[ "$(stat_mode "$ssh_dir/config")" != "600" ]]; then
    doctor_error "SSH config '$ssh_dir/config' does not have mode 600."
  fi

  for target_path in "$ssh_dir"/bitbucket_work "$ssh_dir"/hetzner "$ssh_dir"/personal; do
    if [[ -f "$target_path" ]] && [[ "$(stat_mode "$target_path")" != "600" ]]; then
      doctor_error "SSH private key '$target_path' does not have mode 600."
    fi
  done

  if ssh-add -l >/dev/null 2>&1; then
    ssh-add -l >/dev/null 2>&1 || doctor_warning "ssh-agent is reachable but the expected keys are not loaded."
  else
    doctor_warning "No reachable ssh-agent session was found while running doctor."
  fi
}

doctor_check_local_secrets() {
  local target_dir="$DOTFORGE_LOCAL_SECRETS_DIR"
  local target_path

  [[ -d "$target_dir" ]] || doctor_error "The local secrets directory '$target_dir' is missing."
  if [[ -d "$target_dir" ]] && [[ "$(stat_mode "$target_dir")" != "700" ]]; then
    doctor_error "The local secrets directory '$target_dir' does not have mode 700."
  fi

  for target_path in \
    "$target_dir/OPENCODE_GSMCP_TOKEN" \
    "$target_dir/SSH_BITBUCKET_WORK" \
    "$target_dir/SSH_HETZNER" \
    "$target_dir/SSH_PERSONAL"; do
    [[ -f "$target_path" ]] || doctor_error "Expected local secret file '$target_path' is missing."
    if [[ -f "$target_path" ]] && [[ "$(stat_mode "$target_path")" != "600" ]]; then
      doctor_error "Local secret file '$target_path' does not have mode 600."
    fi
  done
}

stat_mode() {
  local path=$1
  if stat -f '%Lp' "$path" >/dev/null 2>&1; then
    stat -f '%Lp' "$path"
  else
    stat -c '%a' "$path"
  fi
}

doctor_check_path_injection() {
  grep -F 'export PATH="$HOME/.local/share/dotforge/bin:$PATH"' "$HOME/.config/zsh/.zprofile" >/dev/null 2>&1 || doctor_error \
    "zsh PATH injection for dotforge is missing from '$HOME/.config/zsh/.zprofile'."
  grep -F 'path add ($env.HOME | path join ".local" "share" "dotforge" "bin")' "$HOME/.config/nushell/config.nu" >/dev/null 2>&1 || doctor_error \
    "nushell PATH injection for dotforge is missing from '$HOME/.config/nushell/config.nu'."
}

doctor_check_post_install() {
  local csv
  csv=$(config_package_tokens)

  if csv_contains_token "$csv" volta; then
    command_exists volta || doctor_error "Volta is selected but the 'volta' command is missing."
    if command_exists volta; then
      volta which node >/dev/null 2>&1 || doctor_error "Volta is installed but does not manage a Node runtime yet."
    fi
  fi

  if csv_contains_token "$csv" tmux; then
    [[ -d "$HOME/.config/tmux/plugins/catppuccin" ]] || doctor_error \
      "tmux is selected but the Catppuccin TPM plugin is missing from '$HOME/.config/tmux/plugins/catppuccin'."
  fi
}
