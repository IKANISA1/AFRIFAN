import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Canon Yaoundé (Cameroon).
class CanonYaoundeConfig implements ClubConfig {
  const CanonYaoundeConfig();

  @override
  String get clubId =>
      const String.fromEnvironment('CLUB_ID', defaultValue: 'canon_yaounde');

  @override
  String get clubName => 'Canon Yaoundé';

  @override
  String get appName => 'Canon Yaoundé';

  @override
  String get country => 'Cameroon';

  @override
  String get countryCode => 'CM';

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
    primary: Color(0xFF006B3F),
    secondary: Color(0xFFCC0000),
    accent: Color(0xFFFFD700),
    gradient: [Color(0xFF004D2C), Color(0xFF1A0000)],
  );

  @override
  String get crestAsset => 'assets/crest/canon_yaounde_crest.png';

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
    ussdTemplate: '*126*1*{amount}*{momo}#',
    senderName: 'Orange Money',
    countryCode: 'CM',
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
