#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_SLUG="${1:-rayon_sports}"
APP_DIR="$ROOT/apps/$APP_SLUG"
PRODUCTION_JSON="$APP_DIR/assets/flavors/production.json"
IOS_APP_PATH="$APP_DIR/build/ios/iphoneos/Runner.app"
IOS_ZIP_PATH="$APP_DIR/build/ios/iphoneos/Runner.app.zip"

if [ ! -d "$APP_DIR" ]; then
  echo "Unknown app slug: $APP_SLUG" >&2
  exit 1
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "iOS release dry-run requires macOS." >&2
  exit 2
fi

if [ ! -f "$PRODUCTION_JSON" ]; then
  echo "Missing production config: $PRODUCTION_JSON" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is required." >&2
  exit 2
fi

if ! command -v ditto >/dev/null 2>&1; then
  echo "ditto is required to package the unsigned iOS app artifact." >&2
  exit 2
fi

bash "$ROOT/tools/scripts/validate_flutter_runtime_pins.sh" --runtime
bash "$ROOT/tools/scripts/validate_club_release.sh" "$APP_SLUG"

(
  cd "$APP_DIR"
  flutter build ios --release --no-codesign \
    --dart-define-from-file=assets/flavors/production.json
)

if [ ! -d "$IOS_APP_PATH" ]; then
  echo "iOS release dry-run did not produce Runner.app: $IOS_APP_PATH" >&2
  exit 1
fi

rm -f "$IOS_ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$IOS_APP_PATH" "$IOS_ZIP_PATH"

if [ ! -f "$IOS_ZIP_PATH" ]; then
  echo "iOS release dry-run did not produce the packaged artifact: $IOS_ZIP_PATH" >&2
  exit 1
fi

echo "iOS release dry-run artifact ready:"
echo "$IOS_ZIP_PATH"
