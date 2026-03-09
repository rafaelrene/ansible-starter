#!/usr/bin/env bash

read_state_lines() {
  local file=$1
  if [[ -f "$file" ]]; then
    awk 'NF { print }' "$file"
  fi
}

write_state_lines() {
  local file=$1
  shift
  ensure_dir "$(dirname -- "$file")"
  {
    local line
    for line in "$@"; do
      [[ -n "$line" ]] && printf '%s\n' "$line"
    done
  } | sorted_unique_lines >"$file"
}

clear_state_file() {
  local file=$1
  rm -f "$file"
}
