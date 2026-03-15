self_command() {
  local subcommand="${1:-}"

  case "$subcommand" in
    update)
      self_update
      ;;
    clean)
      self_clean
      ;;
    *)
      die_with_fix \
        "Unsupported self subcommand: ${subcommand:-<empty>}" \
        "dotforge self only supports update and clean." \
        "Use 'dotforge self update' or 'dotforge self clean'."
      ;;
  esac
}

self_repo_dir() {
  printf '%s\n' "$DOTFORGE_ROOT"
}

self_require_git() {
  command_exists git || die_with_fix \
    "git is required for dotforge self management." \
    "dotforge self delegates checkout inspection and updates to git." \
    "Install git and rerun the command."
}

self_require_checkout() {
  local repo_dir=$1

  git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1 || die_with_fix \
    "The dotforge checkout is not a git repository." \
    "dotforge self can only manage a checkout that has git metadata at '$repo_dir'." \
    "Reinstall dotforge or run the command from a normal dotforge checkout."
}

self_current_branch() {
  local repo_dir=$1
  local branch=""

  branch=$(git -C "$repo_dir" symbolic-ref --quiet --short HEAD) || die_with_fix \
    "The dotforge checkout is not on a branch." \
    "dotforge self only supports a normal branch checkout, not detached HEAD state." \
    "Check out the branch you want to manage, then rerun the command."

  printf '%s\n' "$branch"
}

self_fetch_branch() {
  local repo_dir=$1
  local branch=$2

  git -C "$repo_dir" fetch origin "$branch" || die_with_fix \
    "Failed to fetch dotforge updates." \
    "git could not fetch 'origin/$branch' for the dotforge checkout." \
    "Verify network access and that the branch exists on origin, then rerun the command."
}

self_status_short() {
  local repo_dir=$1
  git -C "$repo_dir" status --short
}

self_local_only_commits() {
  local repo_dir=$1
  local branch=$2
  git -C "$repo_dir" log --oneline "origin/$branch..HEAD"
}

self_render_local_state() {
  local status_short=$1
  local local_commits=$2

  printf 'Local file changes:\n'
  if [[ -n "$status_short" ]]; then
    printf '%s\n' "$status_short"
  else
    printf '(none)\n'
  fi

  printf 'Unpushed commits:\n'
  if [[ -n "$local_commits" ]]; then
    printf '%s\n' "$local_commits"
  else
    printf '(none)\n'
  fi
}

self_update() {
  local repo_dir
  local branch
  local status_short
  local local_commits
  local details

  self_require_git
  repo_dir=$(self_repo_dir)
  self_require_checkout "$repo_dir"
  branch=$(self_current_branch "$repo_dir")
  self_fetch_branch "$repo_dir" "$branch"

  status_short=$(self_status_short "$repo_dir")
  local_commits=$(self_local_only_commits "$repo_dir" "$branch")

  if [[ -n "$status_short" || -n "$local_commits" ]]; then
    details=$(self_render_local_state "$status_short" "$local_commits")
    die_with_fix \
      "Refusing to update the dotforge checkout while local changes are present." \
      "$details" \
      "Commit and push the changes, or run 'dotforge self clean' to discard them before retrying."
  fi

  info "Updating dotforge checkout from origin/$branch."
  git -C "$repo_dir" reset --hard "origin/$branch" >/dev/null 2>&1 || die_with_fix \
    "Failed to update the dotforge checkout." \
    "git could not reset the checkout at '$repo_dir' to 'origin/$branch'." \
    "Verify that origin/$branch exists and rerun the command."
}

self_clean() {
  local repo_dir
  local branch

  self_require_git
  repo_dir=$(self_repo_dir)
  self_require_checkout "$repo_dir"
  branch=$(self_current_branch "$repo_dir")
  self_fetch_branch "$repo_dir" "$branch"

  info "Resetting dotforge checkout to origin/$branch."
  git -C "$repo_dir" reset --hard "origin/$branch" >/dev/null 2>&1 || die_with_fix \
    "Failed to reset the dotforge checkout." \
    "git could not reset the checkout at '$repo_dir' to 'origin/$branch'." \
    "Verify that origin/$branch exists and rerun the command."

  git -C "$repo_dir" clean -fd >/dev/null 2>&1 || die_with_fix \
    "Failed to remove untracked files from the dotforge checkout." \
    "git could not clean untracked files from '$repo_dir'." \
    "Remove the untracked files manually or fix filesystem permissions, then rerun the command."
}
