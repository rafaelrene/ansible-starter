#!/usr/bin/env bash

deploy_managed_assets() {
  local secrets_dir=$1
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/git" "$HOME/.config/git"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/ghostty" "$HOME/.config/ghostty"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/graphite" "$HOME/.config/graphite"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/nushell" "$HOME/.config/nushell"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/nvim" "$HOME/.config/nvim"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/custom-nvim-config" "$HOME/.config/custom-nvim-config"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/starship" "$HOME/.config/starship"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/tmux" "$HOME/.config/tmux"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/zsh" "$HOME/.config/zsh"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/home/.zshenv" "$HOME/.zshenv"

  if [[ "$DOTFORGE_PLATFORM" == "macos" ]]; then
    deploy_symlink "$DOTFORGE_ASSETS_DIR/config/sketchybar" "$HOME/.config/sketchybar"
  fi

  deploy_ssh_assets "$secrets_dir"
  deploy_opencode_assets "$secrets_dir"
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
  local target

  ensure_dir "$ssh_dir"
  chmod 700 "$ssh_dir"

  copy_managed_file "$DOTFORGE_ASSETS_DIR/ssh/config" "$ssh_dir/config" 600
  for file in "$DOTFORGE_ASSETS_DIR"/ssh/*.pub; do
    copy_managed_file "$file" "$ssh_dir/$(basename -- "$file")" 644
  done

  for private_key in bitbucket_work hetzner personal; do
    target="$ssh_dir/$private_key"
    copy_managed_file "$secrets_dir/ssh/$private_key" "$target" 600
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

deploy_opencode_assets() {
  local secrets_dir=$1
  local target_dir="$HOME/.config/opencode"
  local rendered_file="$target_dir/opencode.jsonc"
  local template="$DOTFORGE_ASSETS_DIR/config/opencode/opencode.jsonc.template"
  local token_file="$secrets_dir/opencode/gsmcp_token"
  local token

  ensure_dir "$target_dir"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/opencode/.opencode" "$target_dir/.opencode"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/opencode/agent" "$target_dir/agent"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/opencode/skills" "$target_dir/skills"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/opencode/AGENTS.md" "$target_dir/AGENTS.md"
  deploy_symlink "$DOTFORGE_ASSETS_DIR/config/opencode/tui.json" "$target_dir/tui.json"

  [[ -f "$token_file" ]] || die_with_fix \
    "The decrypted secrets bundle is missing 'opencode/gsmcp_token'." \
    "dotforge now expects the opencode MCP token to be stored in the encrypted bundle." \
    "Run 'dotforge secrets unpack', add opencode/gsmcp_token, repack, and rerun dotforge."

  token=$(cat "$token_file")
  sed "s|__DOTFORGE_GSMCP_TOKEN__|$token|g" "$template" >"$rendered_file" || die_with_fix \
    "Failed to render the opencode config." \
    "dotforge could not materialize the opencode config from the template and decrypted token." \
    "Verify the template and secret token, then rerun dotforge."
  chmod 600 "$rendered_file"

  if [[ -f "$DOTFORGE_SECRETS_HASHES_FILE" ]]; then
    local existing=()
    local entry
    while IFS= read -r entry; do
      [[ -n "$entry" ]] || continue
      existing+=("$entry")
    done <"$DOTFORGE_SECRETS_HASHES_FILE"
    existing+=("$rendered_file|$(hash_file "$rendered_file")")
    write_state_lines "$DOTFORGE_SECRETS_HASHES_FILE" "${existing[@]}"
  else
    write_state_lines "$DOTFORGE_SECRETS_HASHES_FILE" "$rendered_file|$(hash_file "$rendered_file")"
  fi
}

run_post_install_steps() {
  local csv
  csv=$(config_package_tokens)
  case ",$csv," in
    *,volta,*)
      command_exists volta || die_with_fix \
        "Volta is selected but the 'volta' command is not available." \
        "The package manager step did not leave a working Volta installation." \
        "Fix the Volta package installation and rerun dotforge."
      volta install node || die_with_fix \
        "Failed to install Node with Volta." \
        "The post-install Volta step did not complete successfully." \
        "Fix the Volta error shown above and rerun dotforge."
      ;;
  esac
}
