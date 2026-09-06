import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Canon Yaoundé (Cameroon).
class CanonYaoundeConfig implements ClubConfig {
  const CanonYaoundeConfig();

  @override
  String get clubId => ClubConfig.requireDefine(
    const String.fromEnvironment('CLUB_ID'),
    'CLUB_ID',
  );

  @override
  String get clubName => 'Canon Yaoundé';

  @override
  String get appName => 'Canon Yaoundé';

  @override
  String get country => 'Cameroon';

  @override
  String get countryCode => 'CM';

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*126*';

  @override
  String get currency => 'XAF';

  @override
  String get currencySymbol => 'FCFA';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF006B3F),
    secondary: Color(0xFFCC0000),
    accent: Color(0xFFFFD700),
    gradient: [Color(0xFF004D2C), Color(0xFF1A0000)],
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
    ussdTemplate: '*126*1*{amount}*{momo}#',
    senderName: 'Orange Money',
    countryCode: 'CM',
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
