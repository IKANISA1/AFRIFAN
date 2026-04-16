import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for AS Mangasport (Gabon).
class AsMangasportConfig implements ClubConfig {
  const AsMangasportConfig();

  @override
  String get clubId =>
      ClubConfig.requireDefine(
        const String.fromEnvironment('CLUB_ID'),
        'CLUB_ID',
      );

  @override
  String get clubName => 'AS Mangasport';

  @override
  String get appName => 'AS Mangasport';

  @override
  String get country => 'Gabon';

  @override
  String get countryCode => 'GA';

  @override
  String get language => 'fr';

  @override
  String get momoPrefix => '*126*';

  @override
  String get currency => 'XAF';

  @override
  String get currencySymbol => 'FCFA';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFFFFD700),
    secondary: Color(0xFF006B3F),
    accent: Color(0xFF000000),
    gradient: [Color(0xFFCCAA00), Color(0xFF004D2C)],
  );

  @override
  String get crestAsset => 'assets/crest/as_mangasport_crest.png';

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
    ussdTemplate: '*126*{amount}*{momo}#',
    senderName: 'Airtel Money',
    countryCode: 'GA',
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
