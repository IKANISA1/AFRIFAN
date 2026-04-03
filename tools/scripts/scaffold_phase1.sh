#!/bin/bash
# ==========================================================================
# AfriClub — Scaffold 19 new club apps + config packages
# ==========================================================================
# This script:
#   1. Creates packages/clubs/club_{slug}/ config packages
#   2. Creates apps/{slug}/ by copying from rayon_sports template
#   3. Customizes each app's main.dart, pubspec.yaml, and Android build
# ==========================================================================

set -euo pipefail

ROOT="/Volumes/PRO-G40/AFRICLUB"
TEMPLATE_APP="$ROOT/apps/rayon_sports"

# ── Club definitions ──
# Format: slug|club_name|app_name|country|country_code|language|momo_prefix|ussd_template|momo_sender|currency|currency_sym|primary|secondary|accent|gradient1|gradient2|languages|config_class|app_id_prefix
CLUBS=(
  "vitalo|Vital'O FC|Vital'O|Burundi|BI|fr|*150*|*150*2*{amount}*{momo}#|Lumitel MoMo|BIF|FBu|0xFF7B2D8E|0xFFFFFFFF|0xFFFFD700|0xFF5A1E6E|0xFF2D0A3E|fr,rn,en|VitaloConfig|bi.ikanisa.vitalo"
  "yanga|Young Africans (Yanga)|Yanga SC|Tanzania|TZ|sw|*150*|*150*00*{amount}*{momo}#|Tigo Pesa|TZS|TSh|0xFF006B3F|0xFFFFD700|0xFFFFFFFF|0xFF004D2C|0xFF002211|sw,en|YangaConfig|tz.ikanisa.yanga"
  "tp_mazembe|TP Mazembe|TP Mazembe|DR Congo|CD|fr|*126*|*126*1*1*{amount}*{momo}#|m-Pesa|CDF|FC|0xFF000000|0xFFFFFFFF|0xFFC0C0C0|0xFF1A1A1A|0xFF000000|fr,ln,en|TpMazembeConfig|cd.ikanisa.tp_mazembe"
  "simba|Simba SC|Simba SC|Tanzania|TZ|sw|*150*|*150*00*{amount}*{momo}#|Tigo Pesa|TZS|TSh|0xFFCC0000|0xFFFFFFFF|0xFFFFD700|0xFF990000|0xFF330000|sw,en|SimbaConfig|tz.ikanisa.simba"
  "as_vita|AS Vita Club|AS Vita Club|DR Congo|CD|fr|*126*|*126*1*1*{amount}*{momo}#|m-Pesa|CDF|FC|0xFF006400|0xFF000000|0xFFFFD700|0xFF004D00|0xFF002200|fr,ln,en|AsVitaConfig|cd.ikanisa.as_vita"
  "asante_kotoko|Asante Kotoko SC|Asante Kotoko|Ghana|GH|en|*170*|*170*1*{amount}*{momo}#|MTN MoMo|GHS|GH₵|0xFFCC0000|0xFFFFFFFF|0xFFFFD700|0xFF990000|0xFF330000|en,ak,tw|AsanteKotokoConfig|gh.ikanisa.asante_kotoko"
  "asec_mimosas|ASEC Mimosas|ASEC Mimosas|Ivory Coast|CI|fr|*144*|*144*4*{amount}*{momo}#|Orange Money|XOF|CFA|0xFFFFD700|0xFF000000|0xFFFF8C00|0xFFCCAA00|0xFF997700|fr,en|AsecMimosasConfig|ci.ikanisa.asec_mimosas"
  "nyasa_bullets|Nyasa Big Bullets FC|Nyasa Bullets|Malawi|MW|en|*414*|*414*{amount}*{momo}#|Airtel Money|MWK|MK|0xFFCC0000|0xFFFFFFFF|0xFF000000|0xFF990000|0xFF330000|en,ny|NyasaBulletsConfig|mw.ikanisa.nyasa_bullets"
  "dynamos|Dynamos FC|Dynamos FC|Zimbabwe|ZW|en|*153*|*153*2*{amount}*{momo}#|EcoCash|USD|$|0xFF0000CC|0xFFFFFFFF|0xFFFFD700|0xFF000099|0xFF000044|en,sn|DynamosConfig|zw.ikanisa.dynamos"
  "africa_sports|Africa Sports National|Africa Sports|Ivory Coast|CI|fr|*144*|*144*4*{amount}*{momo}#|Orange Money|XOF|CFA|0xFF006B3F|0xFFCC0000|0xFFFFFFFF|0xFF004D2C|0xFF002211|fr,en|AfricaSportsConfig|ci.ikanisa.africa_sports"
  "nkana|Nkana FC|Nkana FC|Zambia|ZM|en|*303*|*303*{amount}*{momo}#|Airtel Money|ZMW|ZK|0xFFCC0000|0xFFFFFFFF|0xFF000000|0xFF990000|0xFF330000|en,bem|NkanaConfig|zm.ikanisa.nkana"
  "canon_yaounde|Canon Yaoundé|Canon Yaoundé|Cameroon|CM|fr|*126*|*126*1*{amount}*{momo}#|Orange Money|XAF|FCFA|0xFF006B3F|0xFFCC0000|0xFFFFD700|0xFF004D2C|0xFF1A0000|fr,en|CanonYaoundeConfig|cm.ikanisa.canon_yaounde"
  "union_douala|Union Douala|Union Douala|Cameroon|CM|fr|*126*|*126*1*{amount}*{momo}#|Orange Money|XAF|FCFA|0xFF006B3F|0xFFFFFFFF|0xFF000000|0xFF004D2C|0xFF002211|fr,en|UnionDoualaConfig|cm.ikanisa.union_douala"
  "zesco_united|ZESCO United FC|ZESCO United|Zambia|ZM|en|*303*|*303*{amount}*{momo}#|Airtel Money|ZMW|ZK|0xFF006B3F|0xFFFF8C00|0xFFFFFFFF|0xFF004D2C|0xFF002211|en,bem|ZescoUnitedConfig|zm.ikanisa.zesco_united"
  "asko_kara|ASKO de Kara|ASKO Kara|Togo|TG|fr|*144*|*144*{amount}*{momo}#|Moov Money|XOF|CFA|0xFFFFD700|0xFF006B3F|0xFF000000|0xFFCCAA00|0xFF004D2C|fr,ee,en|AskoKaraConfig|tg.ikanisa.asko_kara"
  "ac_leopards|AC Léopards|AC Léopards|Congo Republic|CG|fr|*144*|*144*{amount}*{momo}#|Airtel Money|XAF|FCFA|0xFF006B3F|0xFFFFFFFF|0xFF000000|0xFF004D2C|0xFF002211|fr,ln,en|AcLeopardsConfig|cg.ikanisa.ac_leopards"
  "maranatha|Maranatha FC|Maranatha FC|Togo|TG|fr|*144*|*144*{amount}*{momo}#|Moov Money|XOF|CFA|0xFFCC0000|0xFFFFFFFF|0xFFFFD700|0xFF990000|0xFF330000|fr,ee,en|MaranathaConfig|tg.ikanisa.maranatha"
  "as_mangasport|AS Mangasport|AS Mangasport|Gabon|GA|fr|*126*|*126*{amount}*{momo}#|Airtel Money|XAF|FCFA|0xFFFFD700|0xFF006B3F|0xFF000000|0xFFCCAA00|0xFF004D2C|fr,en|AsMangasportConfig|ga.ikanisa.as_mangasport"
  "mogas_90|Mogas 90 FC|Mogas 90|Benin|BJ|fr|*144*|*144*{amount}*{momo}#|MTN MoMo|XOF|CFA|0xFF006B3F|0xFFFFFFFF|0xFFCC0000|0xFF004D2C|0xFF330000|fr,en|Mogas90Config|bj.ikanisa.mogas_90"
)

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  AfriClub Multi-Club Scaffold — 19 New Clubs               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

