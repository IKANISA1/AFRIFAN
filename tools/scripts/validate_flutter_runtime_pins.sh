#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PIN_FILE="$ROOT/.fvmrc"
WORKFLOW_DIR="$ROOT/.github/workflows"
CHECK_RUNTIME=false
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

if [ "${1:-}" = "--runtime" ]; then
  CHECK_RUNTIME=true
  if [ -n "${2:-}" ]; then
    FLUTTER_BIN="$2"
  fi
elif [ "$#" -gt 0 ]; then
  echo "Usage: $0 [--runtime [flutter-executable]]" >&2
  exit 2
fi

if [ ! -f "$PIN_FILE" ]; then
  echo "Missing controlled Flutter version file: $PIN_FILE" >&2
  exit 1
fi

PINNED_VERSION="$(tr -d '[:space:]' < "$PIN_FILE")"
if ! [[ "$PINNED_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid exact Flutter version in .fvmrc: $PINNED_VERSION" >&2
  exit 1
fi

WORKFLOWS=()
while IFS= read -r workflow; do
  WORKFLOWS+=("$workflow")
done < <(grep -R -l --include='*.yml' --include='*.yaml' \
  'subosito/flutter-action@' "$WORKFLOW_DIR" | sort)

if [ "${#WORKFLOWS[@]}" -eq 0 ]; then
  echo "No Flutter workflow setup actions were found." >&2
  exit 1
fi

ERRORS=0
SETUP_COUNT=0
for workflow in "${WORKFLOWS[@]}"; do
  while IFS=: read -r line_number _; do
    SETUP_COUNT=$((SETUP_COUNT + 1))
    block_end=$((line_number + 8))
    block="$(sed -n "${line_number},${block_end}p" "$workflow")"
    if ! grep -Eq \
      'flutter-version-file:[[:space:]]*["'"'"']?\.fvmrc["'"'"']?[[:space:]]*$' \
      <<< "$block"; then
      echo "$workflow:$line_number does not source Flutter from .fvmrc." >&2
      ERRORS=$((ERRORS + 1))
    fi
    if grep -Eq '^[[:space:]]*flutter-version:' <<< "$block"; then
      echo "$workflow:$line_number contains a competing Flutter version." >&2
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -n 'subosito/flutter-action@' "$workflow")
done

if grep -R -n --include='*.yml' --include='*.yaml' \
  '^[[:space:]]*flutter-version:' "$WORKFLOW_DIR"; then
  echo "Workflow-local Flutter versions must not compete with .fvmrc." >&2
  ERRORS=$((ERRORS + 1))
fi

if grep -R -n --include='*.sh' \
  'fvm/versions/[0-9][0-9.]*' "$ROOT/tools/scripts"; then
  echo "Release tooling contains a hard-coded FVM version." >&2
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -ne 0 ]; then
  echo "Flutter runtime pin validation failed with $ERRORS error(s)." >&2
  exit 1
fi

echo "Flutter runtime configuration is controlled by .fvmrc ($PINNED_VERSION) across $SETUP_COUNT workflow setup(s)."

if [ "$CHECK_RUNTIME" = true ]; then
  if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1 && [ ! -x "$FLUTTER_BIN" ]; then
    echo "Flutter executable not found: $FLUTTER_BIN" >&2
    exit 2
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to verify the active Flutter runtime." >&2
    exit 2
  fi

  ACTIVE_VERSION="$("$FLUTTER_BIN" --version --machine | jq -r '.frameworkVersion')"
  if [ "$ACTIVE_VERSION" != "$PINNED_VERSION" ]; then
    echo "Active Flutter $ACTIVE_VERSION does not match .fvmrc $PINNED_VERSION." >&2
    exit 1
  fi
  echo "Active Flutter runtime matches .fvmrc ($PINNED_VERSION)."
fi
