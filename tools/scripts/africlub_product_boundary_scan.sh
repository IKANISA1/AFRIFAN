#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FAIL_ON_FINDINGS=false
if [[ "${1:-}" == "--fail-on-findings" ]]; then
  FAIL_ON_FINDINGS=true
fi

echo "AFRICLUB product-boundary scan"

FORBIDDEN_PATTERN='(\bbetting\b|\bgambling\b|\bwager\b|\bwagering\b|\bodds\b|cash[- ]?out|cash prize|cash prizes|\bjackpot\b|paid prediction|paid predictions|pooled prize|pooled prizes|\bstake\b|\bstaking\b|\bpayout\b|\bwinnings\b|\bbookmaker\b|\bmarket slip\b)'
WALLET_PATTERN='(customer wallet|supporter wallet|wallet transfer|wallet balance|wallet operations|open wallet|manual redemption|cash-out|recipient fan id)'
FANZONE_LEGACY_COPY_PATTERN='(FET earned|Partner FET|Wallet redemption|Earn FET|FET balance|FET pool|JOIN FOR|LOCK [^[:cntrl:]]*FET|Payout / winner|Won [^[:cntrl:]]*FET|Refunded [^[:cntrl:]]*FET|Your current FET balance|added to your slip|prediction for|Add prediction|Selected prediction|Prediction slip|PREDICTION SLIP|Lock In Predictions|CONFIRM PREDICTIONS|\+[^[:cntrl:]]* FET|[0-9][0-9,]* FET|\} FET|Transfer tokens|personal wallet|market slip)'

SCAN_TARGETS=(
  "apps/rayon_sports/web/src/app"
  "apps/rayon_sports/web/src/components"
  "apps/rayon_sports/web/src/lib/data/admin"
  "packages/features/feat_gamification/assets"
  "packages/features/feat_gamification/lib/src/screens"
  "packages/features/feat_gamification/lib/src/widgets"
  "packages/core/core_app"
  "packages/core/core_feature_config"
  "supabase/functions"
)

RG_ARGS=(
  --glob '!**/node_modules/**'
  --glob '!**/.next/**'
  --glob '!**/build/**'
  --glob '!**/.dart_tool/**'
  --glob '!**/coverage/**'
  --glob '!**/*.test.ts'
  --glob '!**/*_test.dart'
  --glob '!**/test/**'
  --glob '!**/models/**'
  --glob '!**/repositories/**'
  --glob '!**/providers/**'
  --glob '!**/controllers/**'
  --glob '!**/generate-multipliers/**'
)

findings=0

filter_product_boundary_findings() {
  rg -n -i "$1" "${SCAN_TARGETS[@]}" "${RG_ARGS[@]}" \
    | rg -v "^\S+:[0-9]+:[[:space:]]*(///|//|import |class |enum |typedef |extension |mixin |factory |const [A-Z_]|final [A-Za-z_]|State<|ConsumerState<|String _submissionKey|Future<|return 'jackpot-|return \"jackpot-|case 'partner_pool_payout'|case \"partner_pool_payout\")" \
    | rg -v "(_stake|stakeFet|stake:|stake\\)|stake,|detail\\.odds|outcome\\.odds|partnerStakeFet|payoutPerWinnerFet|payoutFet)" \
    | rg -v "(Do not use betting|No multipliers or dynamic odds are used|Operation failed \(non-critical\))"
}

if filter_product_boundary_findings "${FORBIDDEN_PATTERN}"; then
  findings=1
  echo
  echo "Found betting/odds/stake/payout-style language in active runtime surfaces." >&2
fi

if filter_product_boundary_findings "${WALLET_PATTERN}"; then
  findings=1
  echo
  echo "Found customer-wallet positioning in active runtime surfaces." >&2
fi

if filter_product_boundary_findings "${FANZONE_LEGACY_COPY_PATTERN}"; then
  findings=1
  echo
  echo "Found Fan Zone legacy token/prediction/slip copy in active runtime surfaces." >&2
fi

if [[ "$findings" -eq 0 ]]; then
  echo "Product-boundary scan passed."
  exit 0
fi

if [[ "$FAIL_ON_FINDINGS" == true ]]; then
  echo "Product-boundary scan failed." >&2
  exit 1
fi

echo "Product-boundary scan found issues; rerun with --fail-on-findings to enforce."
