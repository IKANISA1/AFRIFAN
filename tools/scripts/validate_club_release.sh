#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_SLUG="${1:-rayon_sports}"
APP_DIR="$ROOT/apps/$APP_SLUG"
PRODUCTION_JSON="$APP_DIR/assets/flavors/production.json"
STAGING_JSON="$APP_DIR/assets/flavors/staging.json"
ANDROID_KEY_PROPERTIES="$APP_DIR/android/key.properties"
ANDROID_KEYSTORE_PROPERTIES="$APP_DIR/android/keystore.properties"
ANDROID_KEYSTORE="$APP_DIR/android/upload-keystore.jks"
ANDROID_APP_KEYSTORE="$APP_DIR/android/app/upload-keystore.jks"
PLAY_STORE_SERVICE_ACCOUNT_JSON="$APP_DIR/android/fastlane/play-store-service-account.json"
ANDROID_MAIN_ACTIVITY="$(find "$APP_DIR/android/app/src/main/kotlin" -name MainActivity.kt | head -n 1)"
ANDROID_V31_STYLES="$APP_DIR/android/app/src/main/res/values-v31/styles.xml"
ANDROID_V31_STYLES_NIGHT="$APP_DIR/android/app/src/main/res/values-night-v31/styles.xml"
ANDROID_LAUNCH_BACKGROUND="$APP_DIR/android/app/src/main/res/drawable/launch_background.xml"
ANDROID_TRANSPARENT_SPLASH_ICON="$APP_DIR/android/app/src/main/res/drawable/transparent_splash_icon.xml"

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

bash "$ROOT/tools/scripts/validate_ios_release_contract.sh" "$APP_SLUG"

python3 - "$PRODUCTION_JSON" "$APP_DIR" <<'PY'
import json
import pathlib
import urllib.error
import urllib.request
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

def verify_public_url(url: str, label: str) -> None:
    if not url.startswith("https://"):
        raise SystemExit(f"{label} must use HTTPS: {url}")

    headers = {"User-Agent": "Mozilla/5.0 (release-validator)"}
    attempts = [
        urllib.request.Request(url, headers=headers, method="HEAD"),
        urllib.request.Request(url, headers=headers, method="GET"),
    ]
    last_error = None
    for request in attempts:
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                status = getattr(response, "status", 200) or 200
                if 200 <= status < 400:
                    return
                last_error = f"HTTP {status}"
        except urllib.error.HTTPError as exc:
            if 200 <= exc.code < 400:
                return
            last_error = f"HTTP {exc.code}"
        except Exception as exc:  # noqa: BLE001
            last_error = str(exc)

    raise SystemExit(f"{label} is not publicly reachable: {url} ({last_error})")

verify_public_url(config["APP_WEBSITE_URL"], "APP_WEBSITE_URL")
verify_public_url(config["APP_PRIVACY_URL"], "APP_PRIVACY_URL")
verify_public_url(config["APP_TERMS_URL"], "APP_TERMS_URL")
PY

for required_file in \
  "$ANDROID_V31_STYLES" \
  "$ANDROID_V31_STYLES_NIGHT" \
  "$ANDROID_LAUNCH_BACKGROUND" \
  "$ANDROID_TRANSPARENT_SPLASH_ICON"; do
  if [ ! -f "$required_file" ]; then
    echo "Missing Android splash contract file: $required_file" >&2
    exit 1
  fi
done

for styles_file in "$ANDROID_V31_STYLES" "$ANDROID_V31_STYLES_NIGHT"; do
  if ! rg -q 'windowSplashScreenAnimatedIcon">@drawable/transparent_splash_icon<' "$styles_file"; then
    echo "Android 12 splash must use transparent_splash_icon in $styles_file." >&2
    exit 1
  fi
  if ! rg -q 'windowSplashScreenAnimationDuration">0<' "$styles_file"; then
    echo "Android 12 splash animation duration must be 0 in $styles_file." >&2
    exit 1
  fi
  if ! rg -q 'windowBackground">@drawable/launch_background<' "$styles_file"; then
    echo "LaunchTheme must point at launch_background in $styles_file." >&2
    exit 1
  fi
done

if rg -q '<bitmap|android:src=|@mipmap|@drawable/.+crest|@drawable/.+logo' "$ANDROID_LAUNCH_BACKGROUND"; then
  echo "launch_background.xml must stay a plain background without a branded icon." >&2
  exit 1
fi

