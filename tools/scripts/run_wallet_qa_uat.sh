#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPLY_LINKED=0
SKIP_SEED=0
SKIP_E2E=0

usage() {
  cat <<'EOF'
Usage:
  tools/scripts/run_wallet_qa_uat.sh [--apply-linked] [--skip-seed] [--skip-e2e]

Flags:
  --apply-linked  Apply pending linked Supabase migrations before seeding and browser UAT.
  --skip-seed     Skip the wallet persona seed step.
  --skip-e2e      Skip the wallet Playwright browser pass.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply-linked)
      APPLY_LINKED=1
      shift
      ;;
    --skip-seed)
      SKIP_SEED=1
      shift
      ;;
    --skip-e2e)
      SKIP_E2E=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

cd "$ROOT"

echo "==> Supabase linked migration state"
supabase migration list

if [ "$APPLY_LINKED" -eq 1 ]; then
  if [ -z "${SUPABASE_DB_PASSWORD:-}" ]; then
    echo "SUPABASE_DB_PASSWORD is required when --apply-linked is set." >&2
    exit 2
  fi
  echo "==> Applying linked Supabase migrations"
  supabase db push --linked --include-all --password "$SUPABASE_DB_PASSWORD" --yes
fi

echo "==> Flutter analyze"
flutter analyze \
  packages/features/feat_gamification \
  packages/features/feat_onboarding \
  packages/features/feat_settings

echo "==> Flutter wallet and auth regression tests"
flutter test packages/features/feat_gamification/test
flutter test packages/features/feat_onboarding/test
flutter test packages/features/feat_settings/test

echo "==> Web lint, typecheck, unit tests, build"
(
  cd apps/rayon_sports/web
  corepack npm run lint
  corepack npm run typecheck
  corepack npm test
  corepack npm run build
)

if [ "$SKIP_SEED" -eq 0 ]; then
  echo "==> Seeding wallet QA personas"
  (
    cd apps/rayon_sports/web
    corepack npm run qa:wallet:seed
  )
fi

if [ "$SKIP_E2E" -eq 0 ]; then
  echo "==> Wallet browser UAT"
  (
    cd apps/rayon_sports/web
    corepack npm run test:e2e:wallet
  )
fi

echo "Wallet QA/UAT runner completed."
