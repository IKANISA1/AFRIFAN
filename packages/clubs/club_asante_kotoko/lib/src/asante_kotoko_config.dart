import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Asante Kotoko SC (Ghana).
class AsanteKotokoConfig implements ClubConfig {
  const AsanteKotokoConfig();

  @override
  String get clubId =>
      ClubConfig.requireDefine(
        const String.fromEnvironment('CLUB_ID'),
        'CLUB_ID',
      );

  @override
  String get clubName => 'Asante Kotoko SC';

  @override
  String get appName => 'Asante Kotoko';

  @override
  String get country => 'Ghana';

  @override
  String get countryCode => 'GH';

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*170*';

  @override
  String get currency => 'GHS';

  @override
  String get currencySymbol => 'GH₵';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFFCC0000),
    secondary: Color(0xFFD1D5DB),
    accent: Color(0xFFFFD700),
    gradient: [Color(0xFF990000), Color(0xFF330000)],
  );

  @override
  String get crestAsset => 'assets/crest/asante_kotoko_crest.png';

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
  List<String> get supportedLanguages => const ['en', 'ak', 'tw'];

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
    ussdTemplate: '*170*1*{amount}*{momo}#',
    senderName: 'MTN MoMo',
    countryCode: 'GH',
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
