#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DESIGN="${SOURCE_DESIGN:-/Volumes/PRO-G40/DESIGN/DESIGN.md}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUT_DIR:-$ROOT/output/design_compliance/$STAMP}"
REPORT="$OUT_DIR/report.md"
VALIDATION="$OUT_DIR/VALIDATION.json"
MATRIX="$OUT_DIR/route_evidence_matrix.md"
VIOLATIONS="$OUT_DIR/violations.txt"
WARNINGS="$OUT_DIR/warnings.txt"
EXCEPTIONS_REGISTER="${EXCEPTIONS_REGISTER:-$ROOT/docs/governance/design-exceptions.json}"
ROUTE_INVENTORY_JSON="${ROUTE_INVENTORY_JSON:-$ROOT/output/implementation_goal_20260724/route_inventory_current/route-inventory.json}"
ROUTE_STATE_CLOSURE_JSON="${ROUTE_STATE_CLOSURE_JSON:-$(dirname "$ROUTE_INVENTORY_JSON")/route-state-closure.json}"
SCREEN_ARCHETYPE_COVERAGE_JSON="${SCREEN_ARCHETYPE_COVERAGE_JSON:-$(dirname "$ROUTE_INVENTORY_JSON")/screen-archetype-coverage.json}"
COMPONENT_INVENTORY_JSON="${COMPONENT_INVENTORY_JSON:-$ROOT/output/implementation_goal_20260724/component_inventory_current/universal-component-inventory.json}"
GOLDEN_BASELINES_JSON="${GOLDEN_BASELINES_JSON:-$ROOT/docs/governance/golden-baselines.json}"

mkdir -p "$OUT_DIR"
: >"$VIOLATIONS"
: >"$WARNINGS"

cd "$ROOT"

record_violation() {
  local label="$1"
  local content="$2"
  if [ -n "$content" ]; then
    {
      printf '## %s\n' "$label"
      printf '%s\n\n' "$content"
    } >>"$VIOLATIONS"
  fi
}

record_warning() {
  local label="$1"
  local content="$2"
  if [ -n "$content" ]; then
    {
      printf '## %s\n' "$label"
      printf '%s\n\n' "$content"
    } >>"$WARNINGS"
  fi
}

checksum_status="fail"
repo_design_sha=""
source_design_sha=""
if [ -f "$ROOT/DESIGN.md" ] && [ -f "$SOURCE_DESIGN" ]; then
  repo_design_sha="$(shasum -a 256 "$ROOT/DESIGN.md" | awk '{print $1}')"
  source_design_sha="$(shasum -a 256 "$SOURCE_DESIGN" | awk '{print $1}')"
  if [ "$repo_design_sha" = "$source_design_sha" ]; then
    checksum_status="pass"
  fi
fi

if [ "$checksum_status" != "pass" ]; then
  record_violation "DESIGN.md checksum" \
    "Root DESIGN.md does not match $SOURCE_DESIGN."
fi

exceptions_status="fail"
if [ -f "$EXCEPTIONS_REGISTER" ] &&
  jq -e '
    (.schema_version | type == "string") and
    (.design_authority.sha256 | type == "string" and length > 0) and
    (.exceptions | type == "array") and
    all(
      .exceptions[];
      (.id | type == "string" and length > 0) and
      (.status | type == "string" and length > 0) and
      (.surface | type == "string" and length > 0) and
      (.exact_route_or_component | type == "string" and length > 0) and
      (.varied_rule | type == "string" and length > 0) and
      (.reason | type == "string" and length > 0) and
      (.approved_alternative | type == "string" and length > 0) and
      (.risk | type == "string" and length > 0) and
      (.evidence | type == "array" and length > 0) and
      (.owner | type == "string" and length > 0) and
      (.approval.status | type == "string" and length > 0) and
      (.expiry_or_review_date | type == "string" and length > 0) and
      (
        if .approval.status == "approved" then
          (.approval.approved_by | type == "string" and length > 0) and
          (.approval.approved_at | type == "string" and length > 0)
        else
          true
        end
      )
    )
  ' "$EXCEPTIONS_REGISTER" >/dev/null; then
  exceptions_status="pass"
fi

