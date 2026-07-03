import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Africa Sports National (Ivory Coast).
class AfricaSportsConfig implements ClubConfig {
  const AfricaSportsConfig();

  @override
  String get clubId => ClubConfig.requireDefine(
    const String.fromEnvironment('CLUB_ID'),
    'CLUB_ID',
  );

  @override
  String get clubName => 'Africa Sports National';

  @override
  String get appName => 'Africa Sports';

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
    primary: Color(0xFF006B3F),
    secondary: Color(0xFFCC0000),
    accent: Color(0xFFD1D5DB),
    gradient: [Color(0xFF004D2C), Color(0xFF002211)],
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
    ussdTemplate: '*144*4*{amount}*{momo}#',
    senderName: 'Orange Money',
    countryCode: 'CI',
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
