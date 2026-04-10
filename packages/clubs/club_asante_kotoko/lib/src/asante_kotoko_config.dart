import 'dart:ui';

import 'package:core_theme/core_theme.dart';

/// Configuration for Asante Kotoko SC (Ghana).
class AsanteKotokoConfig implements ClubConfig {
  const AsanteKotokoConfig();

  @override
  String get clubId =>
      const String.fromEnvironment('CLUB_ID', defaultValue: '9');

  @override
  String get clubName => 'Asante Kotoko SC';

  @override
  String get appName => 'Asante Kotoko';

  @override
  String get country => 'Ghana';

  @override
  String get countryCode => 'GH';

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*170*';

  @override
  String get currency => 'GHS';

  @override
  String get currencySymbol => 'GH₵';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFFCC0000),
    secondary: Color(0xFFD1D5DB),
    accent: Color(0xFFFFD700),
    gradient: [Color(0xFF990000), Color(0xFF330000)],
  );

  @override
  String get crestAsset => 'assets/crest/asante_kotoko_crest.png';

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
  List<String> get supportedLanguages => const ['en', 'ak', 'tw'];

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
    ussdTemplate: '*170*1*{amount}*{momo}#',
    senderName: 'MTN MoMo',
    countryCode: 'GH',
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
