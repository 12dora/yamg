#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-"$ROOT_DIR/.build/xcode-derived-data"}"
PROJECT="$ROOT_DIR/YAMG.xcodeproj"
SCHEME="${SCHEME:-YAMG}"
CONFIGURATION="${CONFIGURATION:-Debug}"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/YAMG.app"

if [[ "${LAUNCH_APP:-1}" == "1" ]]; then
  open "$APP_PATH"
fi

printf 'Built %s\n' "$APP_PATH"
