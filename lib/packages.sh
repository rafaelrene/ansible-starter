#!/usr/bin/env bash

desired_state_lines_from_csv() {
  local csv=$1
  local spec source manager kind tap package token
  while IFS= read -r spec; do
    [[ -n "$spec" ]] || continue
    IFS='|' read -r source manager kind tap package token <<EOF
$spec
EOF
    printf '%s|%s|%s|%s\n' "$manager" "$kind" "$tap" "$package"
  done <<EOF
$(resolve_csv_to_specs "$csv")
EOF
}

reconcile_packages() {
  local csv
  csv=$(config_package_tokens)

  uninstall_removed_packages "$csv"
  install_desired_packages "$csv"

  local desired_lines=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    desired_lines+=("$line")
  done <<EOF
$(desired_state_lines_from_csv "$csv")
EOF
  write_state_lines "$DOTFORGE_MANAGED_PACKAGES_FILE" "${desired_lines[@]}"
}

install_desired_packages() {
  local csv=$1
  local brew_formula=()
  local brew_cask=()
  local brew_raw=()
  local brew_taps=()
  local yay_packages=()
  local spec source manager kind tap package token

  while IFS= read -r spec; do
    [[ -n "$spec" ]] || continue
    IFS='|' read -r source manager kind tap package token <<EOF
$spec
EOF
    case "$manager:$kind" in
      brew:formula)
        [[ -n "$tap" ]] && brew_taps+=("$tap")
        brew_formula+=("$package")
        ;;
      brew:cask)
        [[ -n "$tap" ]] && brew_taps+=("$tap")
        brew_cask+=("$package")
        ;;
      brew:raw)
        brew_raw+=("$package")
        ;;
      yay:*)
        yay_packages+=("$package")
        ;;
    esac
  done <<EOF
$(resolve_csv_to_specs "$csv")
EOF

  if [[ ${#brew_taps[@]} -gt 0 ]]; then
    local unique_taps=()
    local tap
    for tap in "${brew_taps[@]}"; do
      if ! contains_line "$tap" "${unique_taps[@]}"; then
        unique_taps+=("$tap")
      fi
    done
    for tap in "${unique_taps[@]}"; do
      brew tap "$tap" || die_with_fix \
        "Failed to tap Homebrew repository '$tap'." \
        "dotforge could not add a required tap for one of the selected packages." \
        "Fix the Homebrew tap error and rerun dotforge."
    done
  fi

  [[ ${#brew_formula[@]} -eq 0 ]] || brew install --formula "${brew_formula[@]}" || die_with_fix \
    "Failed to install one or more Homebrew formula packages." \
    "Homebrew reported an installation error while installing the selected formulae." \
    "Review the Homebrew output above, resolve the issue, and rerun dotforge."

  [[ ${#brew_cask[@]} -eq 0 ]] || brew install --cask "${brew_cask[@]}" || die_with_fix \
    "Failed to install one or more Homebrew casks." \
    "Homebrew reported an installation error while installing the selected casks." \
    "Review the Homebrew output above, resolve the issue, and rerun dotforge."

  [[ ${#brew_raw[@]} -eq 0 ]] || brew install "${brew_raw[@]}" || die_with_fix \
    "Failed to install one or more raw Homebrew packages." \
    "Homebrew could not install one of the custom brew: packages." \
    "Verify the package names and rerun dotforge."

  [[ ${#yay_packages[@]} -eq 0 ]] || yay -S --needed --noconfirm "${yay_packages[@]}" || die_with_fix \
    "Failed to install one or more Arch packages with yay." \
    "yay reported an error while installing the selected packages." \
    "Fix the yay error shown above and rerun dotforge."
}

uninstall_removed_packages() {
  local csv=$1
  local desired_lines=()
  local current_lines=()
  local line
  local removed=()

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    desired_lines+=("$line")
  done <<EOF
$(desired_state_lines_from_csv "$csv")
EOF

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    current_lines+=("$line")
  done <<EOF
$(read_state_lines "$DOTFORGE_MANAGED_PACKAGES_FILE")
EOF

  for line in "${current_lines[@]}"; do
    contains_line "$line" "${desired_lines[@]}" || removed+=("$line")
  done

  uninstall_state_lines "${removed[@]}"
}

uninstall_state_lines() {
  local line manager kind tap package
  local brew_formula=()
  local brew_cask=()
  local brew_raw=()
  local yay_packages=()

  for line in "$@"; do
    [[ -n "$line" ]] || continue
    IFS='|' read -r manager kind tap package <<EOF
$line
EOF
    case "$manager:$kind" in
      brew:formula) brew_formula+=("$package") ;;
      brew:cask) brew_cask+=("$package") ;;
      brew:raw) brew_raw+=("$package") ;;
      yay:*) yay_packages+=("$package") ;;
    esac
  done

  [[ ${#brew_formula[@]} -eq 0 ]] || brew uninstall --formula "${brew_formula[@]}" || die_with_fix \
    "Failed to uninstall one or more Homebrew formula packages." \
    "Homebrew could not remove a formula that dotforge no longer manages." \
    "Resolve the Homebrew uninstall error and rerun dotforge."

  [[ ${#brew_cask[@]} -eq 0 ]] || brew uninstall --cask "${brew_cask[@]}" || die_with_fix \
    "Failed to uninstall one or more Homebrew casks." \
    "Homebrew could not remove a cask that dotforge no longer manages." \
    "Resolve the Homebrew uninstall error and rerun dotforge."

  [[ ${#brew_raw[@]} -eq 0 ]] || brew uninstall "${brew_raw[@]}" || die_with_fix \
    "Failed to uninstall one or more raw Homebrew packages." \
    "Homebrew could not remove a custom brew: package that dotforge no longer manages." \
    "Verify the package name and rerun dotforge."

  [[ ${#yay_packages[@]} -eq 0 ]] || yay -Rns --noconfirm "${yay_packages[@]}" || die_with_fix \
    "Failed to uninstall one or more Arch packages." \
    "yay could not remove a package that dotforge no longer manages." \
    "Resolve the yay uninstall error and rerun dotforge."
}

pkg_add() {
  local token=$1
  [[ -n "$token" ]] || die_with_fix \
    "No package was provided to 'dotforge pkg add'." \
    "dotforge needs a package id or raw package token to add." \
    "Run 'dotforge pkg add <package-id|brew:name|yay:name>'."

  local csv
  csv=$(config_package_tokens)
  csv=$(normalize_package_csv "$csv,$token")
  save_package_tokens "$csv"
  reconcile_packages
}

pkg_rm() {
  local token=$1
  [[ -n "$token" ]] || die_with_fix \
    "No package was provided to 'dotforge pkg rm'." \
    "dotforge needs a package id or raw package token to remove." \
    "Run 'dotforge pkg rm <package-id|brew:name|yay:name>'."

  local csv
  local result=()
  local item
  local old_ifs=$IFS
  local found=0

  csv=$(config_package_tokens)
  IFS=','
  for item in $csv; do
    item=$(trim "$item")
    [[ -n "$item" ]] || continue
    if [[ "$item" == "$token" ]]; then
      found=1
      continue
    fi
    result+=("$item")
  done
  IFS=$old_ifs

  if [[ $found -eq 0 ]]; then
    die_with_fix \
      "Package '$token' is not currently selected in dotforge config." \
      "dotforge pkg rm only removes packages that are already present in ~/.config/dotforge/config." \
      "Check the configured package list and rerun the command with a selected package."
  fi

  save_package_tokens "$(join_by_comma "${result[@]}")"
  reconcile_packages
}
