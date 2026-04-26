#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PROJECT_PATH="$ROOT_DIR/Bansh.xcodeproj"
SCHEME="BanshInputMethod"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData}"
TEST_BUNDLE_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/BanshCoreTests.xctest"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build-for-testing

if [[ ! -d "$TEST_BUNDLE_PATH" ]]; then
  echo "Expected test bundle at $TEST_BUNDLE_PATH" >&2
  exit 1
fi

xcrun xctest "$TEST_BUNDLE_PATH"
