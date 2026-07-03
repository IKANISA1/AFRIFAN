import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Mogas 90 FC (Benin).
class Mogas90Config implements ClubConfig {
  const Mogas90Config();

  @override
  String get clubId => ClubConfig.requireDefine(
    const String.fromEnvironment('CLUB_ID'),
    'CLUB_ID',
  );

  @override
  String get clubName => 'Mogas 90 FC';

  @override
  String get appName => 'Mogas 90';

  @override
  String get country => 'Benin';

  @override
  String get countryCode => 'BJ';

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
    primary: Color(0xFF006B3F),
    secondary: Color(0xFFD1D5DB),
    accent: Color(0xFFCC0000),
    gradient: [Color(0xFF004D2C), Color(0xFF330000)],
  );
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
    senderName: 'MTN MoMo',
    countryCode: 'BJ',
  );

  @override
  String get environment =>
      const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');

  @override
  Map<String, bool> get features => {
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
  };
}
