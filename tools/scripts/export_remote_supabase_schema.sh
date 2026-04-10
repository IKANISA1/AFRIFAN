#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/supabase/recovery}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BUNDLE_DIR="$OUTPUT_DIR/schema_$TIMESTAMP"
SCHEMA_FILE="$BUNDLE_DIR/remote_schema.sql"
HISTORY_FILE="$BUNDLE_DIR/remote_history.csv"
SCHEMA_SCOPE_FILE="$BUNDLE_DIR/schema_scope.txt"

usage() {
  cat <<'EOF'
Usage:
  export_remote_supabase_schema.sh

Environment:
  DATABASE_URL   Required. Remote Postgres connection string.
  OUTPUT_DIR     Optional. Defaults to supabase/recovery.
  SCHEMAS        Optional. Comma-separated schema list. Defaults to
                 public,graphql_public.
  INCLUDE_ALL_SCHEMAS
                 Optional. Set to 1 to dump all schemas visible to the role.

Exports:
  - remote_schema.sql
  - remote_history.csv
  - schema_scope.txt
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

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is required." >&2
  exit 2
fi

mkdir -p "$BUNDLE_DIR"

SCHEMAS_RAW="${SCHEMAS:-public,graphql_public}"
INCLUDE_ALL_SCHEMAS="${INCLUDE_ALL_SCHEMAS:-0}"

PG_DUMP_ARGS=(
  --schema-only
  --no-owner
  --no-privileges
  --file="$SCHEMA_FILE"
)

if [ "$INCLUDE_ALL_SCHEMAS" = "1" ]; then
  echo "all" > "$SCHEMA_SCOPE_FILE"
else
  IFS=',' read -r -a SCHEMA_LIST <<< "$SCHEMAS_RAW"
  if [ "${#SCHEMA_LIST[@]}" -eq 0 ]; then
    echo "At least one schema must be provided in SCHEMAS." >&2
    exit 2
  fi

  : > "$SCHEMA_SCOPE_FILE"
  for schema in "${SCHEMA_LIST[@]}"; do
    schema="${schema// /}"
    if [ -z "$schema" ]; then
      continue
    fi
    PG_DUMP_ARGS+=(--schema="$schema")
    echo "$schema" >> "$SCHEMA_SCOPE_FILE"
  done

  if [ ! -s "$SCHEMA_SCOPE_FILE" ]; then
    echo "At least one non-empty schema must be provided in SCHEMAS." >&2
    exit 2
  fi
fi

PG_DUMP_BIN=""
for candidate in \
  /usr/local/opt/postgresql@17/bin/pg_dump \
  /opt/homebrew/opt/postgresql@17/bin/pg_dump \
  "$(command -v pg_dump 2>/dev/null || true)"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    PG_DUMP_BIN="$candidate"
    break
  fi
done

if [ -n "$PG_DUMP_BIN" ]; then
  "$PG_DUMP_BIN" "$DATABASE_URL" "${PG_DUMP_ARGS[@]}"
elif command -v supabase >/dev/null 2>&1; then
  if [ "$INCLUDE_ALL_SCHEMAS" = "1" ]; then
    supabase db dump \
      --db-url "$DATABASE_URL" \
      --file "$SCHEMA_FILE"
  else
    supabase db dump \
      --db-url "$DATABASE_URL" \
      --file "$SCHEMA_FILE" \
      --schema "$(paste -sd, "$SCHEMA_SCOPE_FILE")"
  fi
else
  echo "A compatible pg_dump binary or supabase CLI is required." >&2
  exit 2
fi

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -F ',' -Atqc \
  "select version, coalesce(name, '') from supabase_migrations.schema_migrations order by version;" \
  > "$HISTORY_FILE"

echo "bundle_dir=$BUNDLE_DIR"
echo "schema_file=$SCHEMA_FILE"
echo "history_file=$HISTORY_FILE"
echo "schema_scope_file=$SCHEMA_SCOPE_FILE"
