#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FLUTTER_BIN="${FLUTTER_BIN:-/Volumes/PRO-G40/flutter_3_44/bin/flutter}"
if [[ ! -x "$FLUTTER_BIN" ]]; then
  FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
fi

failures=0

run_required() {
  local label="$1"
  shift

  echo
  echo "==> $label"
  if "$@"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label" >&2
    failures=$((failures + 1))
  fi
}

check_required_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "missing required alignment file: $file" >&2
    return 1
  fi
}

check_matrix_contract() {
  local matrix="docs/design/MOBI_REVOLUT_100_PERCENT_ALIGNMENT_MATRIX.md"

  check_required_file "DESIGN.md"
  check_required_file "docs/design.md"
  check_required_file "docs/design/DESIGN_SYSTEM.md"
  check_required_file "$matrix"
  check_required_file "docs/screen_inventory.md"
  check_required_file "docs/rayon_mobile_visual_evidence_manifest_2026-07-01.md"
  check_required_file "docs/rayon_mobile_large_width_shell_decision_2026-07-01.md"
  check_required_file "docs/rayon_mobile_deferred_route_classification_2026-07-01.md"

  for number in $(seq -w 1 18); do
    local row="UX-${number}"
    if ! rg -q "\\| ${row} \\|" "$matrix"; then
      echo "alignment matrix missing row: $row" >&2
      return 1
    fi
  done

  for phase in "Phase 0" "Phase 1" "Phase 2" "Phase 3" "Phase 4" "Phase 5"; do
    if ! rg -q "\\| ${phase} \\|" "$matrix"; then
      echo "alignment matrix missing phase: $phase" >&2
      return 1
    fi
  done

  required_patterns=(
    "AfriTopCommandBar"
    "AfriClubBottomNav"
    "AfriAsyncStateView"
    "AfriStateBanner"
    "AfriActionSheet"
    "afriRoutePage"
    "afriSheetPage"
    "Product-boundary scan"
    "rayon_mobile_visual_coverage_contract_test.dart"
    "rayon_mobile_native_ux_gate.sh"
  )

  for pattern in "${required_patterns[@]}"; do
    if ! rg -q "$pattern" "$matrix" docs/design/DESIGN_SYSTEM.md; then
      echo "active design contract missing required pattern: $pattern" >&2
      return 1
    fi
  done
}

check_deleted_design_docs_stay_deleted() {
  local deleted_docs=(
    docs/design_mandate.md
    docs/revolut_borrowed_ui_goal_2026-06-27.md
    docs/revolut_borrowed_repo_cleanup_goal_2026-06-28.md
    docs/rayon_sports_mobile_audit_2026-06-28.md
    docs/rayon_sports_mobile_readiness_goal_2026-06-28.md
    docs/rayon_sports_flutter_screen_cleanup_inventory_2026-06-28.md
    docs/rayon_sports_fullstack_ui_ux_review_2026-06-29.md
    docs/africlub_native_mobile_ux_audit_2026-06-29.md
    docs/africlub_native_mobile_ux_implementation_2026-06-29.md
    docs/protected_surface_triage_2026-06-28.md
  )

  for file in "${deleted_docs[@]}"; do
    if [[ -e "$file" ]]; then
      echo "superseded design doc still exists: $file" >&2
      return 1
    fi
  done

  local stale_refs
  stale_refs="$(
    rg -n \
      "docs/(design_mandate|revolut_borrowed_ui_goal_2026-06-27|revolut_borrowed_repo_cleanup_goal_2026-06-28|rayon_sports_mobile_audit_2026-06-28|rayon_sports_mobile_readiness_goal_2026-06-28|rayon_sports_flutter_screen_cleanup_inventory_2026-06-28|rayon_sports_fullstack_ui_ux_review_2026-06-29|africlub_native_mobile_ux_audit_2026-06-29|africlub_native_mobile_ux_implementation_2026-06-29|protected_surface_triage_2026-06-28)" \
      . \
      --glob '*.md' \
      --glob '*.dart' \
      --glob '*.sh' \
      --glob '*.json' \
      --glob '*.yaml' \
      --glob '*.yml' \
      | rg -v '^./docs/design/MOBI_REVOLUT_100_PERCENT_ALIGNMENT_MATRIX.md:' \
      | rg -v '^./tools/scripts/validate_mobi_revolut_alignment_matrix.sh:' || true
  )"

  if [[ -n "$stale_refs" ]]; then
    echo "$stale_refs" >&2
    echo "stale references to superseded design docs remain outside the deletion log" >&2
    return 1
  fi
}

