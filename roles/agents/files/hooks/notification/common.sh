#!/bin/sh

osascript -e 'display notification "Agent needs attention" with title "Agent" sound name "default"' >/dev/null 2>&1 || true
