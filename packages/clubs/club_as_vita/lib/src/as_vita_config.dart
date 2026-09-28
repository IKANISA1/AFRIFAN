import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for AS Vita Club (DR Congo).
class AsVitaConfig implements ClubConfig {
  const AsVitaConfig();

  @override
  String get clubId => ClubConfig.requireDefine(
    const String.fromEnvironment('CLUB_ID'),
    'CLUB_ID',
  );

  @override
  String get clubName => 'AS Vita Club';

  @override
  String get appName => 'AS Vita Club';

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
    primary: Color(0xFF006400),
    secondary: Color(0xFF000000),
    accent: Color(0xFFFFD700),
    gradient: [Color(0xFF004D00), Color(0xFF002200)],
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
  MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*126*1*1*{amount}*{momo}#',
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
  };
}
