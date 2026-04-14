import 'dart:ui';

import 'package:core_modules/core_modules.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppModuleRegistry', () {
    test('filters disabled modules from club feature flags', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBiopay: false,
          hasFanClubs: false,
          hasShop: false,
          hasTicketing: false,
        ),
      );

      expect(
        modules.map((module) => module.featureKey),
        orderedEquals(<String>[
          'home',
          'live',
          'fanzone',
          'settings',
          'onboarding',
          'membership',
          'contributions',
          'admin',
        ]),
      );
    });

    test('keeps enabled modules in registry order', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBiopay: true,
          hasFanClubs: true,
          hasShop: true,
          hasTicketing: true,
        ),
      );

      expect(
        modules.map((module) => module.featureKey),
        orderedEquals(<String>[
          'home',
          'live',
          'fanzone',
          'biopay',
          'settings',
          'onboarding',
          'membership',
          'contributions',
          'ticketing',
          'fan_clubs',
          'admin',
          'shop',
        ]),
      );
    });
  });
}

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig({
    required this.hasBiopay,
    required this.hasFanClubs,
    required this.hasShop,
    required this.hasTicketing,
  });

  @override
  final bool hasBiopay;

  @override
  final bool hasFanClubs;

  @override
  final bool hasShop;

  @override
  final bool hasTicketing;

  @override
  String get appName => 'AFRICLUB Test';

  @override
  String get clubId => '1';

  @override
  String get clubName => 'AFRICLUB Test Club';

  @override
  ClubColors get colors => const ClubColors(
    primary: Color(0xFF0038A8),
    secondary: Color(0xFF001F5C),
    accent: Color(0xFFD4A017),
    gradient: <Color>[Color(0xFF001F5C), Color(0xFF0038A8)],
  );

  @override
  String get country => 'Rwanda';

  @override
  String get countryCode => 'RW';

  @override
  String get crestAsset => 'assets/crest/test.png';

  @override
  String get currency => 'RWF';

  @override
  String get currencySymbol => 'RWF';

  @override
  bool get hasChat => false;

  @override
  bool get hasSmsLedger => false;

  @override
  Map<String, bool> get features => <String, bool>{
    'biopay': hasBiopay,
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
  };

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*182*';

  @override
  MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*182*8*1*{amount}*{momo}#',
    senderName: 'MTN MoMo',
    countryCode: 'RW',
  );

  @override
  String get supabaseAnonKey => 'anon';

  @override
  String get supabaseUrl => 'https://example.supabase.co';

  @override
  List<String> get supportedLanguages => const <String>['en'];

  @override
  String get environment => 'test';
}
