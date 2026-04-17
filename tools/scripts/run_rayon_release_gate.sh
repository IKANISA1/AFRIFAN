#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$ROOT"

echo "==> Validate release contract"
bash tools/scripts/validate_club_release.sh rayon_sports

echo "==> Flutter analyze"
flutter analyze \
  packages/core/core_auth \
  packages/core/core_app \
  packages/core/core_network \
  packages/features/feat_onboarding \
  apps/rayon_sports

echo "==> Flutter smoke checks"
flutter test packages/features/feat_onboarding/test/onboarding_flow_test.dart
flutter test apps/rayon_sports/integration_test/release_readiness_smoke_test.dart

echo "==> Web typecheck, tests, build, audit"
(
  cd apps/rayon_sports/web
  npm run typecheck
  npm test
  npm run build
  npm audit --audit-level=high
)

echo "Rayon Sports release gate passed."
