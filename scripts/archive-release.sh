#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PROJECT_PATH="$ROOT_DIR/Bansh.xcodeproj"
SCHEME="BanshInputMethod"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/ReleaseDerivedData}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/release/BanshInputMethod.xcarchive}"

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

Set up an Apple Development certificate in Xcode or pass BANSH_DEVELOPMENT_TEAM=<your team id>.
Do not commit personal Apple team IDs to the project.
EOF
  exit 1
fi

/bin/mkdir -p "$(dirname "$ARCHIVE_PATH")"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  archive

echo "Archived $ARCHIVE_PATH"