if [ "$exceptions_status" != "pass" ]; then
  record_violation "Design Exceptions Register" \
    "Missing or invalid machine-readable exception register: $EXCEPTIONS_REGISTER"
else
  pending_exceptions="$(
    jq -r '
      .exceptions[]
      | select(.approval.status != "approved")
      | "\(.id): \(.approval.status) — owner \(.owner)"
    ' "$EXCEPTIONS_REGISTER"
  )"
  record_warning "Pending design-exception approvals" "$pending_exceptions"
fi

route_inventory_status="fail"
if [ -f "$ROUTE_INVENTORY_JSON" ] &&
  jq -e '
    . as $root |
    (.schema_version | type == "string") and
    (.route_count | type == "number" and . > 0) and
    (.duplicate_keys | type == "array" and length == 0) and
    (.routes | type == "array" and length == $root.route_count) and
    any(.routes[]; .surface == "mobile" and .path == "/home") and
    any(.routes[]; .surface == "mobile" and .path == "/search") and
    any(.routes[]; .surface == "native_tv") and
    any(.routes[]; .surface == "admin_pwa") and
    any(.routes[]; .surface == "venue_portal")
  ' "$ROUTE_INVENTORY_JSON" >/dev/null; then
  route_inventory_status="pass"
fi
if [ "$route_inventory_status" != "pass" ]; then
  record_violation "Generated route inventory" \
    "Missing, invalid, incomplete, or duplicate route inventory: $ROUTE_INVENTORY_JSON"
fi

route_state_closure_status="fail"
inventory_route_count="0"
if [ "$route_inventory_status" = "pass" ]; then
  inventory_route_count="$(jq -r '.route_count' "$ROUTE_INVENTORY_JSON")"
fi
if [ -f "$ROUTE_STATE_CLOSURE_JSON" ] &&
  jq -e --argjson inventory_route_count "$inventory_route_count" '
    . as $root |
    (.schema_version == "1.1") and
    (.evidence_source | type == "string" and length > 0) and
    (.route_count == $inventory_route_count) and
    (.state_count == 16) and
    (.cell_count == (.route_count * .state_count)) and
    (.applicable_cell_count + .not_applicable_cell_count == .cell_count) and
    (.evidenced_cell_count + .open_cell_count == .applicable_cell_count) and
    (.test_evidenced_cell_count >= .evidenced_cell_count) and
    (.visual_evidenced_cell_count >= .evidenced_cell_count) and
    (
      .closure_complete ==
      (.open_cell_count == 0 and .evidenced_cell_count == .applicable_cell_count)
    ) and
    (.routes | type == "array" and length == $root.route_count) and
    all(
      .routes[];
      (.route_key | type == "string" and length > 0) and
      (.closure_status == "evidence_complete" or
       .closure_status == "evidence_open") and
      (
        .closure_status ==
        (if any(.states[]; .evidence_status == "open") then
           "evidence_open"
         else
           "evidence_complete"
         end)
      ) and
      (.states | type == "object" and length == $root.state_count) and
      all(
        .states[];
        (.applicability == "applicable" or .applicability == "not_applicable") and
        (.evidence_status == "open" or
         .evidence_status == "evidenced" or
         .evidence_status == "not_applicable") and
        (
          if .applicability == "not_applicable" then
            .evidence_status == "not_applicable"
          else
            (.evidence_status == "open" or .evidence_status == "evidenced")
          end
        ) and
        (.rationale | type == "string" and length > 0) and
        (.test_evidence | type == "array") and
        (.screenshot_evidence | type == "array") and
        (.accessibility_evidence | type == "array") and
        (.performance_evidence | type == "array") and
        (.privacy_evidence | type == "array") and
        (.platform_build_evidence | type == "array") and
        (
          if .evidence_status == "evidenced" then
            (.test_evidence | length > 0) and
            (.screenshot_evidence | length > 0) and
            (.owner | type == "string" and length > 0) and
            (.reviewed_at | type == "string" and length > 0)
          else
            true
          end
        )
      )
    )
  ' "$ROUTE_STATE_CLOSURE_JSON" >/dev/null; then
  route_state_closure_status="pass"