check_shared_primitives_exist() {
  local required_sources=(
    packages/core/core_theme/lib/src/widgets/afri_top_command_bar.dart
    packages/core/core_theme/lib/src/widgets/africlub_bottom_nav.dart
    packages/core/core_theme/lib/src/widgets/afri_async_state_view.dart
    packages/core/core_theme/lib/src/widgets/afri_state_view.dart
    packages/core/core_theme/lib/src/widgets/afri_state_banner.dart
    packages/core/core_theme/lib/src/widgets/afri_action_sheet.dart
    packages/core/core_theme/lib/src/widgets/afri_dialog.dart
    packages/core/core_theme/lib/src/widgets/afri_input_field.dart
    packages/core/core_theme/lib/src/widgets/afri_screen_scaffold.dart
    packages/core/core_router/lib/src/route_transitions.dart
    packages/core/core_app/lib/src/shell.dart
  )

  for file in "${required_sources[@]}"; do
    check_required_file "$file"
  done

  rg -q "class AfriTopCommandBar" packages/core/core_theme/lib/src/widgets/afri_top_command_bar.dart
  rg -q "class AfriClubBottomNav" packages/core/core_theme/lib/src/widgets/africlub_bottom_nav.dart
  rg -q "class AfriAsyncStateView" packages/core/core_theme/lib/src/widgets/afri_async_state_view.dart
  rg -q "class AfriStateBanner" packages/core/core_theme/lib/src/widgets/afri_state_banner.dart
  rg -q "Page<T> afriRoutePage" packages/core/core_router/lib/src/route_transitions.dart
  rg -q "Page<T> afriSheetPage" packages/core/core_router/lib/src/route_transitions.dart
  rg -q "AfriClubBottomNav" packages/core/core_app/lib/src/shell.dart
}

check_admin_boundary_sources() {
  rg -q "mobile admin is excluded from default supporter route graph" \
    packages/app_registry/test/navigation_journeys_test.dart
  rg -q "Admin Screen" packages/core/core_app/test/rayon_mobile_visual_coverage_contract_test.dart
  rg -q "mobile admin is not registered unless explicitly opted in" \
    packages/app_registry/test/module_registry_test.dart
}

run_required "matrix contract files and rows" check_matrix_contract
run_required "superseded design docs remain deleted" check_deleted_design_docs_stay_deleted
run_required "shared MOBI/Revolut primitives exist" check_shared_primitives_exist
run_required "admin boundary evidence sources exist" check_admin_boundary_sources
run_required "design drift scan" bash tools/scripts/rayon_mobile_design_drift_report.sh --fail-on-findings
run_required "product-boundary scan" bash tools/scripts/africlub_product_boundary_scan.sh --fail-on-findings
run_required "matrix docs whitespace" git diff --check -- \
  DESIGN.md \
  docs/design.md \
  docs/design/DESIGN_SYSTEM.md \
  docs/design/MOBI_REVOLUT_100_PERCENT_ALIGNMENT_MATRIX.md \
  docs/screen_inventory.md \
  packages/core/core_theme/README.md \
  README.md
run_required "visual coverage contract test" "$FLUTTER_BIN" test --no-pub \
  packages/core/core_app/test/rayon_mobile_visual_coverage_contract_test.dart
run_required "supporter shell navigation test" "$FLUTTER_BIN" test --no-pub \
  apps/rayon_sports/test/rayon_sports_shell_navigation_test.dart
run_required "app registry navigation journey test" "$FLUTTER_BIN" test --no-pub \
  packages/app_registry/test/navigation_journeys_test.dart
run_required "core theme design source guardrail test" "$FLUTTER_BIN" test --no-pub \
  packages/core/core_theme/test/design_system_source_of_truth_test.dart

echo
echo "MOBI/Revolut alignment matrix validation complete: failures=$failures"

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi
