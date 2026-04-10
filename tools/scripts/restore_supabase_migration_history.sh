#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  restore_supabase_migration_history.sh <remote-history.csv> [--truncate-first]

Environment:
  DATABASE_URL   Required. Remote Postgres connection string.

The CSV must contain:
  version,name

Use --truncate-first when restoring a previously backed-up migration ledger
after a failed repair or baseline reset.
EOF
}

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required." >&2
  exit 2
fi

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  usage >&2
  exit 2
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is required." >&2
  exit 2
fi

CSV_FILE="$1"
TRUNCATE_FIRST=0

if [ ! -f "$CSV_FILE" ]; then
  echo "History CSV not found: $CSV_FILE" >&2
  exit 2
fi

if [ "${2:-}" = "--truncate-first" ]; then
  TRUNCATE_FIRST=1
elif [ $# -eq 2 ]; then
  usage >&2
  exit 2
fi

if [ "$TRUNCATE_FIRST" -eq 1 ]; then
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
    "truncate table supabase_migrations.schema_migrations;"
fi

python3 - "$CSV_FILE" <<'PY' | psql "$DATABASE_URL" -v ON_ERROR_STOP=1
import csv
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
rows = []
with path.open("r", encoding="utf-8") as handle:
    reader = csv.reader(handle)
    for version, name in reader:
        version = version.strip()
        if not version:
            continue
        name = name.strip()
        rows.append((version, name))

print("begin;")
for version, name in rows:
    version_sql = version.replace("'", "''")
    name_sql = name.replace("'", "''")
    print(
        "insert into supabase_migrations.schema_migrations (version, name) "
        f"values ('{version_sql}', '{name_sql}') "
        "on conflict (version) do update set name = excluded.name;"
    )
print("commit;")
PY

echo "Restored $(wc -l < "$CSV_FILE" | tr -d ' ') migration history rows from $CSV_FILE."
