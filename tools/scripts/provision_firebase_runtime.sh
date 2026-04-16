#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_SUPABASE_PROJECT_REF=""
if [ -f "$ROOT/supabase/.temp/project-ref" ]; then
  DEFAULT_SUPABASE_PROJECT_REF="$(tr -d '\n' < "$ROOT/supabase/.temp/project-ref")"
fi

SERVICE_ACCOUNT_FILE=""
FIREBASE_PROJECT_ID=""
SUPABASE_PROJECT_REF="$DEFAULT_SUPABASE_PROJECT_REF"
ENV_FILE="$ROOT/supabase/.env.firebase.local"
PUSH_SUPABASE=0

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --service-account-file /path/to/firebase-service-account.json [options]

Options:
  --service-account-file PATH   Required. Firebase service account JSON file.
  --firebase-project-id ID      Optional. Overrides project id from the JSON.
  --supabase-project-ref REF    Optional. Defaults to linked ref in supabase/.temp/project-ref.
  --env-file PATH               Optional. Defaults to supabase/.env.firebase.local.
  --push-supabase               Push generated secrets to the Supabase project with supabase CLI.
  -h, --help                    Show this help.

This script generates the exact env keys expected by:
  - supabase/functions/_shared/app_check.ts
  - supabase/functions/_shared/fcm.ts

It never writes the service account JSON into tracked files.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --service-account-file)
      SERVICE_ACCOUNT_FILE="${2:-}"
      shift 2
      ;;
    --firebase-project-id)
      FIREBASE_PROJECT_ID="${2:-}"
      shift 2
      ;;
    --supabase-project-ref)
      SUPABASE_PROJECT_REF="${2:-}"
      shift 2
      ;;
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    --push-supabase)
      PUSH_SUPABASE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$SERVICE_ACCOUNT_FILE" ]; then
  echo "--service-account-file is required." >&2
  usage >&2
  exit 1
fi

if [ ! -f "$SERVICE_ACCOUNT_FILE" ]; then
  echo "Service account file not found: $SERVICE_ACCOUNT_FILE" >&2
  exit 1
fi

TMP_JSON="$(mktemp)"
python3 - "$SERVICE_ACCOUNT_FILE" "$FIREBASE_PROJECT_ID" "$TMP_JSON" <<'PY'
import json
import pathlib
import sys

service_account_path = pathlib.Path(sys.argv[1])
override_project_id = sys.argv[2].strip()
output_path = pathlib.Path(sys.argv[3])

try:
    service_account = json.loads(service_account_path.read_text())
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid JSON in {service_account_path}: {exc}") from exc

missing = [
    key for key in ("client_email", "private_key")
    if not str(service_account.get(key, "")).strip()
]
if missing:
    raise SystemExit(
        "Service account JSON is missing required fields: " + ", ".join(missing)
    )

service_project_id = str(service_account.get("project_id", "")).strip()
project_id = override_project_id or service_project_id
if not project_id:
    raise SystemExit(
        "Firebase project id is missing. Pass --firebase-project-id or use a service account with project_id."
    )

if override_project_id and service_project_id and override_project_id != service_project_id:
    raise SystemExit(
        "Provided --firebase-project-id does not match the service account JSON project_id."
    )

output = {
    "project_id": project_id,
    "service_account_json": json.dumps(service_account, separators=(",", ":")),
    "client_email": service_account["client_email"],
}
output_path.write_text(json.dumps(output))
PY

PROJECT_ID="$(python3 - "$TMP_JSON" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(data["project_id"])
PY
)"

SERVICE_ACCOUNT_JSON="$(python3 - "$TMP_JSON" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(data["service_account_json"])
PY
)"

CLIENT_EMAIL="$(python3 - "$TMP_JSON" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(data["client_email"])
PY
)"

rm -f "$TMP_JSON"

mkdir -p "$(dirname "$ENV_FILE")"
cat > "$ENV_FILE" <<EOF
FIREBASE_PROJECT_ID=$PROJECT_ID
FIREBASE_SERVICE_ACCOUNT_JSON='$SERVICE_ACCOUNT_JSON'
EOF

echo "Generated Firebase runtime env file:"
echo "  $ENV_FILE"
echo ""
echo "Firebase project:"
echo "  $PROJECT_ID"
echo "Service account:"
echo "  $CLIENT_EMAIL"
echo ""
echo "Local validation:"
echo "  FIREBASE_ENV_FILE=$ENV_FILE bash tools/scripts/validate_BioPay_firebase.sh rayon_sports"

if [ "$PUSH_SUPABASE" -eq 1 ]; then
  if [ -z "$SUPABASE_PROJECT_REF" ]; then
    echo "Supabase project ref is required for --push-supabase." >&2
    exit 1
  fi

  echo ""
  echo "Pushing secrets to Supabase project $SUPABASE_PROJECT_REF..."
  supabase secrets set \
    --project-ref "$SUPABASE_PROJECT_REF" \
    --env-file "$ENV_FILE"
  echo "Supabase secrets updated."
fi
