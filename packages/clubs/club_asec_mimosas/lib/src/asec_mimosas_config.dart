import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for ASEC Mimosas (Ivory Coast).
class AsecMimosasConfig implements ClubConfig {
  const AsecMimosasConfig();

  @override
  String get clubId =>
      ClubConfig.requireDefine(
        const String.fromEnvironment('CLUB_ID'),
        'CLUB_ID',
      );

  @override
  String get clubName => 'ASEC Mimosas';

  @override
  String get appName => 'ASEC Mimosas';

  @override
  String get country => 'Ivory Coast';

  @override
  String get countryCode => 'CI';

  @override
  String get language => 'fr';

  @override
  String get momoPrefix => '*144*';

  @override
  String get currency => 'XOF';

  @override
  String get currencySymbol => 'CFA';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFFFFD700),
    secondary: Color(0xFF000000),
    accent: Color(0xFFFF8C00),
    gradient: [Color(0xFFCCAA00), Color(0xFF997700)],
  );

  @override
  String get crestAsset => 'assets/crest/asec_mimosas_crest.png';

  @override
  String get supabaseUrl => ClubConfig.requireDefine(
    const String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_URL',
  );

  @override
  String get supabaseAnonKey => ClubConfig.requireDefine(
    const String.fromEnvironment('SUPABASE_ANON_KEY'),
    'SUPABASE_ANON_KEY',
  );

  @override
  List<String> get supportedLanguages => const ['fr', 'en'];

  @override
  bool get hasBiopay => false;

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
    ussdTemplate: '*144*4*{amount}*{momo}#',
    senderName: 'Orange Money',
    countryCode: 'CI',
  );

  @override
  String get environment => const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');

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
