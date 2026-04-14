import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Vital'O FC (Burundi).
class VitaloConfig implements ClubConfig {
  const VitaloConfig();

  @override
  String get clubId =>
      const String.fromEnvironment('CLUB_ID', defaultValue: '44');

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
  List<String> get supportedLanguages => const ['fr', 'rn', 'en'];

  @override
  bool get hasBiopay => false;

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
    'biopay': hasBiopay,
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
  };
}
