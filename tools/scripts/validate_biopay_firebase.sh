#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DEFAULT_FIREBASE_ENV_FILE="$ROOT/supabase/.env.firebase.local"
FIREBASE_ENV_FILE="${FIREBASE_ENV_FILE:-$DEFAULT_FIREBASE_ENV_FILE}"
DEFAULT_FIREBASE_SERVER_VALIDATION_MODE="auto"
if [ -n "${CI:-}" ] && [ "${GITHUB_EVENT_NAME:-}" != "pull_request" ]; then
  DEFAULT_FIREBASE_SERVER_VALIDATION_MODE="strict"
fi
FIREBASE_SERVER_VALIDATION_MODE="${FIREBASE_SERVER_VALIDATION_MODE:-$DEFAULT_FIREBASE_SERVER_VALIDATION_MODE}"
if [ -f "$FIREBASE_ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$FIREBASE_ENV_FILE"
  set +a
fi

if [ -n "${FIREBASE_SERVICE_ACCOUNT_FILE:-}" ] &&
  [ -z "${FIREBASE_SERVICE_ACCOUNT_JSON:-}" ]; then
  FIREBASE_SERVICE_ACCOUNT_JSON="$(
    python3 - "$FIREBASE_SERVICE_ACCOUNT_FILE" <<'PY'
import json
import pathlib
import sys

service_account_path = pathlib.Path(sys.argv[1])
try:
    service_account = json.loads(service_account_path.read_text())
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid JSON in {service_account_path}: {exc}") from exc

print(json.dumps(service_account, separators=(",", ":")))
PY
  )"
  export FIREBASE_SERVICE_ACCOUNT_JSON
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required to validate BioPay Firebase provisioning." >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to validate BioPay Firebase provisioning." >&2
  exit 2
fi

TARGET_APPS=()
if [ "$#" -gt 0 ]; then
  TARGET_APPS=("$@")
else
  while IFS= read -r slug; do
    TARGET_APPS+=("$slug")
  done < <(
    rg -l "bool get hasBioPay => true;" "$ROOT/packages/clubs" -g '*config.dart' \
      | sed -E 's#^.*/club_([^/]+)/lib/src/.*$#\1#' \
      | sort
  )
fi

if [ "${#TARGET_APPS[@]}" -eq 0 ]; then
  echo "No BioPay-enabled club configs found. Skipping Firebase provisioning validation."
  exit 0
fi

SERVICE_ACCOUNT_JSON_RAW="${FIREBASE_SERVICE_ACCOUNT_JSON:-}"
if [ -z "$SERVICE_ACCOUNT_JSON_RAW" ] && [ -n "${FIREBASE_SERVICE_ACCOUNT_FILE:-}" ]; then
  SERVICE_ACCOUNT_JSON_RAW="${FIREBASE_SERVICE_ACCOUNT_JSON:-}"
fi

SERVER_PROJECT_ID=""
SERVER_VALIDATION_ACTIVE=0

case "$FIREBASE_SERVER_VALIDATION_MODE" in
  auto)
    if [ -n "${SERVICE_ACCOUNT_JSON_RAW:-}" ]; then
      SERVER_VALIDATION_ACTIVE=1
    fi
    ;;
  strict | required | true | 1)
    SERVER_VALIDATION_ACTIVE=1
    ;;
  off | skip | false | 0)
    SERVER_VALIDATION_ACTIVE=0
    ;;
  *)
    echo "Invalid FIREBASE_SERVER_VALIDATION_MODE: $FIREBASE_SERVER_VALIDATION_MODE" >&2
    echo "Use one of: auto, strict, off" >&2
    exit 2
    ;;
esac

if [ "$SERVER_VALIDATION_ACTIVE" -eq 1 ]; then
  SERVER_PROJECT_ID="$(python3 - <<'PY'
import json
import os
import sys

raw = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
if not raw:
    raise SystemExit(
        "FIREBASE_SERVICE_ACCOUNT_JSON is required for BioPay App Check and FCM."
    )

try:
    service_account = json.loads(raw)
except json.JSONDecodeError as exc:
    raise SystemExit(
        f"FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON: {exc}"
    ) from exc

missing = [
    key for key in ("client_email", "private_key")
    if not str(service_account.get(key, "")).strip()
]
if missing:
    raise SystemExit(
        "FIREBASE_SERVICE_ACCOUNT_JSON is missing required fields: "
        + ", ".join(missing)
    )

service_project_id = str(service_account.get("project_id", "")).strip()
env_project_id = os.environ.get("FIREBASE_PROJECT_ID", "").strip()

