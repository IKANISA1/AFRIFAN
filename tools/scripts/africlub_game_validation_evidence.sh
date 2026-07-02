#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

failures=0
skips=0
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
if [[ -z "$FLUTTER_BIN" && -x "/Volumes/PRO-G40/flutter_3_44/bin/flutter" ]]; then
  FLUTTER_BIN="/Volumes/PRO-G40/flutter_3_44/bin/flutter"
fi

run_required() {
  local label="$1"
  shift

  echo
  echo "==> REQUIRED: $label"
  if "$@"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label" >&2
    failures=$((failures + 1))
  fi
}

run_optional_tool() {
  local label="$1"
  local tool="$2"
  shift 2

  echo
  echo "==> TOOLCHAIN: $label"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP: $label requires $tool on PATH."
    skips=$((skips + 1))
    return 0
  fi

  if "$@"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label" >&2
    failures=$((failures + 1))
  fi
}

run_optional_env() {
  local label="$1"
  local env_name="$2"
  shift 2

  echo
  echo "==> ENVIRONMENT: $label"
  if [[ -z "${!env_name:-}" ]]; then
    echo "SKIP: $label requires $env_name."
    skips=$((skips + 1))
    return 0
  fi

  if "$@"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label" >&2
    failures=$((failures + 1))
  fi
}

check_source_whitespace() {
  local files=(
    docs/africlub_game_full_implementation_goal_2026-07-02.md
    docs/africlub_game_product_spec.md
    docs/africlub_game_implementation_status_2026-07-02.md
    tools/scripts/africlub_product_boundary_scan.sh
    tools/scripts/scoped_realtime_scan.mjs
    tools/scripts/africlub_game_uat_checklist.sh
    tools/scripts/africlub_game_validation_evidence.sh
    tools/scripts/validate_africlub_mobile_game_controller.sh
    tools/scripts/validate_africlub_game_backend_contract.sh
    tools/scripts/validate_africlub_game_goal.sh
    supabase/migrations/20260702120000_africlub_game_runtime_foundation.sql
    supabase/tests/game_runtime_contract.sql
    supabase/functions/game-session-action/index.ts
    supabase/functions/generate-question-drafts/index.ts
    apps/rayon_sports/web/src/lib/game-runtime.ts
    apps/rayon_sports/web/src/app/tv-display/tv-display-client.tsx
    apps/rayon_sports/web/src/app/admin/games/games-control-client.tsx
    packages/features/feat_gamification/lib/src/fanzone_module.dart
    packages/features/feat_gamification/lib/src/screens/fanzone_hub_screen.dart
    packages/features/feat_gamification/lib/src/screens/game_session_controller_screen.dart
    packages/features/feat_gamification/lib/src/screens/game_session_join_screen.dart
    packages/features/feat_gamification/lib/src/repositories/game_session_repository.dart
    packages/features/feat_gamification/lib/src/models/game_session_models.dart
    packages/features/feat_gamification/lib/src/widgets/fanzone_hub_widgets.dart
  )

  if rg -n "[[:blank:]]$" "${files[@]}"; then
    echo "Trailing whitespace found in game implementation source files." >&2
    return 1
  fi
}

run_required \
  "product-boundary scan" \
  bash tools/scripts/africlub_product_boundary_scan.sh --fail-on-findings

run_required \
  "scoped realtime scan" \
  node tools/scripts/scoped_realtime_scan.mjs

run_required \
  "mobile controller static contract" \
  bash tools/scripts/validate_africlub_mobile_game_controller.sh

run_required \
  "backend static contract" \
  bash tools/scripts/validate_africlub_game_backend_contract.sh

run_required \
  "aggregate game implementation goal" \
  bash tools/scripts/validate_africlub_game_goal.sh

run_required \
  "tracked game implementation whitespace check" \
  git diff --check -- \
    docs/africlub_game_full_implementation_goal_2026-07-02.md \
    docs/africlub_game_product_spec.md \
    docs/africlub_game_implementation_status_2026-07-02.md \
    tools/scripts/africlub_product_boundary_scan.sh \
    tools/scripts/scoped_realtime_scan.mjs \
    tools/scripts/africlub_game_uat_checklist.sh \
    tools/scripts/africlub_game_validation_evidence.sh \
    tools/scripts/validate_africlub_mobile_game_controller.sh \
    tools/scripts/validate_africlub_game_backend_contract.sh \
    tools/scripts/validate_africlub_game_goal.sh \
    supabase/migrations/20260702120000_africlub_game_runtime_foundation.sql \
    supabase/tests/game_runtime_contract.sql \
    supabase/functions/game-session-action/index.ts \
    supabase/functions/generate-question-drafts/index.ts \
    apps/rayon_sports/web/src/lib/game-runtime.ts \
    apps/rayon_sports/web/src/app/tv-display/tv-display-client.tsx \
    apps/rayon_sports/web/src/app/admin/games/games-control-client.tsx \
    packages/features/feat_gamification/lib/src/fanzone_module.dart \
    packages/features/feat_gamification/lib/src/screens/fanzone_hub_screen.dart \
    packages/features/feat_gamification/lib/src/screens/game_session_controller_screen.dart \
    packages/features/feat_gamification/lib/src/screens/game_session_join_screen.dart \
    packages/features/feat_gamification/lib/src/repositories/game_session_repository.dart \
    packages/features/feat_gamification/lib/src/models/game_session_models.dart \
    packages/features/feat_gamification/lib/src/widgets/fanzone_hub_widgets.dart

run_required \
  "game implementation source whitespace check" \
  check_source_whitespace

run_optional_tool \
  "Deno check game-session-action Edge Function" \
  deno \
  deno check supabase/functions/game-session-action/index.ts

run_optional_tool \
  "Deno check generate-question-drafts Edge Function" \
  deno \
  deno check supabase/functions/generate-question-drafts/index.ts

run_optional_tool \
  "Supabase SQL test suite" \
  supabase \
  supabase test

if command -v psql >/dev/null 2>&1; then
  run_optional_env \
    "Postgres game runtime contract" \
    AFRICLUB_GAME_DATABASE_URL \
    psql "$AFRICLUB_GAME_DATABASE_URL" \
      -v ON_ERROR_STOP=1 \
      -f supabase/tests/game_runtime_contract.sql
else
  echo
  echo "==> TOOLCHAIN: Postgres game runtime contract"
  echo "SKIP: Postgres game runtime contract requires psql on PATH."
  skips=$((skips + 1))
fi

echo
echo "==> TOOLCHAIN: Flutter analyzer"
if [[ -z "$FLUTTER_BIN" ]]; then
  echo "SKIP: Flutter analyzer requires flutter on PATH or FLUTTER_BIN."
  skips=$((skips + 1))
elif "$FLUTTER_BIN" analyze; then
  echo "PASS: Flutter analyzer"
else
  echo "FAIL: Flutter analyzer" >&2
  failures=$((failures + 1))
fi

echo
echo "==> TOOLCHAIN: Flutter focused game tests"
if [[ -z "$FLUTTER_BIN" ]]; then
  echo "SKIP: Flutter focused game tests require flutter on PATH or FLUTTER_BIN."
  skips=$((skips + 1))
elif "$FLUTTER_BIN" test \
  packages/features/feat_gamification/test/fanzone_hub_screen_test.dart \
  packages/features/feat_gamification/test/fanzone_module_test.dart; then
  echo "PASS: Flutter focused game tests"
else
  echo "FAIL: Flutter focused game tests" >&2
  failures=$((failures + 1))
fi

echo
echo "AFRICLUB game validation evidence complete: failures=$failures skips=$skips"

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi
