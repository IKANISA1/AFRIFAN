#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_SLUG="${1:-rayon_sports}"
APP_DIR="$ROOT/apps/$APP_SLUG"
IOS_DIR="$APP_DIR/ios"
INFO_PLIST="$IOS_DIR/Runner/Info.plist"
ENTITLEMENTS_PLIST="$IOS_DIR/Runner/Runner.entitlements"
GOOGLE_SERVICE_INFO_PLIST="$IOS_DIR/Runner/GoogleService-Info.plist"
LAUNCH_SCREEN_STORYBOARD="$IOS_DIR/Runner/Base.lproj/LaunchScreen.storyboard"

if [ ! -d "$APP_DIR" ]; then
  echo "Unknown app slug: $APP_SLUG" >&2
  exit 1
fi

python3 - "$INFO_PLIST" "$ENTITLEMENTS_PLIST" "$GOOGLE_SERVICE_INFO_PLIST" "$LAUNCH_SCREEN_STORYBOARD" <<'PY'
import pathlib
import plistlib
import sys

info_path = pathlib.Path(sys.argv[1])
entitlements_path = pathlib.Path(sys.argv[2])
google_service_path = pathlib.Path(sys.argv[3])
launch_screen_path = pathlib.Path(sys.argv[4])

for path, label in (
    (info_path, "Info.plist"),
    (entitlements_path, "Runner.entitlements"),
    (google_service_path, "GoogleService-Info.plist"),
    (launch_screen_path, "LaunchScreen.storyboard"),
):
    if not path.exists():
        raise SystemExit(f"Missing {label}: {path}")

try:
    info = plistlib.loads(info_path.read_bytes())
except Exception as exc:
    raise SystemExit(f"Invalid Info.plist: {exc}") from exc

try:
    entitlements = plistlib.loads(entitlements_path.read_bytes())
except Exception as exc:
    raise SystemExit(f"Invalid Runner.entitlements: {exc}") from exc

try:
    google_service = plistlib.loads(google_service_path.read_bytes())
except Exception as exc:
    raise SystemExit(f"Invalid GoogleService-Info.plist: {exc}") from exc

background_modes = info.get("UIBackgroundModes") or []
if "remote-notification" not in background_modes:
    raise SystemExit(
        "Info.plist must declare remote-notification background mode for push delivery."
    )

app_attest_environment = str(
    entitlements.get("com.apple.developer.devicecheck.appattest-environment", "")
).strip()
if app_attest_environment != "production":
    raise SystemExit(
        "Runner.entitlements must set com.apple.developer.devicecheck.appattest-environment=production."
    )

aps_environment = str(entitlements.get("aps-environment", "")).strip()
if aps_environment != "production":
    raise SystemExit(
        "Runner.entitlements must set aps-environment=production for release push delivery."
    )

bundle_id = str(google_service.get("BUNDLE_ID", "")).strip()
project_id = str(google_service.get("PROJECT_ID", "")).strip()
app_id = str(google_service.get("GOOGLE_APP_ID", "")).strip()

if not bundle_id or bundle_id.startswith("com.example."):
    raise SystemExit("GoogleService-Info.plist must contain a real BUNDLE_ID.")
if not project_id:
    raise SystemExit("GoogleService-Info.plist must contain PROJECT_ID.")
if not app_id:
    raise SystemExit("GoogleService-Info.plist must contain GOOGLE_APP_ID.")

launch_storyboard = launch_screen_path.read_text()
if "<imageView" in launch_storyboard:
    raise SystemExit(
        "LaunchScreen.storyboard must not render a second branded native splash image."
    )
if "backgroundColor" not in launch_storyboard:
    raise SystemExit("LaunchScreen.storyboard must declare a solid background color.")

print(f"iOS release contract ok ({bundle_id}, project {project_id})")
PY
