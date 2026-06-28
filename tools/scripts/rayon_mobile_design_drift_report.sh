#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAIL_ON_FINDINGS=0

if [[ "${1:-}" == "--fail-on-findings" ]]; then
  FAIL_ON_FINDINGS=1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required for this report." >&2
  exit 2
fi

cd "$ROOT"

SCAN_PATHS=(
  "apps/rayon_sports/lib"
  "packages/features"
)

echo "Rayon Sports mobile design drift report"
echo "Root: $ROOT"
echo

TOTAL_FINDINGS=0

run_check() {
  local title="$1"
  local pattern="$2"
  shift 2
  local extra_args=()
  if [[ "$#" -gt 0 ]]; then
    extra_args=("$@")
  fi
  local matches

  if [[ "${#extra_args[@]}" -gt 0 ]]; then
    matches="$(
      rg -n "${extra_args[@]}" \
        --glob '*.dart' \
        --glob '!**/test/**' \
        --glob '!**/integration_test/**' \
        --glob '!**/*.g.dart' \
        --glob '!**/*.freezed.dart' \
        --glob '!**/*.mocks.dart' \
        "$pattern" \
        "${SCAN_PATHS[@]}" || true
    )"
  else
    matches="$(
      rg -n \
        --glob '*.dart' \
        --glob '!**/test/**' \
        --glob '!**/integration_test/**' \
        --glob '!**/*.g.dart' \
        --glob '!**/*.freezed.dart' \
        --glob '!**/*.mocks.dart' \
        "$pattern" \
        "${SCAN_PATHS[@]}" || true
    )"
  fi

  local count=0
  if [[ -n "$matches" ]]; then
    count="$(printf '%s\n' "$matches" | wc -l | tr -d ' ')"
  fi

  TOTAL_FINDINGS=$((TOTAL_FINDINGS + count))

  echo "==> $title: $count"
  if [[ "$count" != "0" ]]; then
    printf '%s\n' "$matches"
  fi
  echo
}

run_check "Raw TextStyle constructors" '\bTextStyle\s*\('
run_check "Small explicit font sizes under 14sp" 'fontSize:\s*([0-9]|10|11|12|13)\b'
run_check "Raw Material colors or direct hex colors" '\b(Colors\.(white|black)|Color\s*\(0x)'
run_check "Raw GestureDetector controls" '\bGestureDetector\s*\('
run_check "Direct Navigator usage" '\bNavigator\.'
run_check "Hardcoded Image.network URLs" 'Image\.network\s*\(\s*['\''"]'
run_check "Local gradient constructors" '\b(LinearGradient|RadialGradient|SweepGradient)\s*\('
run_check "Direct Material button widgets" '\b(TextButton|OutlinedButton|ElevatedButton)\s*\('
run_check "Visible placeholder or empty-section copy" '(Coming soon|No items yet|Nothing here|No [A-Za-z ]+ yet)'
run_check "Emoji codepoints in Dart UI source" '[\x{1F300}-\x{1FAFF}]' -P

echo "Total findings: $TOTAL_FINDINGS"

if [[ "$FAIL_ON_FINDINGS" == "1" && "$TOTAL_FINDINGS" != "0" ]]; then
  exit 1
fi
