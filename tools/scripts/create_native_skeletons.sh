#!/bin/bash
# ==========================================================================
# AfriClub — Generate native Android/iOS skeletons for 19 new club apps
# ==========================================================================
set -euo pipefail

ROOT="/Volumes/PRO-G40/AFRICLUB"

# Format: slug|org_prefix (reverse domain for applicationId)
CLUBS=(
  "vitalo|bi.ikanisa"
  "yanga|tz.ikanisa"
  "tp_mazembe|cd.ikanisa"
  "simba|tz.ikanisa"
  "as_vita|cd.ikanisa"
  "asante_kotoko|gh.ikanisa"
  "asec_mimosas|ci.ikanisa"
  "nyasa_bullets|mw.ikanisa"
  "dynamos|zw.ikanisa"
  "africa_sports|ci.ikanisa"
  "nkana|zm.ikanisa"
  "canon_yaounde|cm.ikanisa"
  "union_douala|cm.ikanisa"
  "zesco_united|zm.ikanisa"
  "asko_kara|tg.ikanisa"
  "ac_leopards|cg.ikanisa"
  "maranatha|tg.ikanisa"
  "as_mangasport|ga.ikanisa"
  "mogas_90|bj.ikanisa"
)

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Generating Flutter native skeletons (Android + iOS)       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

TOTAL=${#CLUBS[@]}
CURRENT=0

for entry in "${CLUBS[@]}"; do
  IFS='|' read -r slug org <<< "$entry"
  CURRENT=$((CURRENT + 1))
  APP_DIR="$ROOT/apps/$slug"

  echo "[$CURRENT/$TOTAL] $slug (org: $org)"

  cd "$APP_DIR"

  # flutter create adds missing platform dirs without overwriting existing code
  flutter create \
    --platforms android,ios \
    --org "$org" \
    --project-name "$slug" \
    . \
    2>&1 | grep -E '(Creating|Running|Wrote|All done)' || true

  echo "  ✓ Native skeleton created"
  echo ""
done

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ All $TOTAL native skeletons generated                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
