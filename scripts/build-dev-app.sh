#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PROJECT_PATH="$ROOT_DIR/Bansh.xcodeproj"
SCHEME="BanshInputMethod"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData}"
BUILD_DIR="$ROOT_DIR/build/dev"
APP_NAME="BanshInputMethod.app"
APP_DIR="$BUILD_DIR/$APP_NAME"
SOURCE_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"

apple_development_team_id()
{
  /usr/bin/security find-identity -v -p codesigning 2>/dev/null |
    /usr/bin/sed -n 's/.*Apple Development: .*(\([A-Z0-9][A-Z0-9]*\)).*/\1/p' |
    /usr/bin/head -n 1
}

TEAM_ID="${BANSH_DEVELOPMENT_TEAM:-}"
if [[ -z "$TEAM_ID" ]]; then
  TEAM_ID="${DEVELOPMENT_TEAM:-}"
fi
if [[ -z "$TEAM_ID" ]]; then
  TEAM_ID="$(apple_development_team_id)"
fi

if [[ -z "$TEAM_ID" ]]; then
  cat >&2 <<'EOF'
No Apple Development signing team could be found.

Before Bansh can register as a macOS input method, set up local development signing:
1. Open Xcode > Settings > Accounts and add your Apple ID if needed.
2. In that account, use "Manage Certificates..." and create an "Apple Development" certificate.
3. Rerun this script, or pass BANSH_DEVELOPMENT_TEAM=<your team id>.

Do not commit personal Apple team IDs to the project.
EOF
  exit 1
fi

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  build

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Expected build product at $SOURCE_APP" >&2
  exit 1
fi

/bin/rm -rf "$APP_DIR"
/bin/mkdir -p "$BUILD_DIR"
/bin/cp -R "$SOURCE_APP" "$APP_DIR"

echo "Built $APP_DIR"
