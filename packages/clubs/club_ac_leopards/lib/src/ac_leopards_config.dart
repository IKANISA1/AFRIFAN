import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for AC Léopards (Congo Republic).
class AcLeopardsConfig implements ClubConfig {
  const AcLeopardsConfig();

  @override
  String get clubId =>
      ClubConfig.requireDefine(
        const String.fromEnvironment('CLUB_ID'),
        'CLUB_ID',
      );

  @override
  String get clubName => 'AC Léopards';

  @override
  String get appName => 'AC Léopards';

  @override
  String get country => 'Congo Republic';

  @override
  String get countryCode => 'CG';

  @override
  String get language => 'fr';

  @override
  String get momoPrefix => '*144*';

  @override
  String get currency => 'XAF';

  @override
  String get currencySymbol => 'FCFA';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF006B3F),
    secondary: Color(0xFFD1D5DB),
    accent: Color(0xFF000000),
    gradient: [Color(0xFF004D2C), Color(0xFF002211)],
  );

  @override
  String get crestAsset => 'assets/crest/ac_leopards_crest.png';

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
  List<String> get supportedLanguages => const ['fr', 'ln', 'en'];

  @override
  bool get hasBioPay => false;

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
    ussdTemplate: '*144*{amount}*{momo}#',
    senderName: 'Airtel Money',
    countryCode: 'CG',
  );

  @override
  String get environment => const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');

  @override
  Map<String, bool> get features => {
    'BioPay': hasBioPay,
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
  };
}
