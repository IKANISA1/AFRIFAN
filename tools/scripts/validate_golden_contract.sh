#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT/docs/governance/golden-baselines.json"
REVIEW="$ROOT/docs/governance/golden-review.md"
TEST="$ROOT/packages/features/feat_settings/test/settings_goldens_test.dart"
CONTRAST_TEST="$ROOT/packages/core/core_theme/test/contrast_evidence_golden_test.dart"

test -f "$MANIFEST"
test -f "$REVIEW"
test -f "$TEST"
test -f "$CONTRAST_TEST"

jq -e '
  (.schema_version | type == "string") and
  (.provenance.baseline_commit | test("^[0-9a-f]{40}$")) and
  (.provenance.dirty_state | type == "boolean") and
  (.provenance.app_version | type == "string" and length > 0) and
  (.provenance.build_number | type == "string" and length > 0) and
  (.provenance.flavor | type == "string" and length > 0) and
  (.provenance.platform | type == "string" and length > 0) and
  (.provenance.runtime | type == "string" and length > 0) and
  (.provenance.locale | type == "string" and length > 0) and
  (.provenance.generated_at | fromdateiso8601 | type == "number") and
  (.provenance.data_source == "synthetic_non_production") and
  (.comparison.metric == "differing_pixels") and
  (.comparison.maximum_rate == 0) and
  (.privacy.data_classification == "synthetic_non_production") and
  (.privacy.automated_scan == "tools/scripts/validate_evidence_privacy.sh") and
  (.privacy.human_review_status == "pending" or
   .privacy.human_review_status == "approved") and
  (.review_policy == "docs/governance/golden-review.md") and
  (.baselines | type == "array" and length >= 2) and
  all(
    .baselines[];
    (.id | type == "string" and length > 0) and
    (.path | type == "string" and endswith(".png")) and
    (.viewport.width > 0) and
    (.viewport.height > 0) and
    (.viewport.device_pixel_ratio == 1) and
    (.theme == "dark" or .theme == "light" or .theme == "high_contrast") and
    (.data_source == "synthetic") and
    (.sha256 | test("^[0-9a-f]{64}$"))
  )
' "$MANIFEST" >/dev/null

jq -e '
  any(
    .baselines[];
    .id == "home-high-contrast-dark-390x844" and
    .theme == "high_contrast"
  ) and
  any(
    .baselines[];
    .id == "settings-standard-light-390x844" and
    .theme == "light"
  ) and
  any(
    .baselines[];
    .id == "settings-high-contrast-light-390x844" and
    .theme == "high_contrast"
  ) and
  any(
    .baselines[];
    .id == "contrast-evidence-dark-430x900" and
    .theme == "dark"
  ) and
  any(
    .baselines[];
    .id == "contrast-evidence-light-430x900" and
    .theme == "light"
  )
' "$MANIFEST" >/dev/null

standard_settings_sha="$(
  jq -r '
    .baselines[]
    | select(.id == "settings-standard-light-390x844")
    | .sha256
  ' "$MANIFEST"
)"
high_contrast_settings_sha="$(
  jq -r '
    .baselines[]
    | select(.id == "settings-high-contrast-light-390x844")
    | .sha256
  ' "$MANIFEST"
)"
if [ "$standard_settings_sha" = "$high_contrast_settings_sha" ]; then
  printf 'High-contrast Settings baseline must differ from standard light.\n' >&2
  exit 1
fi

python3 "$ROOT/tools/scripts/golden_test_references.py" \
  --root "$ROOT" --manifest "$MANIFEST"

while IFS=$'\t' read -r relative_path expected_sha width height theme; do
  absolute_path="$ROOT/$relative_path"
  test -f "$absolute_path"
  test_root="$(dirname "$absolute_path")"
  while [ "$(basename "$test_root")" != "test" ] &&
    [ "$test_root" != "$ROOT" ]; do
    test_root="$(dirname "$test_root")"
  done
  if [ "$(basename "$test_root")" != "test" ]; then
    printf 'Golden is not nested under a test directory: %s\n' "$relative_path" >&2
    exit 1
  fi
  actual_sha="$(shasum -a 256 "$absolute_path" | awk '{print $1}')"
  if [ "$actual_sha" != "$expected_sha" ]; then
    printf 'Golden digest mismatch: %s\n' "$relative_path" >&2
    exit 1
  fi
done < <(
  jq -r '
    .baselines[]
    | [.path, .sha256, .viewport.width, .viewport.height, .theme]
    | @tsv
  ' "$MANIFEST"
)

rg -q 'matchesGoldenFile' "$TEST"
rg -q 'matchesGoldenFile' "$CONTRAST_TEST"
rg -q -- '--update-goldens' "$REVIEW"

printf 'Golden contract valid: %s\n' "$MANIFEST"
