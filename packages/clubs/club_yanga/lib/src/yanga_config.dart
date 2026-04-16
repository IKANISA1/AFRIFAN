import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Young Africans (Yanga) (Tanzania).
class YangaConfig implements ClubConfig {
  const YangaConfig();

  @override
  String get clubId =>
      ClubConfig.requireDefine(
        const String.fromEnvironment('CLUB_ID'),
        'CLUB_ID',
      );

  @override
  String get clubName => 'Young Africans (Yanga)';

  @override
  String get appName => 'Yanga SC';

  @override
  String get country => 'Tanzania';

  @override
  String get countryCode => 'TZ';

  @override
  String get language => 'sw';

  @override
  String get momoPrefix => '*150*';

  @override
  String get currency => 'TZS';

  @override
  String get currencySymbol => 'TSh';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF006B3F),
    secondary: Color(0xFFFFD700),
    accent: Color(0xFFD1D5DB),
    gradient: [Color(0xFF004D2C), Color(0xFF002211)],
  );

  @override
  String get crestAsset => 'assets/crest/yanga_crest.png';

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
  List<String> get supportedLanguages => const ['sw', 'en'];

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
    ussdTemplate: '*150*00*{amount}*{momo}#',
    senderName: 'Tigo Pesa',
    countryCode: 'TZ',
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
