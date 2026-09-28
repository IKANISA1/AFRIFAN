import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for CD Costa do Sol (Mozambique), Os Canarinhos.
class CostaDoSolConfig implements ClubConfig {
  const CostaDoSolConfig();

  @override
  String get clubId => ClubConfig.requireDefine(
    const String.fromEnvironment('CLUB_ID'),
    'CLUB_ID',
  );

  @override
  String get clubName => 'CD Costa do Sol';

  @override
  String get appName => 'Costa do Sol';

  @override
  String get country => 'Mozambique';

  @override
  String get countryCode => 'MZ';

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '';

  @override
  String get currency => 'MZN';

  @override
  String get currencySymbol => 'MT';

  @override
  // Provisional yellow/blue UI palette; replace with approved brand values.
  ClubColors get colors => const ClubColors(
    primary: Color(0xFFF6C400),
    secondary: Color(0xFF144B8B),
    accent: Color(0xFF122F5C),
    gradient: [Color(0xFF144B8B), Color(0xFF122F5C)],
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
  bool get hasFanClubs => false;

  @override
  bool get hasShop => false;

  @override
  bool get hasTicketing => false;

  @override
  bool get hasChat => false;

  @override
  MomoConfig get momo => const MomoConfig(ussdTemplate: '', countryCode: 'MZ');

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
