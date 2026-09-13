#!/bin/sh

/usr/bin/ssh -n -T \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o ConnectionAttempts=1 \
  -o ServerAliveInterval=15 \
  -o ServerAliveCountMax=3 \
  othinus \
  '/run/current-system/sw/bin/journalctl --user --follow --lines=0 --output=cat --quiet --identifier=othinus-agent-notify' |
  while IFS= read -r event; do
    [ "$event" = attention ] || continue
    "$HOME/.local/bin/agent-notify" </dev/null >/dev/null 2>&1 || true
  done
