#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_PATH="/Library/Input Methods/BanshInputMethod.app"

echo "Removing $APP_PATH"
echo "You may be prompted for your administrator password."

/usr/bin/sudo /bin/rm -rf "$APP_PATH"
"$ROOT_DIR/scripts/restart-input-method-services.sh"

echo "Removed $APP_PATH"
