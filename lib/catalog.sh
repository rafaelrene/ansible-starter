#!/usr/bin/env bash

catalog_file_for_platform() {
  case "$DOTFORGE_PLATFORM" in
    macos) printf '%s' "$DOTFORGE_CATALOG_DIR/macos.tsv" ;;
    arch) printf '%s' "$DOTFORGE_CATALOG_DIR/arch.tsv" ;;
    *)
      die_with_fix \
        "Cannot load package catalog for platform '$DOTFORGE_PLATFORM'." \
        "The platform was not detected correctly before package resolution." \
        "Rerun dotforge after fixing platform detection."
      ;;
  esac
}

catalog_default_ids() {
  local file
  file=$(catalog_file_for_platform)
  awk -F '\t' '$NF == "1" { print $1 }' "$file"
}

catalog_lookup() {
  local id=$1
  local file
  file=$(catalog_file_for_platform)
  awk -F '\t' -v package_id="$id" '$1 == package_id { print; exit }' "$file"
}

resolve_package_token() {
  local token=$1
  local row

  if [[ -z "$token" ]]; then
    die_with_fix \
      "An empty package token was provided." \
      "dotforge cannot resolve blank entries from the package list." \
      "Remove empty entries from ~/.config/dotforge/config and rerun dotforge."
  fi

  if [[ "$token" == brew:* ]]; then
    [[ "$DOTFORGE_PLATFORM" == "macos" ]] || die_with_fix \
      "Unsupported raw package token '$token' on this platform." \
      "brew-prefixed extras can only be used on macOS." \
      "Remove '$token' from the config or run dotforge on macOS."
    printf '%s\n' "raw|brew|raw||${token#brew:}|$token"
    return 0
  fi

  if [[ "$token" == yay:* ]]; then
    [[ "$DOTFORGE_PLATFORM" == "arch" ]] || die_with_fix \
      "Unsupported raw package token '$token' on this platform." \
      "yay-prefixed extras can only be used on Arch Linux." \
      "Remove '$token' from the config or run dotforge on Arch Linux."
    printf '%s\n' "raw|yay|raw||${token#yay:}|$token"
    return 0
  fi

  row=$(catalog_lookup "$token")
  if [[ -z "$row" ]]; then
    die_with_fix \
      "Unknown package id '$token'." \
      "The package is not part of the dotforge catalog and is not a raw brew:/yay: token." \
      "Use a known package id or prefix custom packages with brew: or yay:."
  fi

  case "$DOTFORGE_PLATFORM" in
    macos)
      awk -F '\t' -v raw="$row" 'BEGIN {
        split(raw, parts, "\t");
        printf "catalog|brew|%s|%s|%s|%s\n", parts[2], parts[3], parts[4], parts[1];
      }'
      ;;
    arch)
      awk -F '\t' -v raw="$row" 'BEGIN {
        split(raw, parts, "\t");
        printf "catalog|yay|%s||%s|%s\n", parts[2], parts[3], parts[1];
      }'
      ;;
  esac
}

resolve_csv_to_specs() {
  local csv=$1
  local token
  local item
  local old_ifs=$IFS
  IFS=','
  for item in $csv; do
    token=$(trim "$item")
    [[ -z "$token" ]] && continue
    resolve_package_token "$token"
  done
  IFS=$old_ifs
}
