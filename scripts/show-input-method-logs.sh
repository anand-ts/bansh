#!/bin/zsh

set -euo pipefail

WINDOW="${1:-10m}"

/usr/bin/log show \
  --last "$WINDOW" \
  --style compact \
  --predicate 'subsystem CONTAINS[c] "HIToolbox" OR process == "TextInputMenuAgent" OR eventMessage CONTAINS[c] "Bansh" OR eventMessage CONTAINS[c] "input method"'
