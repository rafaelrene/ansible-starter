#!/usr/bin/env bash

preflight_needs_config() {
  case "$1" in
    apply|pkg)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

preflight_needs_passphrase() {
  case "$1:$2" in
    apply:|secrets:add|secrets:update|secrets:remove|secrets:list)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

preflight_needs_shell_context() {
  case "$1" in
    apply|pkg)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

preflight_needs_validated_passphrase() {
  case "$1:$2" in
    apply:|secrets:update|secrets:remove|secrets:list)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

dotforge_preflight_collect() {
  local command=$1
  local subcommand=${2:-}

  if preflight_needs_config "$command"; then
    collect_config_inputs_if_needed
  fi

  if [[ "$command" != "secrets" ]]; then
    ensure_sudo_session
    start_sudo_keepalive
    bootstrap_platform_prerequisites
  fi

  if preflight_needs_passphrase "$command" "$subcommand"; then
    ensure_age_passphrase_ready
  fi

  if preflight_needs_shell_context "$command"; then
    detect_shell_context
    if [[ -n "$DOTFORGE_CURRENT_SHELL" || -n "$DOTFORGE_LOGIN_SHELL" ]]; then
      info "Current shell: ${DOTFORGE_CURRENT_SHELL:-unknown}; login shell: ${DOTFORGE_LOGIN_SHELL:-unknown}"
    fi
  fi

  if preflight_needs_validated_passphrase "$command" "$subcommand"; then
    validate_age_store_passphrase
  fi
}
