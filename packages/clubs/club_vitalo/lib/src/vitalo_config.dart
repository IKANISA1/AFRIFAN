import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Vital'O FC (Burundi).
class VitaloConfig implements ClubConfig {
  const VitaloConfig();

  @override
  String get clubId =>
      ClubConfig.requireDefine(
        const String.fromEnvironment('CLUB_ID'),
        'CLUB_ID',
      );

  @override
  String get clubName => "Vital'O FC";

  @override
  String get appName => "Vital'O";

  @override
  String get country => 'Burundi';

  @override
  String get countryCode => 'BI';

  @override
  String get language => 'fr';

  @override
  String get momoPrefix => '*150*';

  @override
  String get currency => 'BIF';

  @override
  String get currencySymbol => 'FBu';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF7B2D8E),
    secondary: Color(0xFFD1D5DB),
    accent: Color(0xFFFFD700),
    gradient: [Color(0xFF5A1E6E), Color(0xFF2D0A3E)],
  );

  @override
  String get crestAsset => 'assets/crest/vitalo_crest.png';

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
  List<String> get supportedLanguages => const ['fr', 'rn', 'en'];


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
    ussdTemplate: '*150*2*{amount}*{momo}#',
    senderName: 'Lumitel MoMo',
    countryCode: 'BI',
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
