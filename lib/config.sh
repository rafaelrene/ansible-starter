#!/usr/bin/env bash

load_config() {
  if [[ -f "$DOTFORGE_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    . "$DOTFORGE_CONFIG_FILE"
  fi
  DOTFORGE_PACKAGES=${DOTFORGE_PACKAGES:-}
}

write_config() {
  local csv=$1
  ensure_dir "$DOTFORGE_CONFIG_DIR"
  cat >"$DOTFORGE_CONFIG_FILE" <<EOF
# shellcheck shell=bash
DOTFORGE_PACKAGES="$csv"
EOF
}

normalize_package_csv() {
  local csv=$1
  local seen=""
  local normalized=()
  local item
  local token
  local old_ifs=$IFS

  IFS=','
  for item in $csv; do
    token=$(trim "$item")
    [[ -z "$token" ]] && continue
    case ",$seen," in
      *,"$token",*) ;;
      *)
        normalized+=("$token")
        seen=$seen,$token
        ;;
    esac
  done
  IFS=$old_ifs

  join_by_comma "${normalized[@]}"
}

ensure_config_ready() {
  load_config

  if [[ -n "${DOTFORGE_PACKAGES:-}" ]]; then
    DOTFORGE_PACKAGES=$(normalize_package_csv "$DOTFORGE_PACKAGES")
    write_config "$DOTFORGE_PACKAGES"
    return 0
  fi

  if [[ "$DOTFORGE_NONINTERACTIVE" == "1" ]]; then
    die_with_fix \
      "The dotforge package list is not configured." \
      "Non-interactive mode requires DOTFORGE_PACKAGES in the environment or config file." \
      "Set DOTFORGE_PACKAGES before running dotforge or create ~/.config/dotforge/config."
  fi

  DOTFORGE_PACKAGES=$(interactive_package_selection)
  DOTFORGE_PACKAGES=$(normalize_package_csv "$DOTFORGE_PACKAGES")
  write_config "$DOTFORGE_PACKAGES"
}

interactive_package_selection() {
  local line
  DOTFORGE_PACKAGE_DEFAULTS=()
  DOTFORGE_PACKAGE_SELECTED=()
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    DOTFORGE_PACKAGE_DEFAULTS+=("$line")
    DOTFORGE_PACKAGE_SELECTED+=("$line")
  done <<EOF
$(catalog_default_ids)
EOF

  info "Configure package defaults. Commands: toggle <number>, all, none, done"

  while true; do
    print_package_selection
    printf 'selection> '
    IFS= read -r line
    line=$(trim "$line")

    case "$line" in
      done)
        break
        ;;
      all)
        DOTFORGE_PACKAGE_SELECTED=("${DOTFORGE_PACKAGE_DEFAULTS[@]}")
        ;;
      none)
        DOTFORGE_PACKAGE_SELECTED=()
        ;;
      toggle\ *)
        toggle_selected_packages "${line#toggle }"
        ;;
      *)
        warn "Unknown selection command '$line'."
        ;;
    esac
  done

  printf 'Extra packages (comma separated, use brew: or yay: prefixes, blank for none): '
  IFS= read -r line
  line=$(trim "$line")

  if [[ -n "$line" ]]; then
    if [[ ${#DOTFORGE_PACKAGE_SELECTED[@]} -gt 0 ]]; then
      printf '%s,%s\n' "$(join_by_comma "${DOTFORGE_PACKAGE_SELECTED[@]}")" "$line"
    else
      printf '%s\n' "$line"
    fi
  else
    join_by_comma "${DOTFORGE_PACKAGE_SELECTED[@]}"
    printf '\n'
  fi
}

print_package_selection() {
  local index=1
  local item

  printf '\n'
  for item in "${DOTFORGE_PACKAGE_DEFAULTS[@]}"; do
    if contains_line "$item" "${DOTFORGE_PACKAGE_SELECTED[@]}"; then
      printf ' [%s] %s. %s\n' "x" "$index" "$item"
    else
      printf ' [%s] %s. %s\n' " " "$index" "$item"
    fi
    index=$((index + 1))
  done
}

toggle_selected_packages() {
  local indexes=$1
  local number
  local token

  for number in $indexes; do
    if ! [[ "$number" =~ ^[0-9]+$ ]]; then
      warn "Invalid selection index '$number'."
      continue
    fi
    token=${DOTFORGE_PACKAGE_DEFAULTS[$((number - 1))]:-}
    [[ -n "$token" ]] || continue

    if contains_line "$token" "${DOTFORGE_PACKAGE_SELECTED[@]}"; then
      DOTFORGE_PACKAGE_SELECTED=($(printf '%s\n' "${DOTFORGE_PACKAGE_SELECTED[@]}" | awk -v drop="$token" '$0 != drop'))
    else
      DOTFORGE_PACKAGE_SELECTED+=("$token")
    fi
  done
}

config_package_tokens() {
  load_config
  normalize_package_csv "${DOTFORGE_PACKAGES:-}"
}

save_package_tokens() {
  local csv
  csv=$(normalize_package_csv "$1")
  write_config "$csv"
  DOTFORGE_PACKAGES=$csv
}
