#!/bin/zsh

set -euo pipefail

for process_name in BanshInputMethod TextInputMenuAgent TextInputSwitcher; do
  /usr/bin/killall "$process_name" >/dev/null 2>&1 || true
done

USER_ID=$(/usr/bin/id -u)
TEXT_INPUT_AGENT_LABEL="gui/$USER_ID/com.apple.TextInputMenuAgent"

if /bin/launchctl print "$TEXT_INPUT_AGENT_LABEL" >/dev/null 2>&1; then
  /bin/launchctl kickstart -k "$TEXT_INPUT_AGENT_LABEL" >/dev/null 2>&1 || true
fi

echo "Restarted text input services (best effort)."
