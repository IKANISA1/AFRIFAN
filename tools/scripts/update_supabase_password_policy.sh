#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# update_supabase_password_policy.sh
#
# Updates the production Supabase Auth password policy to:
#   - minimum_password_length: 8
#   - password_requirements:   letters_digits
#
# This matches the local config.toml setting updated in the
# production audit (Task 4).
#
# USAGE:
#   ./tools/scripts/update_supabase_password_policy.sh <SUPABASE_ACCESS_TOKEN>
#
# HOW TO GET AN ACCESS TOKEN:
#   1. Go to https://supabase.com/dashboard/account/tokens
#   2. Click "Generate New Token"
#   3. Name it "password-policy-update" (temporary, delete after)
#   4. Copy the token and pass it as the argument
#
# The script will:
#   1. Fetch the current auth config (to verify connectivity)
#   2. PATCH the password policy settings
#   3. Verify the update succeeded
# ──────────────────────────────────────────────────────────────
set -euo pipefail

PROJECT_REF="mmpbzcdhfvplxplnfucy"
API_BASE="https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth"

# ── Validate input ──────────────────────────────────────────
TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  echo "❌ Usage: $0 <SUPABASE_ACCESS_TOKEN>"
  echo ""
  echo "Get a token from: https://supabase.com/dashboard/account/tokens"
  exit 1
fi

echo "🔑 Using project ref: ${PROJECT_REF}"
echo ""

# ── Step 1: Verify connectivity by fetching current config ──
echo "📡 Fetching current auth config..."
CURRENT=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${API_BASE}")

HTTP_CODE=$(echo "$CURRENT" | tail -1)
BODY=$(echo "$CURRENT" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
  echo "❌ Failed to fetch auth config (HTTP $HTTP_CODE)"
  echo "$BODY"
  exit 1
fi

CURRENT_MIN_LENGTH=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('password_min_length', 'unknown'))" 2>/dev/null || echo "unknown")
CURRENT_REQUIREMENTS=$(echo "$BODY" | python3 -c "import sys,json; v=json.load(sys.stdin).get('password_required_characters',''); print('letters_digits' if v and 'ABC' in v and '012' in v else v or 'none')" 2>/dev/null || echo "unknown")

echo "   Current min length:    ${CURRENT_MIN_LENGTH}"
echo "   Current requirements:  ${CURRENT_REQUIREMENTS}"
echo ""

# ── Step 2: Update password policy ─────────────────────────
echo "🔧 Updating password policy..."
echo "   → minimum_password_length: 8"
echo "   → password_requirements:   letters_digits"
echo ""

PATCH_RESULT=$(curl -s -w "\n%{http_code}" \
  -X PATCH \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "password_min_length": 8,
    "password_required_characters": "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ:0123456789"
  }' \
  "${API_BASE}")

PATCH_HTTP=$(echo "$PATCH_RESULT" | tail -1)
PATCH_BODY=$(echo "$PATCH_RESULT" | sed '$d')

if [ "$PATCH_HTTP" != "200" ]; then
  echo "❌ Failed to update password policy (HTTP $PATCH_HTTP)"
  echo "$PATCH_BODY"
  exit 1
fi

echo "✅ Password policy updated successfully!"
echo ""

# ── Step 3: Verify the update ──────────────────────────────
echo "🔍 Verifying update..."
VERIFY=$(curl -s \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${API_BASE}")

NEW_MIN_LENGTH=$(echo "$VERIFY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('password_min_length', 'unknown'))" 2>/dev/null || echo "unknown")
NEW_REQUIREMENTS=$(echo "$VERIFY" | python3 -c "import sys,json; v=json.load(sys.stdin).get('password_required_characters',''); print('letters_digits' if v and 'ABC' in v and '012' in v else v or 'none')" 2>/dev/null || echo "unknown")

echo "   New min length:    ${NEW_MIN_LENGTH}"
echo "   New requirements:  ${NEW_REQUIREMENTS}"
echo ""

if [ "$NEW_MIN_LENGTH" = "8" ] && [ "$NEW_REQUIREMENTS" = "letters_digits" ]; then
  echo "✅ Verification passed — production password policy matches config.toml"
else
  echo "⚠️  Verification returned unexpected values. Please check the Supabase dashboard manually."
fi

echo ""
echo "🧹 Remember to delete the access token from:"
echo "   https://supabase.com/dashboard/account/tokens"
