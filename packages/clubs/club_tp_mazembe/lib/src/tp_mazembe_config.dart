import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for TP Mazembe (DR Congo).
class TpMazembeConfig implements ClubConfig {
  const TpMazembeConfig();

  @override
  String get clubId => ClubConfig.requireDefine(
    const String.fromEnvironment('CLUB_ID'),
    'CLUB_ID',
  );

  @override
  String get clubName => 'TP Mazembe';

  @override
  String get appName => 'TP Mazembe';

  @override
  String get country => 'DR Congo';

  @override
  String get countryCode => 'CD';

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*126*';

  @override
  String get currency => 'CDF';

  @override
  String get currencySymbol => 'FC';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF000000),
    secondary: Color(0xFFD1D5DB),
    accent: Color(0xFFC0C0C0),
    gradient: [Color(0xFF1A1A1A), Color(0xFF000000)],
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
  List<String> get supportedLanguages => const ['en'];

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
    ussdTemplate: '*126*1*1*{amount}*{momo}#',
    senderName: 'm-Pesa',
    countryCode: 'CD',
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
