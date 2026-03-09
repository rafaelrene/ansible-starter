#!/usr/bin/env bash

prompt_for_age_passphrase() {
  if [[ -n "$DOTFORGE_AGE_PASSPHRASE" ]]; then
    printf '%s' "$DOTFORGE_AGE_PASSPHRASE"
    return 0
  fi

  if [[ "$DOTFORGE_NONINTERACTIVE" == "1" ]]; then
    die_with_fix \
      "Age passphrase is required." \
      "Non-interactive mode cannot prompt for the age passphrase." \
      "Set DOTFORGE_AGE_PASSPHRASE before rerunning dotforge."
  fi

  local passphrase
  printf 'Enter age passphrase: ' >&2
  stty -echo
  IFS= read -r passphrase
  stty echo
  printf '\n' >&2
  printf '%s' "$passphrase"
}

age_run() {
  local mode=$1
  shift

  if [[ -n "$DOTFORGE_AGE_PASSPHRASE" ]]; then
    command_exists python3 || die_with_fix \
      "python3 is required for non-interactive age passphrase automation." \
      "dotforge is using DOTFORGE_AGE_PASSPHRASE and must drive age through a pseudo-terminal." \
      "Install python3 or rerun dotforge interactively."

    DOTFORGE_AGE_PASSPHRASE="$DOTFORGE_AGE_PASSPHRASE" python3 "$DOTFORGE_HELPER_DIR/age_passphrase.py" "$mode" "$@"
  else
    age "$@"
  fi
}

validate_age_bundle_passphrase() {
  local temp_file
  temp_file=$(mktemp "${TMPDIR:-/tmp}/dotforge-age-check.XXXXXX")
  register_cleanup "rm -f '$temp_file'"
  age_run decrypt -d -o "$temp_file" "$DOTFORGE_SECRETS_BUNDLE" >/dev/null 2>&1 || die_with_fix \
    "Failed to decrypt '$DOTFORGE_SECRETS_BUNDLE'." \
    "The age passphrase is wrong or the encrypted bundle is corrupted." \
    "Retry with the correct passphrase. If the bundle is corrupted, restore it from git history."
}

prepare_runtime_secrets_dir() {
  [[ -f "$DOTFORGE_SECRETS_BUNDLE" ]] || die_with_fix \
    "Missing encrypted secrets bundle." \
    "dotforge expected '$DOTFORGE_SECRETS_BUNDLE' to exist before applying SSH secrets." \
    "Create the bundle with 'dotforge secrets pack <path>' or restore it from git."

  DOTFORGE_AGE_PASSPHRASE=$(prompt_for_age_passphrase)
  validate_age_bundle_passphrase

  local temp_dir archive_path
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-secrets.XXXXXX")
  archive_path="$temp_dir/bundle.tar"

  register_cleanup "best_effort_wipe '$temp_dir'"
  age_run decrypt -d -o "$archive_path" "$DOTFORGE_SECRETS_BUNDLE" >/dev/null || die_with_fix \
    "Failed to decrypt the secrets bundle." \
    "The age passphrase was accepted but the bundle could not be decrypted into a tar archive." \
    "Verify the bundle contents and rerun dotforge."

  tar -xf "$archive_path" -C "$temp_dir" || die_with_fix \
    "Failed to unpack the decrypted secrets bundle." \
    "The decrypted data is not a valid tar archive or extraction failed." \
    "Rebuild the bundle with 'dotforge secrets pack <path>' and rerun dotforge."

  [[ -d "$temp_dir/ssh" ]] || die_with_fix \
    "The decrypted bundle does not contain the expected 'ssh/' tree." \
    "dotforge only knows how to apply scoped secrets under ssh/ at the moment." \
    "Repack the bundle using 'dotforge secrets pack <path>' with an ssh/ directory."

  printf '%s\n' "$temp_dir"
}

secrets_unpack() {
  [[ -f "$DOTFORGE_SECRETS_BUNDLE" ]] || die_with_fix \
    "Missing encrypted secrets bundle." \
    "dotforge cannot unpack secrets because '$DOTFORGE_SECRETS_BUNDLE' does not exist." \
    "Create the bundle first or restore it from git."

  DOTFORGE_AGE_PASSPHRASE=$(prompt_for_age_passphrase)
  validate_age_bundle_passphrase

  local temp_dir archive_path
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-secrets-unpack.XXXXXX")
  archive_path="$temp_dir/bundle.tar"

  age_run decrypt -d -o "$archive_path" "$DOTFORGE_SECRETS_BUNDLE" >/dev/null || die_with_fix \
    "Failed to decrypt the secrets bundle." \
    "The passphrase is wrong or the age bundle is corrupted." \
    "Retry with the correct passphrase or restore the bundle."

  tar -xf "$archive_path" -C "$temp_dir" || die_with_fix \
    "Failed to unpack the decrypted secrets bundle." \
    "The decrypted data was not a valid tar archive." \
    "Rebuild the bundle and rerun 'dotforge secrets unpack'."

  rm -f "$archive_path"
  printf '%s\n' "$temp_dir" >"$DOTFORGE_UNPACKED_DIR_FILE"
  info "Decrypted secrets are available at: $temp_dir"
}

secrets_pack() {
  local source_dir=$1
  [[ -n "$source_dir" ]] || die_with_fix \
    "No source path was provided to 'dotforge secrets pack'." \
    "dotforge needs a directory containing the scoped secrets tree." \
    "Run 'dotforge secrets pack <path>' with the directory created by 'dotforge secrets unpack'."
  [[ -d "$source_dir/ssh" ]] || die_with_fix \
    "The provided secrets path does not contain an ssh/ directory." \
    "dotforge expects the same scoped tree emitted by 'dotforge secrets unpack'." \
    "Point the command at a directory with an ssh/ subtree and rerun it."

  DOTFORGE_AGE_PASSPHRASE=$(prompt_for_age_passphrase)

  local temp_dir archive_path
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotforge-secrets-pack.XXXXXX")
  archive_path="$temp_dir/bundle.tar"
  register_cleanup "best_effort_wipe '$temp_dir'"

  tar -cf "$archive_path" -C "$source_dir" ssh || die_with_fix \
    "Failed to create a tar archive from '$source_dir'." \
    "dotforge could not bundle the scoped secrets tree before encryption." \
    "Check file permissions and the source directory, then rerun the command."

  age_run encrypt -p -o "$DOTFORGE_SECRETS_BUNDLE" "$archive_path" >/dev/null || die_with_fix \
    "Failed to encrypt the secrets bundle with age." \
    "age could not produce '$DOTFORGE_SECRETS_BUNDLE' from the provided secret tree." \
    "Verify the passphrase flow and rerun 'dotforge secrets pack'."

  if [[ -f "$DOTFORGE_UNPACKED_DIR_FILE" ]]; then
    local unpacked_dir
    unpacked_dir=$(cat "$DOTFORGE_UNPACKED_DIR_FILE")
    if [[ "$unpacked_dir" == "$source_dir" ]]; then
      best_effort_wipe "$source_dir"
      rm -f "$DOTFORGE_UNPACKED_DIR_FILE"
    fi
  fi

  local secrets_dir
  secrets_dir=$(prepare_runtime_secrets_dir)
  deploy_ssh_assets "$secrets_dir"
  info "Secrets bundle updated. Commit and push '$DOTFORGE_SECRETS_BUNDLE' when you are ready."
}
