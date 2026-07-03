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
  \) -print || true
)"
record_violation "Stored visual design assets" "$visual_assets"

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

mobile_admin_hits="$(
  rg -n "'mobile_admin':\s*true|hasMobileAdmin:\s*true|mobileAdmin:\s*true" \
    apps packages \
    -g '*.dart' \
    -g '!**/test/**' \
    -g '!**/integration_test/**' || true
)"
record_violation "Consumer mobile admin enablement" "$mobile_admin_hits"

route_names="$(
  rg -n 'static const String [a-zA-Z0-9_]+ =' packages/core/core_router/lib/src/route_names.dart |
    sed -E "s/.*String ([A-Za-z0-9_]+) = '([^']+)'.*/\1|\2/" || true
)"

{
  printf '| Route ID | Surface | Role Boundary | Required State Evidence | Responsive Evidence | Exceptions |\n'
  printf '| --- | --- | --- | --- | --- | --- |\n'
  while IFS='|' read -r route_id route_path; do
    [ -n "$route_id" ] || continue
    surface="mobile"
    role="consumer"
    if [ "$route_id" = "admin" ]; then
      surface="admin"
      role="operator"
    fi
    printf '| `%s` | %s | %s | required | required | none recorded |\n' \
      "$route_path" "$surface" "$role"
  done <<<"$route_names"
  printf '| `apps/rayon_sports_tv` | TV | read-only screen-safe native Flutter app | required | 720p/1080p native TV contract required | none recorded |\n'
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
  printf '%s\n' "- Repo DESIGN.md SHA-256: \`$repo_design_sha\`"
  printf '%s\n\n' "- Source DESIGN.md SHA-256: \`$source_design_sha\`"
  printf '%s\n\n' "- Status: \`$status\`"
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
  "$repo_design_sha" "$source_design_sha" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "status": sys.argv[2],
    "violation_count": int(sys.argv[3]),
    "warning_count": int(sys.argv[4]),
    "report": sys.argv[5],
    "route_evidence_matrix": sys.argv[6],
    "repo_design_sha256": sys.argv[7],
    "source_design_sha256": sys.argv[8],
}
path.write_text(json.dumps(payload, indent=2) + "\n")
PY

printf 'Design compliance report: %s\n' "$REPORT"
printf 'Design compliance validation: %s\n' "$VALIDATION"

if [ "$status" != "pass" ]; then
  cat "$VIOLATIONS" >&2
  exit 1
fi
