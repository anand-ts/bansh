#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_PATH="$HOME/Library/Input Methods/BanshInputMethod.app"

/bin/rm -rf "$APP_PATH"
"$ROOT_DIR/scripts/restart-input-method-services.sh"

echo "Removed $APP_PATH"