for entry in "${CLUBS[@]}"; do
  IFS='|' read -r slug club_name app_name country country_code language momo_prefix ussd_template momo_sender currency currency_sym primary secondary accent gradient1 gradient2 languages config_class app_id <<< "$entry"

  echo "━━━ Scaffolding: $club_name ($slug) ━━━"

  # ── 1. CREATE CONFIG PACKAGE ──
  PKG_DIR="$ROOT/packages/clubs/club_$slug"
  mkdir -p "$PKG_DIR/lib/src"

  # pubspec.yaml
  cat > "$PKG_DIR/pubspec.yaml" << PUBEOF
name: club_$slug
description: $club_name — AFRICLUB club configuration package.
publish_to: none
version: 1.0.0

environment:
  sdk: ">=3.10.0 <4.0.0"

dependencies:
  core_theme:
    path: ../../../packages/core/core_theme

resolution: workspace
PUBEOF

  # Barrel export
  cat > "$PKG_DIR/lib/club_$slug.dart" << BAREOF
/// $club_name — Club configuration package.
library club_$slug;

export 'src/${slug}_config.dart';
BAREOF

  # Convert languages to Dart list syntax: 'fr', 'en'
  DART_LANGS=$(echo "$languages" | sed "s/,/', '/g" | sed "s/^/'/" | sed "s/$/'/")

  # Config implementation
  cat > "$PKG_DIR/lib/src/${slug}_config.dart" << CFGEOF
