#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ARCHIVE_SCRIPT="$ROOT_DIR/scripts/archive-release.sh"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/release/BanshInputMethod.xcarchive}"
ARCHIVE_APP="$ARCHIVE_PATH/Products/Applications/BanshInputMethod.app"
DIST_ROOT="${DIST_ROOT:-$ROOT_DIR/build/direct-download}"
DIST_DIR="$DIST_ROOT/Bansh"
SUPPORT_DIR="$DIST_DIR/.support"
HELPER_SOURCE="$ROOT_DIR/Packaging/direct-download/register-input-source.m"
HELPER_BINARY="$SUPPORT_DIR/register-input-source"
APP_NAME="BanshInputMethod.app"
APP_PATH="$DIST_DIR/$APP_NAME"
README_PATH="$DIST_DIR/README.txt"
INSTALL_SCRIPT_PATH="$DIST_DIR/Install Bansh.command"
UNINSTALL_SCRIPT_PATH="$DIST_DIR/Uninstall Bansh.command"

developer_identity_sha()
{
  /usr/bin/security find-identity -v -p codesigning 2>/dev/null |
    /usr/bin/awk '/Apple Development:/ { print $2; exit }'
}

sign_binary_best_effort()
{
  local binary_path="$1"
  local identity

  identity="$(developer_identity_sha)"
  if [[ -n "$identity" ]]; then
    /usr/bin/codesign --force --sign "$identity" --timestamp=none "$binary_path"
  else
    /usr/bin/codesign --force --sign - --timestamp=none "$binary_path"
  fi
}

if [[ ! -x "$ARCHIVE_SCRIPT" ]]; then
  echo "archive script not found at $ARCHIVE_SCRIPT" >&2
  exit 1
fi

if [[ ! -f "$HELPER_SOURCE" ]]; then
  echo "helper source not found at $HELPER_SOURCE" >&2
  exit 1
fi

"$ARCHIVE_SCRIPT"

if [[ ! -d "$ARCHIVE_APP" ]]; then
  echo "expected archived app at $ARCHIVE_APP" >&2
  exit 1
fi

/bin/rm -rf "$DIST_DIR"
/bin/mkdir -p "$SUPPORT_DIR"
/usr/bin/ditto "$ARCHIVE_APP" "$APP_PATH"

/usr/bin/clang -fmodules -fmodules-cache-path="$ROOT_DIR/build/clang-mod-cache" \
  -framework Foundation \
  -framework Carbon \
  "$HELPER_SOURCE" \
  -o "$HELPER_BINARY"

sign_binary_best_effort "$HELPER_BINARY"

cat >"$INSTALL_SCRIPT_PATH" <<'EOF'
#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
APP_NAME="BanshInputMethod.app"
APP_PATH="$SCRIPT_DIR/$APP_NAME"
SUPPORT_DIR="$SCRIPT_DIR/.support"
REGISTER_BINARY="$SUPPORT_DIR/register-input-source"
INSTALL_DIR="/Library/Input Methods"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"
DRY_RUN=0

plist_string()
{
  local key="$1"
  /usr/bin/plutil -extract "$key" raw -o - "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
}

plist_array_value()
{
  local key_path="$1"
  /usr/libexec/PlistBuddy -c "Print :$key_path" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
}

