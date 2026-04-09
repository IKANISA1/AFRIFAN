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
  String get clubId =>
      const String.fromEnvironment('CLUB_ID', defaultValue: '24');

  @override
  String get clubName => 'Rayon Sports FC';

  @override
  String get appName => 'Gikundiro';

  @override
  String get country => 'Rwanda';

  @override
  String get countryCode => 'RW';

  @override
  String get language => 'rw';

  @override
  String get momoPrefix => '*182*';

  @override
  String get currency => 'RWF';

  @override
  String get currencySymbol => 'FRw';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF0038A8), // Rayon Blue
    secondary: Color(0xFF001742), // Deep Navy
    accent: Color(0xFFD9B24C), // Trophy Gold
    gradient: [Color(0xFF001742), Color(0xFF0038A8)],
  );

  @override
  String get crestAsset => 'assets/crest/rayon_sports_crest.png';

  @override
  String get supabaseUrl => const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mmpbzcdhfvplxplnfucy.supabase.co',
  );

  @override
  String get supabaseAnonKey => const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tcGJ6Y2RoZnZwbHhwbG5mdWN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNDM2MTYsImV4cCI6MjA4ODcxOTYxNn0.Ojw-vQ6aEJjyuZU4nReP4ynxJ2XjD5L6n6TxhLlzeeQ',
  );

  @override
  List<String> get supportedLanguages => const ['rw', 'fr', 'en'];

  @override
  bool get hasBiopay => true;

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
    ussdTemplate: '*182*8*1*{amount}*{momo}#',
    senderName: 'MTN MoMo',
    countryCode: 'RW',
  );

  @override
  Map<String, bool> get features => {
    'biopay': hasBiopay,
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
  };
}