python3 - "$PRODUCTION_JSON" \
  "$APP_DIR/store_metadata/play_store/listing.md" \
  "$APP_DIR/store_metadata/privacy_policy.html" \
  "$APP_DIR/landing/privacy/index.html" \
  "$APP_DIR/landing/terms/index.html" <<'PY'
import json
import pathlib
import sys

config = json.loads(pathlib.Path(sys.argv[1]).read_text())
support_email = config["APP_SUPPORT_EMAIL"]
website_url = config["APP_WEBSITE_URL"]
privacy_url = config["APP_PRIVACY_URL"]

checks = {
    pathlib.Path(sys.argv[2]): [support_email, website_url, privacy_url],
    pathlib.Path(sys.argv[3]): [support_email, website_url],
    pathlib.Path(sys.argv[4]): [support_email, website_url],
    pathlib.Path(sys.argv[5]): [support_email, website_url],
}

missing = []
for path, expected_values in checks.items():
    if not path.exists():
      missing.append(f"missing file: {path}")
      continue
    content = path.read_text()
    for value in expected_values:
      if value not in content:
        missing.append(f"{path}: missing expected value {value}")

if missing:
    raise SystemExit("\n".join(missing))
PY

STALE_RELEASE_HITS="$(
  rg -n -F \
    -e 'rw.rayonsport.gikundiro' \
    -e 'gikundiro.ikanisa.com' \
    -e 'support@gikundiro.ikanisa.com' \
    -e 'Firebase (crash analytics)' \
    -e '| Email address | Yes | No | Account authentication | Yes |' \
    -e '**Account management**: Email/phone for authentication' \
    -e 'Transaction records are retained for 12 months' \
    -e 'AFRICLUB official' \
    "$APP_DIR" \
    "$ROOT/packages/features/feat_settings/lib/src/settings_actions.dart" \
    || true
)"

if [ -n "$STALE_RELEASE_HITS" ]; then
  echo "Stale release metadata or package identifiers detected for $APP_SLUG." >&2
  echo "$STALE_RELEASE_HITS" >&2
  exit 1
fi

python3 - "$ROOT/packages/features" "$APP_DIR/lib" <<'PY'
import pathlib
import re
import sys

targets = [pathlib.Path(arg) for arg in sys.argv[1:] if pathlib.Path(arg).exists()]
pattern = re.compile(r"""(['"])(?:(?=(\\?))\2.)*?AFRICLUB(?:(?=(\\?))\3.)*?\1""")
hits = []

for target in targets:
    for path in target.rglob("*.dart"):
        if "/test/" in path.as_posix():
            continue
        text = path.read_text()
        if pattern.search(text):
            hits.append(str(path))

if hits:
    raise SystemExit(
        "User-facing placeholder branding detected in production Dart sources:\n"
        + "\n".join(sorted(hits))
    )
PY

CLUB_CONFIG_PATH="$(find "$ROOT/packages/clubs" -path "*club_${APP_SLUG}/lib/src/*config.dart" | head -n 1)"
if [ -n "$CLUB_CONFIG_PATH" ] && rg -q "bool get hasBioPay => true;" "$CLUB_CONFIG_PATH"; then
  bash "$ROOT/tools/scripts/validate_BioPay_firebase.sh" "$APP_SLUG"
  if [ -z "$ANDROID_MAIN_ACTIVITY" ] || ! rg -q "FlutterFragmentActivity" "$ANDROID_MAIN_ACTIVITY"; then
    echo "BioPay-enabled club must host Android on FlutterFragmentActivity." >&2
    echo "Update MainActivity for $APP_SLUG before release." >&2
    exit 1
  fi
fi

tracked_signing_files=()
for candidate in \
  "$ANDROID_KEY_PROPERTIES" \
  "$ANDROID_KEYSTORE_PROPERTIES" \
  "$ANDROID_KEYSTORE" \
  "$ANDROID_APP_KEYSTORE" \
  "$PLAY_STORE_SERVICE_ACCOUNT_JSON"; do
  relative_path="${candidate#"$ROOT"/}"
  if [ -e "$candidate" ] && git -C "$ROOT" ls-files --error-unmatch "$relative_path" >/dev/null 2>&1; then
    tracked_signing_files+=("$relative_path")
  fi
done

if [ "${#tracked_signing_files[@]}" -gt 0 ]; then
  echo "Committed mobile release credentials detected for $APP_SLUG." >&2
  printf 'Tracked files:\n' >&2
  printf '  - %s\n' "${tracked_signing_files[@]}" >&2
  exit 1
fi

echo "Release validation passed for $APP_SLUG."
