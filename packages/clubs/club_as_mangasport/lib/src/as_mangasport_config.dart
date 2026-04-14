import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for AS Mangasport (Gabon).
class AsMangasportConfig implements ClubConfig {
  const AsMangasportConfig();

  @override
  String get clubId =>
      const String.fromEnvironment('CLUB_ID', defaultValue: '69');

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
  List<String> get supportedLanguages => const ['fr', 'en'];

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
    ussdTemplate: '*126*{amount}*{momo}#',
    senderName: 'Airtel Money',
    countryCode: 'GA',
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
