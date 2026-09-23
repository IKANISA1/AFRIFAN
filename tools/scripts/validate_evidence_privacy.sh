#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-$ROOT/output/evidence}"
GOLDEN_DIR="${GOLDEN_DIR:-$ROOT/packages}"
GOLDEN_MANIFEST="${GOLDEN_MANIFEST:-$ROOT/docs/governance/golden-baselines.json}"
REPORT="${REPORT:-$EVIDENCE_ROOT/evidence-privacy-validation.json}"

test -d "$EVIDENCE_ROOT"
test -d "$GOLDEN_DIR"
test -f "$GOLDEN_MANIFEST"

jq -e '
  (.provenance.data_source == "synthetic_non_production") and
  (.privacy.data_classification == "synthetic_non_production") and
  (.privacy.automated_scan == "tools/scripts/validate_evidence_privacy.sh") and
  (.privacy.human_review_status == "pending" or
   .privacy.human_review_status == "approved") and
  all(.baselines[]; .data_source == "synthetic")
' "$GOLDEN_MANIFEST" >/dev/null

patterns=(
  '(^|[^0-9])((\+250|00250)[[:space:]-]?7[0-9]|07[0-9])[[:space:]-]?[0-9]{3}[[:space:]-]?[0-9]{4}([^0-9]|$)'
  'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
  '(^|[^A-Za-z0-9])(sb_secret_|sk_live_|rk_live_|AKIA)[A-Za-z0-9_-]{8,}'
  '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
  'Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{12,}'
  '(service_role|service-role)[^[:cntrl:]]{0,40}(eyJ|sb_secret_)'
  '(otp|one[- ]time[[:space:]]+pass(code|word))[^[:cntrl:]]{0,20}[0-9]{4,8}'
)

scan_failed=false
pattern_args=()
for pattern in "${patterns[@]}"; do
  pattern_args+=("-e" "$pattern")
  text_matches="$(
    rg -n -i -e "$pattern" \
      "$EVIDENCE_ROOT" \
      "$GOLDEN_MANIFEST" \
      -g '*.md' \
      -g '*.json' \
      -g '*.txt' \
      -g '*.csv' \
      -g '*.log' \
      -g '!evidence-privacy-validation.json' |
      rg -v '"sha256"[[:space:]]*:' || true
  )"
  if [ -n "$text_matches" ]; then
    printf 'Evidence privacy violation for pattern %s:\n%s\n' \
      "$pattern" "$text_matches" >&2
    scan_failed=true
  fi
done

while IFS= read -r relative_image_path; do
  [ -n "$relative_image_path" ] || continue
  image_path="$ROOT/$relative_image_path"
  test -f "$image_path"
  binary_match="$(
    strings "$image_path" | rg -n -i "${pattern_args[@]}" || true
  )"
  if [ -n "$binary_match" ]; then
    printf 'Golden privacy violation in %s for governed privacy patterns\n' \
      "$image_path" >&2
    scan_failed=true
  fi
done < <(jq -r '.baselines[].path' "$GOLDEN_MANIFEST" | sort -u)

if [ "$scan_failed" = true ]; then
  exit 1
fi

generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -n \
  --arg generated_at "$generated_at" \
  --arg evidence_root "$EVIDENCE_ROOT" \
  --arg golden_dir "$GOLDEN_DIR" \
  --arg manifest "$GOLDEN_MANIFEST" \
  --argjson pattern_count "${#patterns[@]}" \
  --argjson baseline_count "$(jq '.baselines | length' "$GOLDEN_MANIFEST")" \
  '{
    schema_version: "1.0",
    generated_at: $generated_at,
    status: "pass",
    automated_scope: {
      evidence_root: $evidence_root,
      golden_directory: $golden_dir,
      golden_manifest: $manifest,
      pattern_count: $pattern_count,
      baseline_count: $baseline_count
    },
    human_review_status: "pending",
    completion_claim: false
  }' >"$REPORT"

printf 'Evidence privacy scan passed: %s\n' "$REPORT"
