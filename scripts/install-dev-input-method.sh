#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="BanshInputMethod.app"
APP_DIR="$ROOT_DIR/build/dev/$APP_NAME"
INSTALL_DIR="${BANSH_INSTALL_DIR:-$HOME/Library/Input Methods}"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"

"$ROOT_DIR/scripts/build-dev-app.sh"

mkdir -p "$INSTALL_DIR"
/bin/rm -rf "$INSTALLED_APP"
/bin/cp -R "$APP_DIR" "$INSTALLED_APP"

"$ROOT_DIR/scripts/register-installed-input-method.sh" "$INSTALLED_APP"

echo "Installed $INSTALLED_APP"
echo "If Bansh does not appear in System Settings right away, sign out and sign back in once."