import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for $club_name ($country).
class $config_class implements ClubConfig {
  const $config_class();

  @override
  String get clubId =>
      const String.fromEnvironment('CLUB_ID', defaultValue: '$slug');

  @override
  String get clubName => '$club_name';

  @override
  String get appName => '$app_name';

  @override
  String get country => '$country';

  @override
  String get countryCode => '$country_code';

  @override
  String get language => '$language';

  @override
  String get momoPrefix => '$momo_prefix';

  @override
  String get currency => '$currency';

  @override
  String get currencySymbol => '$currency_sym';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color($primary),
    secondary: Color($secondary),
    accent: Color($accent),
    gradient: [Color($gradient1), Color($gradient2)],
  );

  @override
  String get crestAsset => 'assets/crest/${slug}_crest.png';

  @override
  String get supabaseUrl => const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mmpbzcdhfvplxplnfucy.supabase.co',
  );

  @override
  String get supabaseAnonKey => const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tcGJ6Y2RoZnZwbHhwbG5mdWN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNDM2MTYsImV4cCI6MjA4ODcxOTYxNn0.Ojw-vQ6aEJjyuZU4nReP4ynxJ2XjD5L6n6TxhLlzeeQ',
  );

  @override
  List<String> get supportedLanguages => const [$DART_LANGS];

  @override
  bool get hasBiopay => true;

  @override
  bool get hasFanClubs => true;

  @override
  bool get hasShop => true;

  @override
  bool get hasTicketing => true;

  @override
  bool get hasChat => true;

  @override
  bool get hasSmsLedger => true;

  @override
  MomoConfig get momo => const MomoConfig(
    ussdTemplate: '$ussd_template',
    senderName: '$momo_sender',
    countryCode: '$country_code',
  );

  @override
  Map<String, bool> get features => {
    'biopay': hasBiopay,
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
  };
}
CFGEOF

  echo "  ✓ Config package: packages/clubs/club_$slug/"

  # ── 2. CREATE APP ──
  APP_DIR="$ROOT/apps/$slug"
  mkdir -p "$APP_DIR/lib"
  mkdir -p "$APP_DIR/assets/crest"
  mkdir -p "$APP_DIR/assets/images"
  mkdir -p "$APP_DIR/assets/flavors"
  mkdir -p "$APP_DIR/assets/models/biopay"

  # Copy shared files from rayon_sports
  cp "$TEMPLATE_APP/lib/bootstrap.dart" "$APP_DIR/lib/bootstrap.dart"
  cp "$TEMPLATE_APP/lib/app.dart"       "$APP_DIR/lib/app.dart"
  cp "$TEMPLATE_APP/lib/shell.dart"     "$APP_DIR/lib/shell.dart"

  # Copy placeholder crest from rayon_sports
  if [ -d "$TEMPLATE_APP/assets/crest" ]; then
    for f in "$TEMPLATE_APP/assets/crest/"*; do
      [ -f "$f" ] && cp "$f" "$APP_DIR/assets/crest/${slug}_crest.png" && break
    done
  fi

  # Copy images dir content
  if [ -d "$TEMPLATE_APP/assets/images" ]; then
    cp -r "$TEMPLATE_APP/assets/images/"* "$APP_DIR/assets/images/" 2>/dev/null || true
  fi

  # Copy biopay model assets
  if [ -d "$TEMPLATE_APP/assets/models/biopay" ]; then
    cp -r "$TEMPLATE_APP/assets/models/biopay/"* "$APP_DIR/assets/models/biopay/" 2>/dev/null || true
  fi

  # main.dart
  cat > "$APP_DIR/lib/main.dart" << MAINEOF