project_id = env_project_id or service_project_id
if not project_id:
    raise SystemExit(
        "FIREBASE_PROJECT_ID is required when the service account JSON does not include project_id."
    )

if env_project_id and service_project_id and env_project_id != service_project_id:
    raise SystemExit(
        "FIREBASE_PROJECT_ID does not match FIREBASE_SERVICE_ACCOUNT_JSON.project_id."
    )

print(project_id)
PY
)"
fi

echo "BioPay Firebase and App Check provisioning check"
echo "Root: $ROOT"
if [ "$SERVER_VALIDATION_ACTIVE" -eq 1 ]; then
  echo "Server project: $SERVER_PROJECT_ID"
else
  echo "Server project: skipped (client Firebase config only)"
fi
if [ -f "$FIREBASE_ENV_FILE" ]; then
  echo "Runtime env: $FIREBASE_ENV_FILE"
fi
echo ""

missing=0

for slug in "${TARGET_APPS[@]}"; do
  app_dir="$ROOT/apps/$slug"
  android_config="$app_dir/android/app/google-services.json"
  ios_config="$app_dir/ios/Runner/GoogleService-Info.plist"

  if [ ! -d "$app_dir" ]; then
    echo "Unknown app slug: $slug" >&2
    missing=1
    continue
  fi

  echo "Checking $slug"

  if python3 - "$android_config" "$ios_config" "$SERVER_PROJECT_ID" <<'PY'
import json
import pathlib
import plistlib
import sys

android_path = pathlib.Path(sys.argv[1])
ios_path = pathlib.Path(sys.argv[2])
server_project_id = sys.argv[3].strip()

errors = []

if not android_path.exists():
    errors.append(f"android: missing {android_path}")
if not ios_path.exists():
    errors.append(f"ios: missing {ios_path}")
if errors:
    raise SystemExit("\n".join(errors))

try:
    android = json.loads(android_path.read_text())
except json.JSONDecodeError as exc:
    raise SystemExit(f"android: invalid JSON in {android_path}: {exc}") from exc

project_info = android.get("project_info") or {}
android_project_id = str(project_info.get("project_id", "")).strip()
if not android_project_id:
    raise SystemExit("android: project_info.project_id is missing")

clients = android.get("client")
if not isinstance(clients, list) or not clients:
    raise SystemExit("android: client list is missing")

android_client_info = (clients[0] or {}).get("client_info") or {}
android_app_id = str(android_client_info.get("mobilesdk_app_id", "")).strip()
if not android_app_id:
    raise SystemExit("android: client_info.mobilesdk_app_id is missing")

try:
    ios = plistlib.loads(ios_path.read_bytes())
except Exception as exc:
    raise SystemExit(f"ios: invalid plist in {ios_path}: {exc}") from exc

ios_project_id = str(ios.get("PROJECT_ID", "")).strip()
if not ios_project_id:
    raise SystemExit("ios: PROJECT_ID is missing")

ios_app_id = str(ios.get("GOOGLE_APP_ID", "")).strip()
if not ios_app_id:
    raise SystemExit("ios: GOOGLE_APP_ID is missing")

bundle_id = str(ios.get("BUNDLE_ID", "")).strip()
if not bundle_id:
    raise SystemExit("ios: BUNDLE_ID is missing")

if android_project_id != ios_project_id:
    raise SystemExit(
        "android and ios Firebase configs point to different project IDs: "
        f"{android_project_id} vs {ios_project_id}"
    )

if server_project_id and android_project_id != server_project_id:
    raise SystemExit(
        "client Firebase configs do not match the server project ID: "
        f"{android_project_id} vs {server_project_id}"
    )

print(f"  android: ok ({android_project_id})")
print(f"  ios: ok ({ios_project_id})")
if server_project_id:
    print(f"  server: ok ({server_project_id})")
PY
  then
    :
  else
    missing=1
  fi

  echo ""
done

if [ "$missing" -ne 0 ]; then
  echo "BioPay Firebase provisioning validation failed." >&2
  echo "Add the missing Firebase config files and server App Check credentials before shipping any BioPay-enabled flavor." >&2
  exit 1
fi

if [ "$SERVER_VALIDATION_ACTIVE" -eq 1 ]; then
  echo "BioPay Firebase and App Check provisioning is complete for the requested flavors."
else
  echo "BioPay client Firebase configs are valid for the requested flavors."
  echo "Server-side App Check validation was skipped because no Firebase service account credentials were provided."
fi
