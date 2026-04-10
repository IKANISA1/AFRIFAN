#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATIONS_DIR="$ROOT/supabase/migrations"

usage() {
  cat <<'EOF'
Usage:
  repair_supabase_migration_history.sh <migration-version-or-file> [--dry-run]

Examples:
  repair_supabase_migration_history.sh 20260410230000
  repair_supabase_migration_history.sh supabase/migrations/20260410230000_create_request_rate_limit_function.sql

Environment:
  DATABASE_URL   Required. Remote Postgres connection string.

This script records an already-applied migration in
supabase_migrations.schema_migrations without replaying the SQL file.
Use it only when the remote schema is already in the expected state.
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

TARGET="$1"
DRY_RUN=0
if [ "${2:-}" = "--dry-run" ]; then
  DRY_RUN=1
elif [ $# -eq 2 ]; then
  usage >&2
  exit 2
fi

resolve_migration_file() {
  local target="$1"

  if [ -f "$target" ]; then
    printf '%s\n' "$target"
    return 0
  fi

  if [ -f "$ROOT/$target" ]; then
    printf '%s\n' "$ROOT/$target"
    return 0
  fi

  if [[ "$target" =~ ^[0-9]{14}$ ]]; then
    local matches=()
    while IFS= read -r file; do
      matches+=("$file")
    done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name "${target}_*.sql" | sort)

    if [ "${#matches[@]}" -eq 1 ]; then
      printf '%s\n' "${matches[0]}"
      return 0
    fi

    if [ "${#matches[@]}" -gt 1 ]; then
      echo "Multiple migration files match version $target." >&2
      printf '  %s\n' "${matches[@]}" >&2
      exit 2
    fi
  fi

  echo "Could not resolve migration file for: $target" >&2
  exit 2
}

MIGRATION_FILE="$(resolve_migration_file "$TARGET")"
BASENAME="$(basename "$MIGRATION_FILE")"

if [[ ! "$BASENAME" =~ ^([0-9]{14})_(.+)\.sql$ ]]; then
  echo "Invalid migration filename: $BASENAME" >&2
  exit 2
fi

VERSION="${BASH_REMATCH[1]}"
NAME="${BASH_REMATCH[2]}"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run: would record migration $VERSION ($NAME)"
  exit 0
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is required." >&2
  exit 2
fi

RECORDED="$(
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -Atqc \
    "select 1 from supabase_migrations.schema_migrations where version = '$VERSION' limit 1;"
)"

if [ "$RECORDED" = "1" ]; then
  echo "Migration $VERSION is already recorded."
  exit 0
fi

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
  "insert into supabase_migrations.schema_migrations (version, name)
   values ('$VERSION', '$NAME');"

echo "Recorded migration $VERSION ($NAME)."
