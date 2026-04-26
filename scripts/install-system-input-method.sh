#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="BanshInputMethod.app"
APP_DIR="$ROOT_DIR/build/dev/$APP_NAME"
INSTALL_DIR="/Library/Input Methods"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"

"$ROOT_DIR/scripts/build-dev-app.sh"

echo "Installing Bansh into $INSTALL_DIR (system-wide)."
echo "You may be prompted for your administrator password."

/usr/bin/sudo /bin/mkdir -p "$INSTALL_DIR"
/usr/bin/sudo /bin/rm -rf "$INSTALLED_APP"
/usr/bin/sudo /bin/cp -R "$APP_DIR" "$INSTALLED_APP"
/usr/bin/sudo /usr/sbin/chown -R root:wheel "$INSTALLED_APP"

"$ROOT_DIR/scripts/register-installed-input-method.sh" "$INSTALLED_APP"

echo "Installed $INSTALLED_APP"
echo "If Bansh still does not appear right away, sign out and sign back in once."
