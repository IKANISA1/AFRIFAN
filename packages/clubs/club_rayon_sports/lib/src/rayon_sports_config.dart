import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Rayon Sports FC (Rwanda).
///
/// "Gikundiro" — the official Rayon Sports FC supporter app.
/// Colors:
/// - Primary #0038A8 (Gikundiro Blue)
/// - Secondary #001742 (Deep Navy)
/// - Accent #D9B24C (Trophy Gold)
class RayonSportsConfig implements ClubConfig {
  const RayonSportsConfig();

  @override
  String get clubId => ClubConfig.requireDefine(
    const String.fromEnvironment('CLUB_ID'),
    'CLUB_ID',
  );

  @override
  String get clubName => 'Rayon Sports FC';

  @override
  String get appName => 'Gikundiro';

  @override
  String get country => 'Rwanda';

  @override
  String get countryCode => 'RW';

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*182*';

  @override
  String get currency => 'RWF';

  @override
  String get currencySymbol => 'RWF';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF0038A8), // Rayon Blue
    secondary: Color(0xFF001742), // Deep Navy
    accent: Color(0xFFD9B24C), // Trophy Gold
    gradient: [Color(0xFF001742), Color(0xFF0038A8)],
  );

  /// Supabase URL — MUST be provided via `--dart-define=SUPABASE_URL=...`.
  /// Never commit default values for backend credentials.
  @override
  String get supabaseUrl {
    return ClubConfig.requireDefine(
      const String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_URL',
    );
  }

  /// Supabase anon key — MUST be provided via `--dart-define=SUPABASE_ANON_KEY=...`.
  /// Never commit default values for backend credentials.
  @override
  String get supabaseAnonKey {
    return ClubConfig.requireDefine(
      const String.fromEnvironment('SUPABASE_ANON_KEY'),
      'SUPABASE_ANON_KEY',
    );
  }

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
    ussdTemplate: '*182*8*1*{amount}*{momo}#',
    countryCode: 'RW',
  );

  @override
  String get environment =>
      const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');

  @override
  Map<String, bool> get features => {
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'google_wallet_tickets': true,
    'chat': hasChat,
  };
}
