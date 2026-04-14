import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for TP Mazembe (DR Congo).
class TpMazembeConfig implements ClubConfig {
  const TpMazembeConfig();

  @override
  String get clubId =>
      const String.fromEnvironment('CLUB_ID', defaultValue: '4');

  @override
  String get clubName => 'TP Mazembe';

  @override
  String get appName => 'TP Mazembe';

  @override
  String get country => 'DR Congo';

  @override
  String get countryCode => 'CD';

  @override
  String get language => 'fr';

  @override
  String get momoPrefix => '*126*';

  @override
  String get currency => 'CDF';

  @override
  String get currencySymbol => 'FC';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF000000),
    secondary: Color(0xFFD1D5DB),
    accent: Color(0xFFC0C0C0),
    gradient: [Color(0xFF1A1A1A), Color(0xFF000000)],
  );

  @override
  String get crestAsset => 'assets/crest/tp_mazembe_crest.png';

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
  List<String> get supportedLanguages => const ['fr', 'ln', 'en'];

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
    ussdTemplate: '*126*1*1*{amount}*{momo}#',
    senderName: 'm-Pesa',
    countryCode: 'CD',
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
