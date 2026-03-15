#!/usr/bin/env bash

deploy_managed_assets() {
  local secrets_dir=$1
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/git" "$HOME/.config/git"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/ghostty" "$HOME/.config/ghostty"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/graphite" "$HOME/.config/graphite"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/nushell" "$HOME/.config/nushell"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/nvim" "$HOME/.config/nvim"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/opencode" "$HOME/.config/opencode"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/custom-nvim-config" "$HOME/.config/custom-nvim-config"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/starship" "$HOME/.config/starship"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/tmux" "$HOME/.config/tmux"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/zsh" "$HOME/.config/zsh"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/home/.zshenv" "$HOME/.zshenv"

  if [[ "$DOTFORGE_PLATFORM" == "macos" ]]; then
    deploy_symlink "$DOTFORGE_ASSETS_DIR/config/sketchybar" "$HOME/.config/sketchybar"
  fi

  deploy_ssh_assets "$secrets_dir"
}

deploy_symlink() {
  local source=$1
  local target=$2
  ensure_dir "$(dirname -- "$target")"

  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
    return 0
  fi

  safe_remove_path "$target"
  ln -s "$source" "$target" || die_with_fix \
    "Failed to create symlink '$target' -> '$source'." \
    "dotforge could not replace the managed path with the expected symlink." \
    "Check filesystem permissions and rerun dotforge."
}

copy_managed_file() {
  local source=$1
  local target=$2
  local mode=$3

  ensure_dir "$(dirname -- "$target")"
  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
    chmod "$mode" "$target"
    return 0
  fi

  cp "$source" "$target" || die_with_fix \
    "Failed to copy '$source' to '$target'." \
    "dotforge could not update a managed file on disk." \
    "Check filesystem permissions and rerun dotforge."
  chmod "$mode" "$target"
}

deploy_ssh_assets() {
  local secrets_dir=$1
  local ssh_dir="$HOME/.ssh"
  local hashes=()
  local file
  local private_key
  local secret_name
  local target

  ensure_dir "$ssh_dir"
  chmod 700 "$ssh_dir"

  copy_managed_file "$DOTFORGE_ASSETS_DIR/ssh/config" "$ssh_dir/config" 600
  for file in "$DOTFORGE_ASSETS_DIR"/ssh/*.pub; do
    copy_managed_file "$file" "$ssh_dir/$(basename -- "$file")" 644
  done

  for private_key in bitbucket_work hetzner personal; do
    case "$private_key" in
      bitbucket_work) secret_name=SSH_BITBUCKET_WORK ;;
      hetzner) secret_name=SSH_HETZNER ;;
      personal) secret_name=SSH_PERSONAL ;;
    esac
    target="$ssh_dir/$private_key"
    copy_managed_file "$secrets_dir/$secret_name" "$target" 600
    hashes+=("$target|$(hash_file "$target")")
  done

  write_state_lines "$DOTFORGE_SECRETS_HASHES_FILE" "${hashes[@]}"

  if ssh-add -l >/dev/null 2>&1; then
    ssh-add "$ssh_dir/bitbucket_work" "$ssh_dir/hetzner" "$ssh_dir/personal" >/dev/null 2>&1 || warn \
      "SSH keys were written to disk but could not be added to the current ssh-agent session."
  else
    warn "No reachable ssh-agent session was found. Start an ssh-agent or open a new shell before using the new keys."
  fi
}

install_tmux_plugins() {
  command_exists tmux || die_with_fix \
    "tmux is selected but the 'tmux' command is not available." \
    "The package manager step did not leave a working tmux installation." \
    "Fix the tmux package installation and rerun dotforge."

  local conf_path="$HOME/.config/tmux/tmux.conf"
  local installer="$HOME/.config/tmux/tpm/bin/install_plugins"
  local started_session=0
  local session_name="dotforge-bootstrap-$$"

  [[ -f "$conf_path" ]] || die_with_fix \
    "The tmux config '$conf_path' is missing." \
    "dotforge could not load tmux before installing TPM plugins." \
    "Verify the managed tmux assets and rerun dotforge."

  [[ -x "$installer" ]] || die_with_fix \
    "The TPM installer '$installer' is missing." \
    "dotforge could not find the vendored tmux plugin installer." \
    "Verify the tmux assets and rerun dotforge."

  if ! tmux ls >/dev/null 2>&1; then
    tmux new-session -d -s "$session_name" || die_with_fix \
      "Failed to start a temporary tmux server." \
      "dotforge could not create the detached tmux session needed for TPM setup." \
      "Verify that tmux works normally and rerun dotforge."
    started_session=1
  fi

  tmux source-file "$conf_path" >/dev/null 2>&1 || die_with_fix \
    "Failed to source '$conf_path' in tmux." \
    "tmux rejected the managed configuration while dotforge was preparing TPM." \
    "Fix the tmux config error and rerun dotforge."

  "$installer" >/dev/null 2>&1 || die_with_fix \
    "Failed to install tmux plugins with TPM." \
    "dotforge could not install the managed tmux plugins, including Catppuccin." \
    "Resolve the TPM error and rerun dotforge."

  tmux source-file "$conf_path" >/dev/null 2>&1 || die_with_fix \
    "Failed to reload '$conf_path' after installing tmux plugins." \
    "tmux could not apply the managed theme and plugin settings after TPM completed." \
    "Fix the tmux config or plugin state and rerun dotforge."

  if [[ $started_session -eq 1 ]]; then
    tmux kill-session -t "$session_name" >/dev/null 2>&1 || true
  fi
}

run_post_install_steps() {
  local csv
  csv=$(config_package_tokens)

  if csv_contains_token "$csv" volta; then
    command_exists volta || die_with_fix \
      "Volta is selected but the 'volta' command is not available." \
      "The package manager step did not leave a working Volta installation." \
      "Fix the Volta package installation and rerun dotforge."
    volta install node || die_with_fix \
      "Failed to install Node with Volta." \
      "The post-install Volta step did not complete successfully." \
      "Fix the Volta error shown above and rerun dotforge."
  fi

  if csv_contains_token "$csv" tmux; then
    install_tmux_plugins
  fi

  if csv_contains_token "$csv" zsh; then
    ensure_login_shell_is_zsh
  fi
}