fi
if [ "$route_state_closure_status" != "pass" ]; then
  record_violation "Route-by-state closure matrix" \
    "Missing or invalid route-state closure matrix: $ROUTE_STATE_CLOSURE_JSON"
else
  open_route_state_cells="$(
    jq -r '.open_cell_count' "$ROUTE_STATE_CLOSURE_JSON"
  )"
  if [ "$open_route_state_cells" != "0" ]; then
    record_warning "Open route-state evidence" \
      "$open_route_state_cells applicable route-state cells still require linked current proof."
  fi
fi

screen_archetype_coverage_status="fail"
if [ -f "$SCREEN_ARCHETYPE_COVERAGE_JSON" ] &&
  jq -e '
    . as $root |
    (.schema_version | type == "string") and
    (.archetype_count == 13) and
    (.required_archetypes | type == "array" and length == $root.archetype_count) and
    (.archetypes | type == "array" and length == $root.archetype_count) and
    (.mapped_archetype_count == $root.archetype_count) and
    (.unmapped_archetype_count == 0) and
    (.ownerless_archetype_count == 0) and
    (.closure_complete == true) and
    all(
      .archetypes[];
      . as $entry |
      (.applicability == "applicable") and
      (.status == "mapped") and
      (.owner | type == "string" and length > 0) and
      (.route_count > 0) and
      (.route_keys | type == "array" and length == $entry.route_count) and
      (.test_evidence | type == "array") and
      (.screenshot_evidence | type == "array")
    )
  ' "$SCREEN_ARCHETYPE_COVERAGE_JSON" >/dev/null; then
  screen_archetype_coverage_status="pass"
fi
if [ "$screen_archetype_coverage_status" != "pass" ]; then
  record_violation "Required screen-archetype coverage" \
    "Missing, unmapped, ownerless, or invalid required archetype coverage: $SCREEN_ARCHETYPE_COVERAGE_JSON"
fi

component_inventory_status="fail"
if [ -f "$COMPONENT_INVENTORY_JSON" ] &&
  jq -e '
    . as $root |
    (.schema_version | type == "string") and
    (.component_count == 71) and
    (.state_count == 14) and
    (.state_cell_count == (.component_count * .state_count)) and
    (.components | type == "array" and length == $root.component_count) and
    (.status_counts.implemented + .status_counts.partial + .status_counts.missing
      == .component_count) and
    all(
      .components[];
      (.component_key | type == "string" and length > 0) and
      (.implementation_status == "implemented" or
       .implementation_status == "partial" or
       .implementation_status == "missing") and
      (.source_paths | type == "array") and
      (.candidate_test_paths | type == "array") and
      (.states | type == "object" and length == $root.state_count) and
      all(
        .states[];
        (.evidence_status == "open" or
         .evidence_status == "evidenced" or
         .evidence_status == "not_implemented" or
         .evidence_status == "not_applicable") and
        (.evidence_status != "required") and
        (.test_evidence | type == "array") and
        (.screenshot_evidence | type == "array") and
        (.disposition_note | type == "string" and length > 0)
      )
    )
  ' "$COMPONENT_INVENTORY_JSON" >/dev/null; then
  component_inventory_status="pass"
fi
if [ "$component_inventory_status" != "pass" ]; then
  record_violation "Universal component inventory" \
    "Missing or invalid 71-component, 14-state inventory: $COMPONENT_INVENTORY_JSON"
else
  open_component_state_cells="$(
    jq -r '.open_state_cell_count' "$COMPONENT_INVENTORY_JSON"
  )"
  missing_component_count="$(
    jq -r '.status_counts.missing' "$COMPONENT_INVENTORY_JSON"
  )"
  not_applicable_component_state_cells="$(
    jq -r '.not_applicable_state_cell_count' "$COMPONENT_INVENTORY_JSON"
  )"
  if [ "$open_component_state_cells" != "0" ] ||
    [ "$missing_component_count" != "0" ]; then
    record_warning "Open component-library evidence" \
      "$missing_component_count components remain missing; $open_component_state_cells applicable component-state cells still require linked current proof; $not_applicable_component_state_cells cells have explicit component-level non-applicability."
  fi
fi

