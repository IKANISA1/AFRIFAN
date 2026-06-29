#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/docs/africlub_gamification_product_rules.md"
MIGRATION="$ROOT/supabase/migrations/20260629120000_partner_centered_wdw_prediction_pools.sql"
MULTIPLIER_FN="$ROOT/supabase/functions/generate-multipliers/index.ts"

required_files=(
  "$DOC"
  "$MIGRATION"
  "$MULTIPLIER_FN"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "missing required file: ${file#$ROOT/}" >&2
    exit 1
  fi
done

required_doc_patterns=(
  "partner-centered eligibility"
  "Home win"
  "Draw"
  "Away win"
  "No dynamic odds, multipliers, overround, house edge"
  "Public fan transfer is disabled for launch"
)

for pattern in "${required_doc_patterns[@]}"; do
  if ! rg -q "$pattern" "$DOC"; then
    echo "product rules missing pattern: $pattern" >&2
    exit 1
  fi
done

required_migration_patterns=(
  "partner_fet_initiatives"
  "partner_fet_earn_events"
  "partner_prediction_pools"
  "partner_prediction_pool_entries"
  "partner_prediction_pool_settlements"
  "prediction_kind = 'wdw'"
  "home_win"
  "draw"
  "away_win"
  "partner_prediction_pool_create"
  "partner_prediction_pool_join"
  "partner_prediction_pool_settle"
  "partner_promotion_earn"
  "partner_pool_entry"
  "partner_pool_payout"
  "partner_pool_refund"
  "revoke execute on function public.fet_transfer"
  "revoke execute on function public.fet_redeem"
)

for pattern in "${required_migration_patterns[@]}"; do
  if ! rg -q "$pattern" "$MIGRATION"; then
    echo "migration missing pattern: $pattern" >&2
    exit 1
  fi
done

if ! rg -q "AFRICLUB_ENABLE_LEGACY_MULTIPLIERS" "$MULTIPLIER_FN"; then
  echo "legacy multiplier function is not guarded by AFRICLUB_ENABLE_LEGACY_MULTIPLIERS" >&2
  exit 1
fi

if ! rg -q "partner_centered_wdw_pools" "$MULTIPLIER_FN"; then
  echo "legacy multiplier function does not report partner-centered WDW replacement model" >&2
  exit 1
fi

echo "Partner gamification contract validation passed."
