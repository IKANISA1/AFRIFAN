#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
OUT_DIR="$ROOT/output/native_mobile_ux_gate/$STAMP"
REPORT="$OUT_DIR/report.md"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

mkdir -p "$OUT_DIR"
cd "$ROOT"

run_step() {
  local name="$1"
  shift
  local log="$OUT_DIR/${name}.log"

  {
    echo "## $name"
    echo
    echo '```'
    "$@"
    echo '```'
    echo
  } 2>&1 | tee "$log" >>"$REPORT"
}

cat >"$REPORT" <<EOF
# Rayon Sports Native Mobile UX Gate

- Generated: $STAMP
- Root: $ROOT
- Purpose: code-owned native-mobile UX, accessibility, route-state, and static-analysis gate under the single root DESIGN.md authority.

EOF

run_step flutter_version "$FLUTTER_BIN" --version
run_step root_authority bash -c \
  'test -f DESIGN.md && test ! -e docs/design.md && test ! -d docs/design'
run_step scoped_analyze "$FLUTTER_BIN" analyze \
  apps/rayon_sports \
  packages/core/core_app \
  packages/core/core_router \
  packages/core/core_theme \
  packages/core/core_network \
  packages/core/core_auth \
  packages/core/core_feature_config \
  packages/features/feat_home \
  packages/features/feat_onboarding \
  packages/features/feat_membership \
  packages/features/feat_settings \
  packages/features/feat_ticketing \
  packages/features/feat_gamification
run_step core_app_and_theme_tests "$FLUTTER_BIN" test \
  packages/core/core_app/test/app_routing_guard_test.dart \
  packages/core/core_theme/test
run_step shell_navigation_tests "$FLUTTER_BIN" test \
  packages/app_registry/test \
  packages/core/core_app/test \
  apps/rayon_sports/test/rayon_sports_shell_navigation_test.dart
run_step screen_state_and_ui_tests "$FLUTTER_BIN" test \
  packages/features/feat_home/test/home_screen_states_test.dart \
  packages/features/feat_onboarding/test/onboarding_flow_test.dart \
  packages/features/feat_gamification/test/fanzone_hub_screen_test.dart \
  packages/features/feat_membership/test/membership_screen_ui_test.dart \
  packages/features/feat_settings/test/settings_screens_test.dart \
  packages/features/feat_ticketing/test/match_list_ui_test.dart

cat >>"$REPORT" <<EOF
## External Evidence Still Required

This gate is intentionally limited to local repository checks. Before calling a
release maximum-native-mobile complete, attach fresh profile/release evidence
from physical or representative simulator devices:

- iOS and Android startup, scroll, navigation, animation, and memory traces.
- VoiceOver and TalkBack walkthrough evidence at 100%, 200%, and largest text.
- Store permission/privacy evidence for the current release build.
- Route-state and accessibility evidence reviewed against DESIGN.md when intentional.

EOF

echo "Native mobile UX gate passed."
echo "Report: $REPORT"