markdown_files="$(
  find . \( \
    -path '*/.git' -o \
    -path '*/node_modules' -o \
    -path '*/.dart_tool' -o \
    -path '*/build' -o \
    -path '*/.next' -o \
    -path '*/coverage' -o \
    -path '*/output' \
  \) -prune -o -type f \( \
    -name '*.md' -o \
    -name '*.mdx' \
  \) -print |
    sed 's#^\./##' || true
)"

secondary_design_docs="$(
  shopt -s nocasematch
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ "$file" = "DESIGN.md" ] && continue
    if [[ "$file" =~ (^|/)(design|.*design.*|screen[_-]?inventory|visual[_-]?baseline|screenshot[_-]?matrix|style[_-]?guide|ui[_-]?audit|ux[_-]?audit).*\.mdx?$ ]]; then
      printf '%s\n' "$file"
    fi
  done <<<"$markdown_files"
  shopt -u nocasematch
)"
record_violation "Secondary design authority docs" "$secondary_design_docs"

secondary_design_content="$(
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ "$file" = "DESIGN.md" ] && continue
    rg -n -i \
      'source of truth for .*design|product design migration|product design completion|design completion audit|screen inventory|screenshot matrix|visual baseline|style guide' \
      "$file" || true
  done <<<"$markdown_files"
)"
record_violation "Secondary design authority content" "$secondary_design_content"

visual_assets="$(
  find . \( \
    -path '*/.git' -o \
    -path '*/node_modules' -o \
    -path '*/.dart_tool' -o \
    -path '*/build' -o \
    -path '*/.next' -o \
    -path '*/coverage' -o \
    -path '*/output' \
  \) -prune -o -type f \( \
    -iname '*.png' -o \
    -iname '*.jpg' -o \
    -iname '*.jpeg' -o \
    -iname '*.webp' -o \
    -iname '*.svg' -o \
    -iname '*.ico' -o \
    -iname '*.icns' \
  \) -print |
    while IFS= read -r media_file; do
      [ -n "$media_file" ] || continue
      normalized="${media_file#./}"
      media_dir="$(dirname "$media_file")"
      media_name="$(basename "$media_file")"
      source_manifest="$media_dir/SOURCES.md"
      if [[ "$normalized" == apps/*/assets/* ]] &&
        [ -f "$source_manifest" ] &&
        rg -F -q "\`$media_name\`" "$source_manifest" &&
        rg -q -i 'source:\s*`https://' "$source_manifest" &&
        rg -q -i '(approval|right[- ]to[- ]use|rights).*(recorded|required|approved)' "$source_manifest"; then
        continue
      fi
      if [[ "$normalized" == packages/*/test/goldens/* ]] &&
        [ -f "$GOLDEN_BASELINES_JSON" ]; then
        expected_sha="$(
          jq -r --arg path "$normalized" \
            '.baselines[]? | select(.path == $path) | .sha256' \
            "$GOLDEN_BASELINES_JSON" |
            head -n 1
        )"
        actual_sha="$(shasum -a 256 "$media_file" | awk '{print $1}')"
        if [[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]] &&
          [ "$actual_sha" = "$expected_sha" ]; then
          continue
        fi
      fi
      printf '%s\n' "$media_file"
    done || true
)"
record_violation "Unmanaged visual assets" "$visual_assets"

forbidden_static_refs="$(
  rg -n \
    'assets/crest|assets/images|LaunchImage|\bAppIcon\b|ic_launcher|splash_logo|favicon|public/icons|public/media|Image\.asset|/icons/|/media/|crestAsset|CREST_ASSET' \
    . \
    -g '*.dart' \
    -g '*.yaml' \
    -g '*.yml' \
    -g '*.json' \
    -g '*.ts' \
    -g '*.tsx' \
    -g '*.js' \
    -g '*.jsx' \
    -g '*.mjs' \
    -g '*.css' \
    -g '*.xml' \
    -g '*.plist' \
    -g '*.pbxproj' \
    -g '*.md' \
    -g '*.sh' \
    -g '*.html' \
    -g '!node_modules/**' \
    -g '!.git/**' \
    -g '!build/**' \
    -g '!.dart_tool/**' \
    -g '!.next/**' \
    -g '!coverage/**' \
    -g '!output/**' |
    rg -v 'packages/core/core_theme/test/ui_source_guardrails_test\.dart' |
    rg -v 'apps/rayon_sports/web/src/app/brand-(mark|surface)\.svg/route\.ts' |
    rg -v 'apps/rayon_sports_tv/test/tv_app_test\.dart' |
    rg -v 'tools/scripts/design_compliance_report\.sh' || true
)"
record_violation "Forbidden static visual references" "$forbidden_static_refs"

native_asset_dirs="$(
  find apps \( \
    -path '*/node_modules' -o \
    -path '*/.dart_tool' -o \
    -path '*/build' -o \
    -path '*/.next' -o \
    -path '*/coverage' -o \
    -path '*/output' \
  \) -prune -o -type d \( \
    -name Assets.xcassets -o \
    -name AppIcon.appiconset -o \
    -name LaunchImage.imageset \
  \) -print || true
)"
record_violation "Native static asset containers" "$native_asset_dirs"

web_asset_dirs="$(
  find apps/rayon_sports/web \( \
    -path '*/node_modules' -o \
    -path '*/.next' -o \
    -path '*/coverage' -o \
    -path '*/output' \
  \) -prune -o -type d \( \
    -path '*/public/icons' -o \
    -path '*/public/media' \
  \) -print || true
)"
record_violation "Web static media directories" "$web_asset_dirs"

