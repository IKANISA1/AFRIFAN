#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATIONS_DIR="$ROOT/supabase/migrations"
ARCHIVE_ROOT="$ROOT/supabase/migrations_archive"
RECOVERY_ROOT="$ROOT/supabase/recovery"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BUNDLE_DIR="$RECOVERY_ROOT/baseline_reset_$TIMESTAMP"
REMOTE_HISTORY_FILE="$BUNDLE_DIR/remote_history_before.csv"
REMOTE_VERSIONS_FILE="$BUNDLE_DIR/remote_versions_before.txt"
LOCAL_VERSIONS_FILE="$BUNDLE_DIR/local_versions_before.txt"
PLAN_FILE="$BUNDLE_DIR/plan.txt"
VERIFY_FILE="$BUNDLE_DIR/verification.txt"
SCHEMA_FILE="$BUNDLE_DIR/remote_schema.sql"
SCOPE_FILE="$BUNDLE_DIR/schema_scope.txt"
BASELINE_VERSION="$(date -u +%Y%m%d%H%M%S)"
BASELINE_NAME="remote_schema_baseline"
SCHEMAS="${SCHEMAS:-public,graphql_public}"
EXECUTE=0

ARCHIVE_DIR=""
LOCAL_BASELINE_FILE=""
REMOTE_RESET_DONE=0
LOCAL_ARCHIVE_DONE=0

usage() {
  cat <<'EOF'
Usage:
  reset_supabase_to_remote_baseline.sh [--execute] [--baseline-version YYYYMMDDHHMMSS] [--baseline-name name]

Environment:
  DATABASE_URL   Required. Remote Postgres connection string.
  SCHEMAS        Optional. Comma-separated schema list to baseline.
                 Defaults to public,graphql_public.

Default mode is dry-run. Use --execute to:
  1. Back up the remote migration ledger.
  2. Export the live schema for the selected schemas.
  3. Archive the existing local migration chain.
  4. Install a single baseline migration locally.
  5. Replace the remote migration ledger with that baseline version.
  6. Verify that supabase db push --dry-run no longer fails on history mismatch.
EOF
}

