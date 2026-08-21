#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_SLUG="${1:-rayon_sports}"
APP_DIR="$ROOT/apps/$APP_SLUG"
IOS_DIR="$APP_DIR/ios"
IOS_SWIFTPM_MANIFEST="$IOS_DIR/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
IOS_MINIMUM_VERSION="${IOS_MINIMUM_VERSION:-15.5}"

if [ ! -d "$APP_DIR" ]; then
  echo "Unknown app slug: $APP_SLUG" >&2
  exit 1
fi

if [ ! -f "$IOS_SWIFTPM_MANIFEST" ]; then
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "Skipping absent iOS SwiftPM manifest outside macOS."
    exit 0
  fi

  if ! command -v flutter >/dev/null 2>&1; then
    echo "flutter is required to generate the iOS SwiftPM manifest." >&2
    exit 2
  fi

  FLAVOR_FILE="$APP_DIR/assets/flavors/production.local.json"
  if [ ! -f "$FLAVOR_FILE" ]; then
    FLAVOR_FILE="$APP_DIR/assets/flavors/production.json"
  fi

  (
    cd "$APP_DIR"
    flutter build ios --config-only --no-codesign --no-pub \
      --dart-define-from-file="$FLAVOR_FILE"
  )
fi

python3 "$ROOT/tools/scripts/sync_ios_swiftpm_deployment_target.py" \
  --manifest "$IOS_SWIFTPM_MANIFEST" \
  --minimum "$IOS_MINIMUM_VERSION"