import 'package:club_$slug/club_$slug.dart';

import 'bootstrap.dart';

/// Production entry point for $club_name.
///
/// Build: flutter build apk --dart-define-from-file=assets/flavors/production.json
void main() {
  bootstrap(const $config_class());
}
MAINEOF

  # pubspec.yaml
  cat > "$APP_DIR/pubspec.yaml" << APPEOF
name: $slug
description: $club_name — AFRICLUB fan super-app
publish_to: none
version: 1.0.0+1

environment:
  sdk: ">=3.10.0 <4.0.0"
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # Core packages
  core_theme:
    path: ../../packages/core/core_theme
  core_auth:
    path: ../../packages/core/core_auth
  core_network:
    path: ../../packages/core/core_network
  core_router:
    path: ../../packages/core/core_router
  core_di:
    path: ../../packages/core/core_di
  core_utils:
    path: ../../packages/core/core_utils

  # Club config
  club_$slug:
    path: ../../packages/clubs/club_$slug

  # Feature packages
  feat_home:
    path: ../../packages/features/feat_home
  feat_membership:
    path: ../../packages/features/feat_membership
  feat_gamification:
    path: ../../packages/features/feat_gamification
  feat_contributions:
    path: ../../packages/features/feat_contributions
  feat_shop:
    path: ../../packages/features/feat_shop
  feat_biopay:
    path: ../../packages/features/feat_biopay
  feat_sms_ledger:
    path: ../../packages/features/feat_sms_ledger
  feat_settings:
    path: ../../packages/features/feat_settings
  feat_onboarding:
    path: ../../packages/features/feat_onboarding
  feat_ticketing:
    path: ../../packages/features/feat_ticketing
  feat_fan_clubs:
    path: ../../packages/features/feat_fan_clubs
  feat_live:
    path: ../../packages/features/feat_live
  feat_admin:
    path: ../../packages/features/feat_admin

  # Third-party
  go_router: ^14.8.1
  supabase_flutter: ^2.12.2
  google_fonts: ^6.2.1
  flutter_animate: ^4.5.2
  get_it: ^8.0.3
  url_launcher: ^6.3.1
  intl: ^0.20.2
  flutter_riverpod: ^2.6.1
  hive_flutter: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true

  assets:
    - assets/crest/
    - assets/flavors/
    - assets/images/
    - assets/models/biopay/

resolution: workspace
APPEOF

  # production.json dart-define
  cat > "$APP_DIR/assets/flavors/production.json" << FLVEOF
{
  "CLUB_ID": "$slug",
  "CLUB_NAME": "$club_name",
  "APP_NAME": "$app_name",
  "COUNTRY_CODE": "$country_code",
  "SUPABASE_URL": "https://mmpbzcdhfvplxplnfucy.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tcGJ6Y2RoZnZwbHhwbG5mdWN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNDM2MTYsImV4cCI6MjA4ODcxOTYxNn0.Ojw-vQ6aEJjyuZU4nReP4ynxJ2XjD5L6n6TxhLlzeeQ",
  "ENVIRONMENT": "production"
}
FLVEOF

  # analysis_options.yaml
  cat > "$APP_DIR/analysis_options.yaml" << ANLEOF
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: false
    prefer_const_declarations: false
    prefer_const_literals_to_create_immutables: false
    use_key_in_widget_constructors: false
    avoid_print: false
    constant_identifier_names: false
    directives_ordering: false
ANLEOF

  echo "  ✓ App: apps/$slug/"

done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ Scaffolded 19 club config packages and 19 app dirs     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next: Update root pubspec.yaml workspace list"