cleanup() {
  local status=$?
  if [ "$status" -ne 0 ] && [ "$EXECUTE" -eq 1 ]; then
    if [ "$REMOTE_RESET_DONE" -eq 1 ] && [ -f "$REMOTE_HISTORY_FILE" ]; then
      DATABASE_URL="$DATABASE_URL" \
        bash "$ROOT/tools/scripts/restore_supabase_migration_history.sh" \
        "$REMOTE_HISTORY_FILE" \
        --truncate-first >/dev/null 2>&1 || true
    fi

    if [ "$LOCAL_ARCHIVE_DONE" -eq 1 ] && [ -n "$ARCHIVE_DIR" ] && [ -d "$ARCHIVE_DIR" ]; then
      rm -f "$MIGRATIONS_DIR"/*.sql
      while IFS= read -r file; do
        mv "$file" "$MIGRATIONS_DIR/"
      done < <(find "$ARCHIVE_DIR" -maxdepth 1 -type f -name '*.sql' | sort)
      rmdir "$ARCHIVE_DIR" 2>/dev/null || true
    fi
  fi
  trap - EXIT
  return "$status"
}
trap cleanup EXIT

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required." >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required." >&2
  exit 2
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --execute)
      EXECUTE=1
      shift
      ;;
    --baseline-version)
      BASELINE_VERSION="${2:-}"
      shift 2
      ;;
    --baseline-name)
      BASELINE_NAME="${2:-}"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is required." >&2
  exit 2
fi

if [[ ! "$BASELINE_VERSION" =~ ^[0-9]{14}$ ]]; then
  echo "Baseline version must be 14 digits." >&2
  exit 2
fi

if [[ ! "$BASELINE_NAME" =~ ^[a-z0-9_]+$ ]]; then
  echo "Baseline name must use lowercase letters, numbers, or underscores." >&2
  exit 2
fi

mkdir -p "$BUNDLE_DIR"
mkdir -p "$ARCHIVE_ROOT"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -F ',' -Atqc \
  "select version, coalesce(name, '') from supabase_migrations.schema_migrations order by version;" \
  > "$REMOTE_HISTORY_FILE"

cut -d',' -f1 "$REMOTE_HISTORY_FILE" > "$REMOTE_VERSIONS_FILE"

python3 - "$MIGRATIONS_DIR" "$LOCAL_VERSIONS_FILE" <<'PY'
import pathlib
import re
import sys

migrations_dir = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])
versions = []
for path in sorted(migrations_dir.glob("*.sql")):
    match = re.match(r"(\d{14})_", path.name)
    if match:
        versions.append(match.group(1))
output_path.write_text("\n".join(sorted(set(versions))) + "\n")
PY

OUTPUT_DIR="$BUNDLE_DIR" SCHEMAS="$SCHEMAS" \
  bash "$ROOT/tools/scripts/export_remote_supabase_schema.sh" >/dev/null

mv "$BUNDLE_DIR"/schema_*/remote_schema.sql "$SCHEMA_FILE"
mv "$BUNDLE_DIR"/schema_*/schema_scope.txt "$SCOPE_FILE"
rm -f "$BUNDLE_DIR"/schema_*/remote_history.csv
rmdir "$BUNDLE_DIR"/schema_* 2>/dev/null || true

LOCAL_COUNT="$(wc -l < "$LOCAL_VERSIONS_FILE" | tr -d ' ')"
REMOTE_COUNT="$(wc -l < "$REMOTE_VERSIONS_FILE" | tr -d ' ')"
ARCHIVE_DIR="$ARCHIVE_ROOT/$TIMESTAMP"
LOCAL_BASELINE_FILE="$MIGRATIONS_DIR/${BASELINE_VERSION}_${BASELINE_NAME}.sql"

{
  echo "bundle_dir=$BUNDLE_DIR"
  echo "schemas=$(paste -sd, "$SCOPE_FILE")"
  echo "baseline_version=$BASELINE_VERSION"
  echo "baseline_name=$BASELINE_NAME"
  echo "local_migration_count_before=$LOCAL_COUNT"
  echo "remote_migration_count_before=$REMOTE_COUNT"
  echo "archive_dir=$ARCHIVE_DIR"
  echo "local_baseline_file=$LOCAL_BASELINE_FILE"
  echo "mode=$([ "$EXECUTE" -eq 1 ] && echo execute || echo dry-run)"
} > "$PLAN_FILE"

if [ "$EXECUTE" -eq 0 ]; then
  cat "$PLAN_FILE"
  echo "Dry run: no local files or remote history were changed."
  exit 0
fi

mkdir -p "$ARCHIVE_DIR"
find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name '*.sql' -print0 | while IFS= read -r -d '' file; do
  mv "$file" "$ARCHIVE_DIR/"
done
LOCAL_ARCHIVE_DONE=1

cp "$SCHEMA_FILE" "$LOCAL_BASELINE_FILE"

python3 - "$REMOTE_HISTORY_FILE" "$BASELINE_VERSION" "$BASELINE_NAME" <<'PY' | \
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 >/dev/null
import csv
import pathlib
import sys

history_path = pathlib.Path(sys.argv[1])
baseline_version = sys.argv[2]
baseline_name = sys.argv[3]
versions = []
with history_path.open("r", encoding="utf-8") as handle:
    reader = csv.reader(handle)
    for version, _name in reader:
        version = version.strip()
        if version:
            versions.append(version)

print("begin;")
if versions:
    joined = ", ".join("'" + version.replace("'", "''") + "'" for version in versions)
    print(
        "delete from supabase_migrations.schema_migrations "
        f"where version in ({joined});"
    )
print(
    "insert into supabase_migrations.schema_migrations (version, name) "
    f"values ('{baseline_version}', '{baseline_name}') "
    "on conflict (version) do update set name = excluded.name;"
)
print("commit;")
PY
REMOTE_RESET_DONE=1

REMOTE_STATE="$(
  psql "$DATABASE_URL" -Atqc \
    "select version || ',' || coalesce(name, '') from supabase_migrations.schema_migrations order by version;"
)"

printf '%s\n' "$REMOTE_STATE" > "$VERIFY_FILE"

if [ "$REMOTE_STATE" != "${BASELINE_VERSION},${BASELINE_NAME}" ]; then
  echo "Remote migration ledger verification failed." >&2
  exit 1
fi

supabase db push --dry-run --db-url "$DATABASE_URL" >> "$VERIFY_FILE"

{
  echo "remote_ledger=${BASELINE_VERSION},${BASELINE_NAME}"
  echo "db_push_check=passed"
} >> "$VERIFY_FILE"

cat "$PLAN_FILE"
cat "$VERIFY_FILE"