print_command()
{
  printf '[dry-run]'
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

run_or_print()
{
  if (( DRY_RUN )); then
    print_command "$@"
  else
    "$@"
  fi
}

restart_input_services()
{
  for process_name in BanshInputMethod TextInputMenuAgent TextInputSwitcher; do
    if (( DRY_RUN )); then
      print_command /usr/bin/killall "$process_name"
    else
      /usr/bin/killall "$process_name" >/dev/null 2>&1 || true
    fi
  done

  local user_id
  user_id=$(/usr/bin/id -u)
  local agent_label="gui/$user_id/com.apple.TextInputMenuAgent"
  if (( DRY_RUN )); then
    print_command /bin/launchctl print "$agent_label"
    print_command /bin/launchctl kickstart -k "$agent_label"
    return
  fi

  if /bin/launchctl print "$agent_label" >/dev/null 2>&1; then
    /bin/launchctl kickstart -k "$agent_label" >/dev/null 2>&1 || true
  fi
}

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing $APP_NAME next to this installer." >&2
  exit 1
fi

if [[ ! -x "$REGISTER_BINARY" ]]; then
  echo "Missing registration helper at $REGISTER_BINARY." >&2
  exit 1
fi

BUNDLE_ID="$(plist_string CFBundleIdentifier)"
SOURCE_ID="$(plist_string TISInputSourceID)"
MODE_ID="$(plist_array_value "ComponentInputModeDict:tsVisibleInputModeOrderedArrayKey:0")"

if [[ -z "$BUNDLE_ID" ]]; then
  echo "Missing CFBundleIdentifier in $APP_PATH." >&2
  exit 1
fi

if [[ -z "$SOURCE_ID" ]]; then
  SOURCE_ID="$BUNDLE_ID"
fi

if [[ -z "$MODE_ID" ]]; then
  MODE_ID="$SOURCE_ID"
fi

echo "Preparing Bansh for install."
run_or_print /usr/bin/xattr -cr "$SCRIPT_DIR"
run_or_print /usr/bin/xattr -cr "$APP_PATH"

echo "Installing Bansh into $INSTALL_DIR."
echo "macOS will ask for your administrator password."

run_or_print /usr/bin/sudo /bin/mkdir -p "$INSTALL_DIR"
run_or_print /usr/bin/sudo /bin/rm -rf "$INSTALLED_APP"
run_or_print /usr/bin/sudo /usr/bin/ditto "$APP_PATH" "$INSTALLED_APP"
run_or_print /usr/bin/sudo /usr/sbin/chown -R root:wheel "$INSTALLED_APP"
run_or_print /usr/bin/sudo /usr/bin/xattr -cr "$INSTALLED_APP"

if (( DRY_RUN )); then
  print_command "$REGISTER_BINARY" "$INSTALLED_APP" "$BUNDLE_ID" "$SOURCE_ID" "$MODE_ID"
else
  "$REGISTER_BINARY" "$INSTALLED_APP" "$BUNDLE_ID" "$SOURCE_ID" "$MODE_ID"
fi

restart_input_services

cat <<'MSG'

Bansh is installed.
If Bansh does not appear in Keyboard > Input Sources right away, sign out and sign back in once.
If macOS blocks this installer when you first open it, run:

  xattr -cr "/path/to/Bansh"

and open "Install Bansh.command" again.
MSG
EOF

cat >"$UNINSTALL_SCRIPT_PATH" <<'EOF'
#!/bin/zsh

set -euo pipefail

APP_PATH="/Library/Input Methods/BanshInputMethod.app"

echo "Removing Bansh from /Library/Input Methods."
echo "macOS may ask for your administrator password."

/usr/bin/sudo /bin/rm -rf "$APP_PATH"

for process_name in BanshInputMethod TextInputMenuAgent TextInputSwitcher; do
  /usr/bin/killall "$process_name" >/dev/null 2>&1 || true
done

USER_ID=$(/usr/bin/id -u)
TEXT_INPUT_AGENT_LABEL="gui/$USER_ID/com.apple.TextInputMenuAgent"
if /bin/launchctl print "$TEXT_INPUT_AGENT_LABEL" >/dev/null 2>&1; then
  /bin/launchctl kickstart -k "$TEXT_INPUT_AGENT_LABEL" >/dev/null 2>&1 || true
fi

echo "Bansh was removed."
EOF

cat >"$README_PATH" <<'EOF'
Bansh Direct Download Install
=============================

1. Extract this folder.
2. Double-click "Install Bansh.command".
3. Enter your administrator password when macOS asks.
4. Open System Settings > Keyboard > Input Sources and enable Bansh if needed.

If macOS refuses to open the installer because it was downloaded from the internet,
open Terminal and run this once on the extracted folder:

  xattr -cr "/path/to/Bansh"

Then open "Install Bansh.command" again.

Notes
-----
- This direct-download build is not App Store or notarized distribution.
- The installer clears quarantine attributes from the copied app as part of the install.
- If Bansh still does not appear right away, sign out and sign back in once.
- "Uninstall Bansh.command" removes the input method from /Library/Input Methods.
EOF

/bin/chmod +x "$INSTALL_SCRIPT_PATH" "$UNINSTALL_SCRIPT_PATH"
/usr/bin/xattr -cr "$DIST_DIR" >/dev/null 2>&1 || true

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.0.0")
ZIP_PATH="${ZIP_PATH:-$DIST_ROOT/Bansh-${VERSION}-direct-download.zip}"
/bin/rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --keepParent --norsrc "$DIST_DIR" "$ZIP_PATH"

echo "Created direct-download folder: $DIST_DIR"
echo "Created direct-download zip: $ZIP_PATH"
