import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Dynamos FC (Zimbabwe).
class DynamosConfig implements ClubConfig {
  const DynamosConfig();

  @override
  String get clubId =>
      ClubConfig.requireDefine(
        const String.fromEnvironment('CLUB_ID'),
        'CLUB_ID',
      );

  @override
  String get clubName => 'Dynamos FC';

  @override
  String get appName => 'Dynamos FC';

  @override
  String get country => 'Zimbabwe';

  @override
  String get countryCode => 'ZW';

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*153*';

  @override
  String get currency => 'USD';

  @override
  String get currencySymbol => '\$';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF0000CC),
    secondary: Color(0xFFD1D5DB),
    accent: Color(0xFFFFD700),
    gradient: [Color(0xFF000099), Color(0xFF000044)],
  );

  @override
  String get crestAsset => 'assets/crest/dynamos_crest.png';

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
  List<String> get supportedLanguages => const ['en', 'sn'];


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
    ussdTemplate: '*153*2*{amount}*{momo}#',
    senderName: 'EcoCash',
    countryCode: 'ZW',
  );

  @override
  String get environment => const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');

  @override
  Map<String, bool> get features => {
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
  };
}
