#!/bin/bash
# ==========================================================================
# AfriClub — Download club crests v2 (tries multiple Wikipedia sources)
# ==========================================================================
set -euo pipefail

ROOT="/Volumes/PRO-G40/AFRICLUB"

# Format: slug|exact_wiki_page_url (from the brand_social migration)
LOGOS=(
  "vitalo|https://en.wikipedia.org/wiki/File:Vital%27O_FC_logo.png"
  "yanga|https://en.wikipedia.org/wiki/File:Young_Africans_S.C._logo.png"
  "tp_mazembe|https://en.wikipedia.org/wiki/File:TP_Mazembe_logo.png"
  "simba|https://en.wikipedia.org/wiki/File:Simba_SC_logo.png"
  "as_vita|https://en.wikipedia.org/wiki/File:AS_Vita_Club_logo.png"
  "asante_kotoko|https://en.wikipedia.org/wiki/File:Asante_Kotoko_SC_logo.png"
  "asec_mimosas|https://en.wikipedia.org/wiki/File:ASEC_Mimosas_logo.png"
  "nyasa_bullets|https://en.wikipedia.org/wiki/File:Nyasa_Big_Bullets_FC_logo.png"
  "dynamos|https://en.wikipedia.org/wiki/File:Dynamos_FC_logo.png"
  "africa_sports|https://en.wikipedia.org/wiki/File:Africa_Sports_National_logo.png"
  "nkana|https://en.wikipedia.org/wiki/File:Nkana_FC_logo.png"
  "canon_yaounde|https://en.wikipedia.org/wiki/File:Canon_Yaounde_logo.png"
  "union_douala|https://en.wikipedia.org/wiki/File:Union_Douala_logo.png"
  "zesco_united|https://en.wikipedia.org/wiki/File:ZESCO_United_FC_logo.png"
  "asko_kara|https://en.wikipedia.org/wiki/File:ASKO_Kara_logo.png"
  "ac_leopards|https://en.wikipedia.org/wiki/File:AC_Leopards_logo.png"
  "maranatha|https://en.wikipedia.org/wiki/File:Maranatha_FC_logo.png"
  "as_mangasport|https://en.wikipedia.org/wiki/File:AS_Mangasport_logo.png"
  "mogas_90|https://fr.wikipedia.org/wiki/Fichier:Mogas_90_FC_logo.png"
  "rayon_sports|https://en.wikipedia.org/wiki/File:Rayon_Sports_FC_logo.png"
)

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Downloading club crests from Wikipedia (v2)               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

DOWNLOADED=0
FAILED=0
FAILED_LIST=""

for entry in "${LOGOS[@]}"; do
  IFS='|' read -r slug wiki_url <<< "$entry"

  DEST="$ROOT/apps/$slug/assets/crest/${slug}_crest.png"

  # Skip if already downloaded and > 1KB
  if [[ -f "$DEST" ]] && [[ $(wc -c < "$DEST" | tr -d ' ') -gt 1000 ]]; then
    echo "  $slug: ✓ Already exists ($(wc -c < "$DEST" | tr -d ' ') bytes)"
    DOWNLOADED=$((DOWNLOADED + 1))
    continue
  fi

  mkdir -p "$(dirname "$DEST")"
  echo -n "  $slug: "

  # Extract filename from URL
  WIKI_FILENAME=$(echo "$wiki_url" | sed -E 's|.*/File:||; s|.*/Fichier:||')

  # Try multiple API endpoints
  IMAGE_URL=""
  for API_BASE in "https://en.wikipedia.org/w/api.php" "https://commons.wikimedia.org/w/api.php" "https://fr.wikipedia.org/w/api.php"; do
    API_CALL="${API_BASE}?action=query&titles=File:${WIKI_FILENAME}&prop=imageinfo&iiprop=url&iiurlwidth=512&format=json"
    RESP=$(curl -sL --max-time 10 "$API_CALL" 2>/dev/null || echo "")
    if [[ -z "$RESP" ]]; then continue; fi

    URL=$(echo "$RESP" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    pages = data.get('query',{}).get('pages',{})
    for pid, p in pages.items():
        if pid == '-1': continue
        ii = p.get('imageinfo',[{}])[0]
        u = ii.get('thumburl', ii.get('url',''))
        if u: print(u); break
except: pass
" 2>/dev/null || echo "")

    if [[ -n "$URL" ]]; then
      IMAGE_URL="$URL"
      break
    fi
  done

  if [[ -z "$IMAGE_URL" ]]; then
    echo "✗ Could not resolve"
    FAILED=$((FAILED + 1))
    FAILED_LIST="$FAILED_LIST $slug"
    continue
  fi

  HTTP_CODE=$(curl -sL -w "%{http_code}" -o "$DEST" --max-time 15 "$IMAGE_URL" 2>/dev/null || echo "000")
  if [[ "$HTTP_CODE" == "200" ]] && [[ -s "$DEST" ]]; then
    FS=$(wc -c < "$DEST" | tr -d ' ')
    echo "✓ Downloaded ($FS bytes)"
    DOWNLOADED=$((DOWNLOADED + 1))
  else
    echo "✗ HTTP $HTTP_CODE"
    rm -f "$DEST"
    FAILED=$((FAILED + 1))
    FAILED_LIST="$FAILED_LIST $slug"
  fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Downloaded: $DOWNLOADED  |  Failed: $FAILED                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
if [[ -n "$FAILED_LIST" ]]; then
  echo "Failed clubs:$FAILED_LIST"
fi
