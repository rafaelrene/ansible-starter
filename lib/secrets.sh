#!/usr/bin/env bash

validate_secret_name() {
  local name=$1
  [[ "$name" =~ ^[A-Z][A-Z0-9_]*$ ]] || die_with_fix \
    "Invalid secret name '$name'." \
    "Secret names must be uppercase snake case." \
    "Use names like 'OPENCODE_GSMCP_TOKEN' or 'SSH_PERSONAL'."
}

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

  tty_print 'Enter age passphrase: '
  tty_read_secret
}

ensure_age_passphrase_ready() {
  if [[ -n "$DOTFORGE_AGE_PASSPHRASE" ]]; then
    return 0
  fi

  DOTFORGE_AGE_PASSPHRASE=$(prompt_for_age_passphrase)
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

new_secret_temp_path() {
  local __target_var=$1
  local path
  path=$(mktemp "${TMPDIR:-/tmp}/dotforge-secret.XXXXXX")
  register_cleanup "best_effort_wipe '$path'"
  printf -v "$__target_var" '%s' "$path"
}

base64_encode_file() {
  local path=$1
  base64 <"$path" | tr -d '\n'
}

base64_decode_to_file() {
  local encoded=$1
  local target=$2

  if printf '%s' "$encoded" | base64 --decode >"$target" 2>/dev/null; then
    return 0
  fi

  if printf '%s' "$encoded" | base64 -d >"$target" 2>/dev/null; then
    return 0
  fi

  if printf '%s' "$encoded" | base64 -D >"$target" 2>/dev/null; then
    return 0
  fi

  die_with_fix \
    "Failed to decode a secret value from the secrets store." \
    "The stored value is not valid base64 for this platform's base64 command." \
    "Repair the encrypted secrets store and rerun dotforge."
}

secrets_store_exists() {
  [[ -f "$DOTFORGE_SECRETS_STORE" ]]
}

validate_age_store_passphrase() {
  ensure_age_passphrase_ready

  if [[ "$DOTFORGE_AGE_PASSPHRASE_VALIDATED" == "1" ]]; then
    return 0
  fi

  [[ -f "$DOTFORGE_SECRETS_STORE" ]] || die_with_fix \
    "Missing encrypted secrets store." \
    "dotforge expected '$DOTFORGE_SECRETS_STORE' to exist before decrypting secrets." \
    "Create it with 'dotforge secrets add <NAME> [VALUE|-]'."

  local temp_file
  new_secret_temp_path temp_file
  age_run decrypt -d -o "$temp_file" "$DOTFORGE_SECRETS_STORE" >/dev/null 2>&1 || die_with_fix \
    "Failed to decrypt '$DOTFORGE_SECRETS_STORE'." \
    "The age passphrase is wrong or the encrypted store is corrupted." \
    "Retry with the correct passphrase. If the store is corrupted, recreate it with 'dotforge secrets add'."
  DOTFORGE_AGE_PASSPHRASE_VALIDATED=1
}

validate_plaintext_secrets_store() {
  local store_path=$1
  local header
  local line_number=0
  local names_file
  local line
  local name
  local encoded

  [[ -f "$store_path" ]] || die_with_fix \
    "The decrypted secrets store is missing." \
    "dotforge expected a plaintext store file during secrets processing." \
    "Retry the command. If the issue persists, recreate the store with 'dotforge secrets add'."

  new_secret_temp_path names_file
  header=$(sed -n '1p' "$store_path")
  [[ "$header" == "v1" ]] || die_with_fix \
    "The secrets store header is invalid." \
    "dotforge only understands plaintext stores that begin with 'v1'." \
    "Recreate the store with 'dotforge secrets add'."

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    if [[ $line_number -eq 1 ]]; then
      continue
    fi

    [[ -n "$line" ]] || die_with_fix \
      "The decrypted secrets store contains a blank record." \
      "dotforge expects each secret record to be a non-empty NAME<TAB>BASE64_VALUE line." \
      "Repair the store and rerun dotforge."
    [[ "$line" == *$'\t'* ]] || die_with_fix \
      "The decrypted secrets store contains an invalid record." \
      "dotforge expects each secret record to be a NAME<TAB>BASE64_VALUE line." \
      "Repair the store and rerun dotforge."

    name=${line%%$'\t'*}
    encoded=${line#*$'\t'}
    [[ -n "$name" && -n "$encoded" ]] || die_with_fix \
      "The decrypted secrets store contains an incomplete record." \
      "Each secret record must include both a name and a base64-encoded value." \
      "Repair the store and rerun dotforge."
    validate_secret_name "$name"
    printf '%s\n' "$name" >>"$names_file"
  done <"$store_path"

  local duplicates
  duplicates=$(sort "$names_file" | uniq -d)
  [[ -z "$duplicates" ]] || die_with_fix \
    "The decrypted secrets store contains duplicate secret names." \
    "dotforge requires each secret name to be unique." \
    "Remove the duplicate records and rerun dotforge."
}

ensure_runtime_secrets_store_ready() {
  if [[ -n "$DOTFORGE_RUNTIME_SECRETS_STORE" ]] && [[ -f "$DOTFORGE_RUNTIME_SECRETS_STORE" ]]; then
    return 0
  fi

  [[ -f "$DOTFORGE_SECRETS_STORE" ]] || die_with_fix \
    "Missing encrypted secrets store." \
    "dotforge expected '$DOTFORGE_SECRETS_STORE' to exist before applying secrets." \
    "Create it with 'dotforge secrets add <NAME> [VALUE|-]'."

  ensure_age_passphrase_ready
  validate_age_store_passphrase

  new_secret_temp_path DOTFORGE_RUNTIME_SECRETS_STORE
  age_run decrypt -d -o "$DOTFORGE_RUNTIME_SECRETS_STORE" "$DOTFORGE_SECRETS_STORE" >/dev/null || die_with_fix \
    "Failed to decrypt the secrets store." \
    "The age passphrase was accepted but the encrypted store could not be decrypted." \
    "Verify the secrets store and rerun dotforge."

  validate_plaintext_secrets_store "$DOTFORGE_RUNTIME_SECRETS_STORE"
}

prepare_runtime_secrets_store() {
  ensure_runtime_secrets_store_ready
}

ensure_runtime_secrets_store_for_write() {
  if [[ -n "$DOTFORGE_RUNTIME_SECRETS_STORE" ]] && [[ -f "$DOTFORGE_RUNTIME_SECRETS_STORE" ]]; then
    return 0
  fi

  if [[ -f "$DOTFORGE_SECRETS_STORE" ]]; then
    ensure_runtime_secrets_store_ready
    return 0
  fi

  new_secret_temp_path DOTFORGE_RUNTIME_SECRETS_STORE
  printf 'v1\n' >"$DOTFORGE_RUNTIME_SECRETS_STORE"
}

write_encrypted_secrets_store() {
  ensure_runtime_secrets_store_for_write
  ensure_age_passphrase_ready
  validate_plaintext_secrets_store "$DOTFORGE_RUNTIME_SECRETS_STORE"
  ensure_dir "$(dirname -- "$DOTFORGE_SECRETS_STORE")"

  age_run encrypt -p -o "$DOTFORGE_SECRETS_STORE" "$DOTFORGE_RUNTIME_SECRETS_STORE" >/dev/null || die_with_fix \
    "Failed to encrypt the secrets store with age." \
    "age could not produce '$DOTFORGE_SECRETS_STORE' from the plaintext store." \
    "Verify the passphrase flow and rerun the command."
  DOTFORGE_AGE_PASSPHRASE_VALIDATED=1
}

secrets_store_has_name() {
  local name=$1
  ensure_runtime_secrets_store_ready
  awk -F '\t' -v secret_name="$name" 'NR > 1 && $1 == secret_name { found = 1; exit } END { exit found ? 0 : 1 }' "$DOTFORGE_RUNTIME_SECRETS_STORE"
}

secrets_store_get_encoded() {
  local name=$1
  ensure_runtime_secrets_store_ready
  awk -F '\t' -v secret_name="$name" 'NR > 1 && $1 == secret_name { print $2; exit }' "$DOTFORGE_RUNTIME_SECRETS_STORE"
}

secrets_store_write_decoded_to_file() {
  local name=$1
  local target=$2
  local encoded

  encoded=$(secrets_store_get_encoded "$name")
  [[ -n "$encoded" ]] || die_with_fix \
    "Missing secret '$name'." \
    "dotforge expected to find '$name' in the encrypted secrets store." \
    "Add it with 'dotforge secrets add $name [VALUE|-]' and rerun dotforge."
  base64_decode_to_file "$encoded" "$target"
}

secrets_store_get_decoded() {
  local name=$1
  local temp_file
  new_secret_temp_path temp_file
  secrets_store_write_decoded_to_file "$name" "$temp_file"
  cat "$temp_file"
}

sorted_secret_records_file() {
  local source_file=$1
  local target_file=$2

  {
    printf 'v1\n'
    awk 'NR > 1 { print }' "$source_file" | sort
  } >"$target_file"
}

secrets_store_put_from_file() {
  local name=$1
  local source_file=$2
  local temp_file
  local sorted_file
  local encoded

  ensure_runtime_secrets_store_for_write
  validate_secret_name "$name"
  encoded=$(base64_encode_file "$source_file")
  new_secret_temp_path temp_file
  new_secret_temp_path sorted_file

  {
    printf 'v1\n'
    awk -F '\t' -v secret_name="$name" 'NR > 1 && $1 != secret_name { print }' "$DOTFORGE_RUNTIME_SECRETS_STORE"
    printf '%s\t%s\n' "$name" "$encoded"
  } >"$temp_file"

  sorted_secret_records_file "$temp_file" "$sorted_file"
  cat "$sorted_file" >"$DOTFORGE_RUNTIME_SECRETS_STORE"
}

secrets_store_remove() {
  local name=$1
  local temp_file

  ensure_runtime_secrets_store_ready
  new_secret_temp_path temp_file
  {
    printf 'v1\n'
    awk -F '\t' -v secret_name="$name" 'NR > 1 && $1 != secret_name { print }' "$DOTFORGE_RUNTIME_SECRETS_STORE" | sort
  } >"$temp_file"
  cat "$temp_file" >"$DOTFORGE_RUNTIME_SECRETS_STORE"
}

secrets_store_list() {
  ensure_runtime_secrets_store_ready
  awk -F '\t' 'NR > 1 { print $1 }' "$DOTFORGE_RUNTIME_SECRETS_STORE" | sort
}

read_secret_value_to_file() {
  local provided=${1-__DOTFORGE_UNSET__}
  local target=$2

  if [[ "$provided" == "__DOTFORGE_UNSET__" ]]; then
    if [[ "$DOTFORGE_NONINTERACTIVE" == "1" ]]; then
      die_with_fix \
        "A secret value is required." \
        "Non-interactive mode cannot prompt for a missing secret value." \
        "Pass the value as an argument or '-' on stdin and rerun the command."
    fi
    tty_print 'Enter secret value: '
    tty_read_secret >"$target"
    return 0
  fi

  if [[ "$provided" == "-" ]]; then
    cat >"$target"
    return 0
  fi

  printf '%s' "$provided" >"$target"
}

materialize_secret_to_path() {
  local name=$1
  local target=$2
  local temp_file

  new_secret_temp_path temp_file
  secrets_store_write_decoded_to_file "$name" "$temp_file"
  ensure_dir "$(dirname -- "$target")"
  cp "$temp_file" "$target" || die_with_fix \
    "Failed to write '$target'." \
    "dotforge could not materialize a local secret file." \
    "Check filesystem permissions and rerun dotforge."
  chmod 600 "$target"
}

require_secret_present() {
  local name=$1
  secrets_store_has_name "$name" || die_with_fix \
    "Missing required secret '$name'." \
    "dotforge needs '$name' to materialize local secret files for this machine." \
    "Add it with 'dotforge secrets add $name [VALUE|-]' and rerun dotforge."
}

materialize_local_secret_files() {
  local names_file
  local name
  local path
  local base

  ensure_runtime_secrets_store_ready
  require_secret_present OPENCODE_GSMCP_TOKEN
  require_secret_present SSH_BITBUCKET_WORK
  require_secret_present SSH_HETZNER
  require_secret_present SSH_PERSONAL

  ensure_dir "$DOTFORGE_LOCAL_SECRETS_DIR"
  chmod 700 "$DOTFORGE_LOCAL_SECRETS_DIR"
  new_secret_temp_path names_file
  secrets_store_list >"$names_file"

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    materialize_secret_to_path "$name" "$DOTFORGE_LOCAL_SECRETS_DIR/$name"
  done <"$names_file"

  for path in "$DOTFORGE_LOCAL_SECRETS_DIR"/*; do
    [[ -e "$path" ]] || continue
    base=$(basename -- "$path")
    grep -Fx "$base" "$names_file" >/dev/null 2>&1 || safe_remove_path "$path"
  done
}

secrets_add() {
  local name=$1
  local provided_value=${2-__DOTFORGE_UNSET__}
  local value_file

  [[ -n "$name" ]] || die_with_fix \
    "No secret name was provided to 'dotforge secrets add'." \
    "dotforge needs a secret name to add a new secret." \
    "Run 'dotforge secrets add <NAME> [VALUE|-]'."

  validate_secret_name "$name"
  ensure_runtime_secrets_store_for_write
  if [[ -f "$DOTFORGE_SECRETS_STORE" ]] && secrets_store_has_name "$name"; then
    die_with_fix \
      "Secret '$name' already exists." \
      "dotforge will not overwrite an existing secret during 'add'." \
      "Use 'dotforge secrets update $name [NEW_VALUE|-]' instead."
  fi

  new_secret_temp_path value_file
  read_secret_value_to_file "$provided_value" "$value_file"
  secrets_store_put_from_file "$name" "$value_file"
  write_encrypted_secrets_store
  info "Secret '$name' added. Run 'dotforge apply' to redeploy local secret files."
}

secrets_update() {
  local name=$1
  local provided_value=${2-__DOTFORGE_UNSET__}
  local value_file

  [[ -n "$name" ]] || die_with_fix \
    "No secret name was provided to 'dotforge secrets update'." \
    "dotforge needs a secret name to update an existing secret." \
    "Run 'dotforge secrets update <NAME> [NEW_VALUE|-]'."

  validate_secret_name "$name"
  ensure_runtime_secrets_store_ready
  secrets_store_has_name "$name" || die_with_fix \
    "Secret '$name' does not exist." \
    "dotforge cannot update a missing secret." \
    "Use 'dotforge secrets add $name [VALUE|-]' to create it first."

  new_secret_temp_path value_file
  read_secret_value_to_file "$provided_value" "$value_file"
  secrets_store_put_from_file "$name" "$value_file"
  write_encrypted_secrets_store
  info "Secret '$name' updated. Run 'dotforge apply' to redeploy local secret files."
}

secrets_remove() {
  local name=$1

  [[ -n "$name" ]] || die_with_fix \
    "No secret name was provided to 'dotforge secrets remove'." \
    "dotforge needs a secret name to remove." \
    "Run 'dotforge secrets remove <NAME>'."

  validate_secret_name "$name"
  ensure_runtime_secrets_store_ready
  if ! secrets_store_has_name "$name"; then
    info "Secret '$name' does not exist. Nothing to remove."
    return 0
  fi

  secrets_store_remove "$name"
  write_encrypted_secrets_store
  info "Secret '$name' removed. Run 'dotforge apply' to redeploy local secret files."
}

secrets_list() {
  ensure_runtime_secrets_store_ready
  secrets_store_list
}
