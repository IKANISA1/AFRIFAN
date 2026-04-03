#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_SLUG="${1:-rayon_sports}"
APP_DIR="$ROOT/apps/$APP_SLUG"
PRODUCTION_JSON="$APP_DIR/assets/flavors/production.json"
STAGING_JSON="$APP_DIR/assets/flavors/staging.json"
ANDROID_KEY_PROPERTIES="$APP_DIR/android/key.properties"
ANDROID_KEYSTORE="$APP_DIR/android/upload-keystore.jks"
ANDROID_APP_KEYSTORE="$APP_DIR/android/app/upload-keystore.jks"
ANDROID_MAIN_ACTIVITY="$(find "$APP_DIR/android/app/src/main/kotlin" -name MainActivity.kt | head -n 1)"

if [ ! -d "$APP_DIR" ]; then
  echo "Unknown app slug: $APP_SLUG" >&2
  exit 1
fi

if [ ! -f "$PRODUCTION_JSON" ]; then
  echo "Missing production config: $PRODUCTION_JSON" >&2
  exit 1
fi

if [ ! -f "$STAGING_JSON" ]; then
  echo "Missing staging config: $STAGING_JSON" >&2
  exit 1
fi

python3 - "$PRODUCTION_JSON" "$APP_DIR" <<'PY'
import json
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
app_dir = pathlib.Path(sys.argv[2])
config = json.loads(config_path.read_text())
required = [
    "CLUB_ID",
    "CLUB_NAME",
    "APP_NAME",
    "CREST_ASSET",
    "HOME_TEAM_NAME",
    "HOME_VENUE_NAME",
    "RIVAL_TEAM_NAME",
    "PRIMARY_COMPETITION_NAME",
    "COUNTRY_CODE",
    "APP_SUPPORT_EMAIL",
    "APP_WEBSITE_URL",
    "APP_PRIVACY_URL",
    "APP_TERMS_URL",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "ENVIRONMENT",
]
missing = [key for key in required if not str(config.get(key, "")).strip()]
if missing:
    raise SystemExit(f"Missing required config keys: {', '.join(missing)}")

crest_asset = pathlib.Path(config["CREST_ASSET"])
crest_path = app_dir / crest_asset
if not crest_path.exists():
    raise SystemExit(f"Configured crest asset does not exist: {crest_path}")
PY

CLUB_CONFIG_PATH="$(find "$ROOT/packages/clubs" -path "*club_${APP_SLUG}/lib/src/*config.dart" | head -n 1)"
if [ -n "$CLUB_CONFIG_PATH" ] && rg -q "bool get hasBiopay => true;" "$CLUB_CONFIG_PATH"; then
  bash "$ROOT/tools/scripts/validate_biopay_firebase.sh" "$APP_SLUG"
  if [ -z "$ANDROID_MAIN_ACTIVITY" ] || ! rg -q "FlutterFragmentActivity" "$ANDROID_MAIN_ACTIVITY"; then
    echo "BioPay-enabled club must host Android on FlutterFragmentActivity." >&2
    echo "Update MainActivity for $APP_SLUG before release." >&2
    exit 1
  fi
fi

if [ -f "$ANDROID_KEY_PROPERTIES" ] || [ -f "$ANDROID_KEYSTORE" ] || [ -f "$ANDROID_APP_KEYSTORE" ]; then
  echo "Committed Android signing material detected for $APP_SLUG." >&2
  exit 1
fi

echo "Release validation passed for $APP_SLUG."
