#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATIONS_DIR="$ROOT/supabase/migrations"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/supabase/recovery}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BUNDLE_DIR="$OUTPUT_DIR/lineage_$TIMESTAMP"

usage() {
  cat <<'EOF'
Usage:
  audit_supabase_migration_lineage.sh

Environment:
  DATABASE_URL   Required. Remote Postgres connection string.
  OUTPUT_DIR     Optional. Defaults to supabase/recovery.

Outputs:
  - remote_history.csv
  - local_versions.txt
  - remote_versions.txt
  - remote_only_versions.txt
  - local_only_versions.txt
  - summary.txt
EOF
}

if [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required." >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required." >&2
  exit 2
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is required." >&2
  exit 2
fi

mkdir -p "$BUNDLE_DIR"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -F ',' -Atqc \
  "select version, coalesce(name, '') from supabase_migrations.schema_migrations order by version;" \
  > "$BUNDLE_DIR/remote_history.csv"

python3 - "$MIGRATIONS_DIR" "$BUNDLE_DIR/local_versions.txt" <<'PY'
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

cut -d',' -f1 "$BUNDLE_DIR/remote_history.csv" > "$BUNDLE_DIR/remote_versions.txt"
comm -23 "$BUNDLE_DIR/remote_versions.txt" "$BUNDLE_DIR/local_versions.txt" \
  > "$BUNDLE_DIR/remote_only_versions.txt"
comm -13 "$BUNDLE_DIR/remote_versions.txt" "$BUNDLE_DIR/local_versions.txt" \
  > "$BUNDLE_DIR/local_only_versions.txt"

REMOTE_ONLY_COUNT="$(wc -l < "$BUNDLE_DIR/remote_only_versions.txt" | tr -d ' ')"
LOCAL_ONLY_COUNT="$(wc -l < "$BUNDLE_DIR/local_only_versions.txt" | tr -d ' ')"
REMOTE_COUNT="$(wc -l < "$BUNDLE_DIR/remote_versions.txt" | tr -d ' ')"
LOCAL_COUNT="$(wc -l < "$BUNDLE_DIR/local_versions.txt" | tr -d ' ')"

{
  echo "bundle_dir=$BUNDLE_DIR"
  echo "remote_count=$REMOTE_COUNT"
  echo "local_count=$LOCAL_COUNT"
  echo "remote_only_count=$REMOTE_ONLY_COUNT"
  echo "local_only_count=$LOCAL_ONLY_COUNT"
} > "$BUNDLE_DIR/summary.txt"

cat "$BUNDLE_DIR/summary.txt"
