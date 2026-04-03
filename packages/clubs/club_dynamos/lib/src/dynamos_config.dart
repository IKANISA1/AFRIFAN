import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Dynamos FC (Zimbabwe).
class DynamosConfig implements ClubConfig {
  const DynamosConfig();

  @override
  String get clubId =>
      const String.fromEnvironment('CLUB_ID', defaultValue: 'dynamos');

  @override
  String get clubName => 'Dynamos FC';

  @override
  String get appName => 'Dynamos FC';

  @override
  String get country => 'Zimbabwe';

  @override
  String get countryCode => 'ZW';

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*153*';

  @override
  String get currency => 'USD';

  @override
  String get currencySymbol => '\$';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF0000CC),
    secondary: Color(0xFFFFFFFF),
    accent: Color(0xFFFFD700),
    gradient: [Color(0xFF000099), Color(0xFF000044)],
  );

  @override
  String get crestAsset => 'assets/crest/dynamos_crest.png';

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
  List<String> get supportedLanguages => const ['en', 'sn'];

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
    ussdTemplate: '*153*2*{amount}*{momo}#',
    senderName: 'EcoCash',
    countryCode: 'ZW',
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
