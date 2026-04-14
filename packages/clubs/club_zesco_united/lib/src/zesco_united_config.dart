import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for ZESCO United FC (Zambia).
class ZescoUnitedConfig implements ClubConfig {
  const ZescoUnitedConfig();

  @override
  String get clubId =>
      const String.fromEnvironment('CLUB_ID', defaultValue: '35');

  @override
  String get clubName => 'ZESCO United FC';

  @override
  String get appName => 'ZESCO United';

  @override
  String get country => 'Zambia';

  @override
  String get countryCode => 'ZM';

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*303*';

  @override
  String get currency => 'ZMW';

  @override
  String get currencySymbol => 'ZK';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF006B3F),
    secondary: Color(0xFFFF8C00),
    accent: Color(0xFFD1D5DB),
    gradient: [Color(0xFF004D2C), Color(0xFF002211)],
  );

  @override
  String get crestAsset => 'assets/crest/zesco_united_crest.png';

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
  List<String> get supportedLanguages => const ['en', 'bem'];

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
    ussdTemplate: '*303*{amount}*{momo}#',
    senderName: 'Airtel Money',
    countryCode: 'ZM',
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