raw_feature_styles="$(
  rg -n \
    '(^|[^A-Za-z0-9_])(const\s+)?Color\s*\(|BorderRadius\.circular\([0-9]|BoxShadow\(|Duration\(milliseconds:|style:\s*(const\s+)?TextStyle\(' \
    packages/features apps/*/lib \
    -g '*.dart' \
    -g '!**/test/**' \
    -g '!**/integration_test/**' |
    rg -v 'ShapeTokens|ColorTokens|AfriDesignTokens|AfriMotion|TypographyTokens|BorderTokens|ExternalBrandColors' || true
)"
record_warning "Raw feature styling advisory" "$raw_feature_styles"

raw_core_theme_styles="$(
  rg -n \
    '(^|[^A-Za-z])(TextStyle|BoxShadow|Duration)\s*\(|\b[0-9]+\.(ms|seconds)\b|\bBorder\.all\s*\(|ImageFilter\.blur\([^)]*(sigmaX|sigmaY):\s*-?[0-9]|(width|height|size|minWidth|minHeight|maxWidth|maxHeight|dimension|strokeWidth|indicatorWeight|displacement|edgeOffset|fontSize|letterSpacing|scaleEnd):\s*(?:[^,\n]*\?\s*)?-?[0-9]' \
    packages/core/core_theme/lib/src/widgets \
    -g '*.dart' || true
)"
record_violation "Raw shared core-theme constants" "$raw_core_theme_styles"

mobile_admin_hits="$(
  rg -n "'mobile_admin':\s*true|hasMobileAdmin:\s*true|mobileAdmin:\s*true" \
    apps packages \
    -g '*.dart' \
    -g '!**/test/**' \
    -g '!**/integration_test/**' || true
)"
record_violation "Consumer mobile admin enablement" "$mobile_admin_hits"

{
  printf '| Route | Surface | Kind | Role Boundary | Required State Evidence | Responsive Evidence | Exceptions |\n'
  printf '| --- | --- | --- | --- | --- | --- | --- |\n'
  if [ "$route_state_closure_status" = "pass" ]; then
    jq -r '
      .routes[]
      | (.states | to_entries | map(select(.value.evidence_status == "open")) | length) as $open
      | (.states | to_entries | map(select(.value.evidence_status == "evidenced")) | length) as $evidenced
      | (.states | to_entries | map(select(.value.evidence_status == "not_applicable")) | length) as $not_applicable
      | [
          ("`" + (.path | gsub("\\|"; "\\\\|")) + "`"),
          .surface,
          .kind,
          .role_boundary,
          ("open=" + ($open | tostring) + "; evidenced=" + ($evidenced | tostring) + "; n/a=" + ($not_applicable | tostring)),
          "linked in route-state-closure.json",
          "none approved unless linked in design-exceptions.json"
        ]
      | "| " + join(" | ") + " |"
    ' "$ROUTE_STATE_CLOSURE_JSON"
  fi
} >"$MATRIX"

violation_count="$(grep -c '^## ' "$VIOLATIONS" || true)"
warning_count="$(grep -c '^## ' "$WARNINGS" || true)"
status="pass"
if [ "$violation_count" != "0" ]; then
  status="fail"
fi

{
  printf '# AFRICLUB DESIGN.md Compliance Report\n\n'
  printf '%s\n' "- Generated: \`$STAMP\`"
  printf '%s\n' "- Root: \`$ROOT\`"
  printf '%s\n' "- Source design: \`$SOURCE_DESIGN\`"
  printf '%s\n' "- Design exceptions: \`$EXCEPTIONS_REGISTER\`"
  printf '%s\n' "- Generated route inventory: \`$ROUTE_INVENTORY_JSON\`"
  printf '%s\n' "- Route-state closure matrix: \`$ROUTE_STATE_CLOSURE_JSON\`"
  printf '%s\n' "- Screen-archetype coverage: \`$SCREEN_ARCHETYPE_COVERAGE_JSON\`"
  printf '%s\n' "- Universal component inventory: \`$COMPONENT_INVENTORY_JSON\`"
  printf '%s\n' "- Repo DESIGN.md SHA-256: \`$repo_design_sha\`"
  printf '%s\n\n' "- Source DESIGN.md SHA-256: \`$source_design_sha\`"
  printf '%s\n' "- Automated source-compliance status: \`$status\`"
  printf '%s\n' "- Design-complete conclusion: \`false\`"
  printf '%s\n\n' "- Route evidence closure: \`incomplete until every required cell links current proof\`"
  printf '## Evidence Matrix\n\n'
  printf 'See `%s`.\n\n' "$MATRIX"
  printf '## Violations\n\n'
  if [ "$violation_count" = "0" ]; then
    printf 'No hard DESIGN.md compliance violations found by this script.\n'
  else
    cat "$VIOLATIONS"
  fi
  printf '\n## Warnings\n\n'
  if [ "$warning_count" = "0" ]; then
    printf 'No advisory DESIGN.md cleanup warnings found by this script.\n'
  else
    cat "$WARNINGS"
  fi
} >"$REPORT"

python3 - "$VALIDATION" "$status" "$violation_count" "$warning_count" "$REPORT" "$MATRIX" \
  "$repo_design_sha" "$source_design_sha" "$EXCEPTIONS_REGISTER" "$exceptions_status" \
  "$ROUTE_INVENTORY_JSON" "$route_inventory_status" "$ROUTE_STATE_CLOSURE_JSON" \
  "$route_state_closure_status" "$SCREEN_ARCHETYPE_COVERAGE_JSON" \
  "$screen_archetype_coverage_status" "$COMPONENT_INVENTORY_JSON" \
  "$component_inventory_status" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "scope": "automated_source_compliance_only",
    "status": sys.argv[2],
    "design_complete": False,
    "route_evidence_complete": False,
    "violation_count": int(sys.argv[3]),
    "warning_count": int(sys.argv[4]),
    "report": sys.argv[5],
    "route_evidence_matrix": sys.argv[6],
    "repo_design_sha256": sys.argv[7],
    "source_design_sha256": sys.argv[8],
    "design_exceptions_register": sys.argv[9],
    "design_exceptions_schema_status": sys.argv[10],
    "route_inventory": sys.argv[11],
    "route_inventory_status": sys.argv[12],
    "route_state_closure": sys.argv[13],
    "route_state_closure_status": sys.argv[14],
    "screen_archetype_coverage": sys.argv[15],
    "screen_archetype_coverage_status": sys.argv[16],
    "component_inventory": sys.argv[17],
    "component_inventory_status": sys.argv[18],
}
path.write_text(json.dumps(payload, indent=2) + "\n")
PY

printf 'Design compliance report: %s\n' "$REPORT"
printf 'Design compliance validation: %s\n' "$VALIDATION"

if [ "$status" != "pass" ]; then
  cat "$VIOLATIONS" >&2
  exit 1
fi
