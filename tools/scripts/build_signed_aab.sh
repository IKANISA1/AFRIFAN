#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────
# Gikundiro Local Signed AAB Builder
# ──────────────────────────────────────────────────────────
# Usage:
#   1. Ensure keystore.properties and upload-keystore.jks
#      exist in apps/rayon_sports/android/
#   2. Run: bash tools/scripts/build_signed_aab.sh
# ──────────────────────────────────────────────────────────

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$REPO_ROOT/apps/rayon_sports"
ANDROID_DIR="$APP_DIR/android"
KEYSTORE_FILE="$ANDROID_DIR/upload-keystore.jks"
KEYSTORE_PROPS="$ANDROID_DIR/keystore.properties"
FLUTTER_PIN="$(tr -d '[:space:]' < "$REPO_ROOT/.fvmrc")"

# ── Resolve Flutter ──
if [ -x "$REPO_ROOT/.fvm/flutter_sdk/bin/flutter" ]; then
  FLUTTER="$REPO_ROOT/.fvm/flutter_sdk/bin/flutter"
elif [ -x "$HOME/fvm/versions/$FLUTTER_PIN/bin/flutter" ]; then
  FLUTTER="$HOME/fvm/versions/$FLUTTER_PIN/bin/flutter"
elif command -v flutter &>/dev/null; then
  FLUTTER="$(command -v flutter)"
elif [ -x "/usr/local/share/flutter/bin/flutter" ]; then
  FLUTTER="/usr/local/share/flutter/bin/flutter"
else
  echo "❌ Flutter not found. Add flutter to PATH or install via fvm."
  exit 1
fi

echo "🔧 Using Flutter: $FLUTTER"
$FLUTTER --version | head -1
bash "$REPO_ROOT/tools/scripts/validate_flutter_runtime_pins.sh" \
  --runtime "$FLUTTER"

# ── Validate signing prerequisites ──
if [ ! -f "$KEYSTORE_FILE" ]; then
  echo "❌ Missing: $KEYSTORE_FILE"
  echo "   Generate one with:"
  echo "   keytool -genkey -v -keystore '$KEYSTORE_FILE' \\"
  echo "     -keyalg RSA -keysize 2048 -validity 10000 -alias upload"
  exit 1
fi

if [ ! -f "$KEYSTORE_PROPS" ]; then
  echo "❌ Missing: $KEYSTORE_PROPS"
  echo "   Create from keystore.properties.example"
  exit 1
fi

# ── Validate google-services.json ──
if [ ! -f "$ANDROID_DIR/app/google-services.json" ]; then
  echo "❌ Missing: $ANDROID_DIR/app/google-services.json (required for release builds)"
  exit 1
fi

# ── Bootstrap monorepo ──
echo "📦 Bootstrapping monorepo..."
cd "$REPO_ROOT"
if command -v melos &>/dev/null; then
  melos bootstrap
elif dart pub global list 2>/dev/null | grep -q melos; then
  dart pub global run melos bootstrap
else
  echo "⚙️  Installing melos..."
  dart pub global activate melos
  dart pub global run melos bootstrap
fi

# ── Build signed AAB ──
echo "🏗️  Building signed release AAB..."
cd "$APP_DIR"
$FLUTTER build appbundle --release --dart-define-from-file=assets/flavors/production.json

AAB_PATH="$APP_DIR/build/app/outputs/bundle/release/app-release.aab"
if [ -f "$AAB_PATH" ]; then
  SIZE=$(du -h "$AAB_PATH" | cut -f1)
  echo ""
  echo "✅ Signed AAB built successfully!"
  echo "   Path: $AAB_PATH"
  echo "   Size: $SIZE"
  echo ""
  echo "📱 Next steps:"
  echo "   1. Upload to Play Console: https://play.google.com/console"
  echo "   2. Or install locally: flutter install --release"
else
  echo "❌ Build failed — AAB not found at expected path."
  exit 1
fi
