#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_SLUG="${1:-rayon_sports}"
APP_DIR="$ROOT/apps/$APP_SLUG"
PRODUCTION_JSON="$APP_DIR/assets/flavors/production.json"
ARTIFACT_PATH="$APP_DIR/build/app/outputs/bundle/release/app-release.aab"

if [ ! -d "$APP_DIR" ]; then
  echo "Unknown app slug: $APP_SLUG" >&2
  exit 1
fi

if [ ! -f "$PRODUCTION_JSON" ]; then
  echo "Missing production config: $PRODUCTION_JSON" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is required." >&2
  exit 2
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool is required to generate an ephemeral Android dry-run keystore." >&2
  exit 2
fi

bash "$ROOT/tools/scripts/validate_club_release.sh" "$APP_SLUG"

TEMP_DIR=""
cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

if [ -z "${ANDROID_KEYSTORE_PATH:-}" ] || \
  [ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ] || \
  [ -z "${ANDROID_KEY_ALIAS:-}" ] || \
  [ -z "${ANDROID_KEY_PASSWORD:-}" ]; then
  TEMP_DIR="$(mktemp -d)"
  export ANDROID_KEYSTORE_PATH="$TEMP_DIR/android-release-dry-run.jks"
  export ANDROID_KEYSTORE_PASSWORD="${ANDROID_KEYSTORE_PASSWORD:-android}"
  export ANDROID_KEY_ALIAS="${ANDROID_KEY_ALIAS:-africlub-dry-run}"
  export ANDROID_KEY_PASSWORD="${ANDROID_KEY_PASSWORD:-android}"

  keytool -genkeypair \
    -storetype JKS \
    -keystore "$ANDROID_KEYSTORE_PATH" \
    -storepass "$ANDROID_KEYSTORE_PASSWORD" \
    -alias "$ANDROID_KEY_ALIAS" \
    -keypass "$ANDROID_KEY_PASSWORD" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 3650 \
    -dname "CN=AFRICLUB Dry Run,O=AFRICLUB,OU=Mobile,L=Kigali,S=Kigali,C=RW" \
    >/dev/null 2>&1
fi

(
  cd "$APP_DIR"
  flutter build appbundle --release \
    --dart-define-from-file=assets/flavors/production.json
)

if [ ! -f "$ARTIFACT_PATH" ]; then
  echo "Android release dry-run did not produce an AAB: $ARTIFACT_PATH" >&2
  exit 1
fi

echo "Android release dry-run artifact ready:"
echo "$ARTIFACT_PATH"
