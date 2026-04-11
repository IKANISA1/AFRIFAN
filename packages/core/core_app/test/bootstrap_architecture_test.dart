import 'dart:async';

import 'package:core_app/src/module_registry.dart';
import 'package:core_app/src/startup_coordinator.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_home/feat_home.dart';
import 'package:feat_onboarding/feat_onboarding.dart';
import 'package:feat_settings/feat_settings.dart';
import 'package:flutter/material.dart';
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
          'settings',
          'onboarding',
          'membership',
          'gamification',
          'contributions',
          'fantasy',
          'live',
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
          'biopay',
          'settings',
          'onboarding',
          'membership',
          'gamification',
          'contributions',
          'ticketing',
          'fan_clubs',
          'fantasy',
          'live',
          'admin',
          'shop',
        ]),
      );
    });
  });

  group('AppRouter', () {
    test('prefers splash when onboarding routes are registered', () {
      final router = AppRouter(
        modules: <FeatureModule>[
          OnboardingModule(),
          HomeModule(),
          SettingsModule(),
        ],
        shellBuilder: (_, shell) => Material(child: shell),
      );

      expect(router.initialLocation, '/splash');
    });

    test('falls back to the first tab when splash is unavailable', () {
      final router = AppRouter(
        modules: <FeatureModule>[HomeModule(), SettingsModule()],
        shellBuilder: (_, shell) => Material(child: shell),
      );

      expect(router.initialLocation, '/home');
    });
  });

  group('AppStartupCoordinator', () {
    testWidgets(
      'defers non-critical backend initialization until after first frame',
      (tester) async {
        final steps = <String>[];
        final deferredInitialization = Completer<void>();
        final coordinator = AppStartupCoordinator(
          options: AppStartupOptions(
            configureDeviceChrome: false,
            initializePersistence: false,
            initializeSmsAutoread: false,
            criticalBackendOverride: (_) async => steps.add('critical'),
            deferredBackendOverride: (_) async {
              steps.add('deferred');
              deferredInitialization.complete();
            },
          ),
        );

        const config = _FakeClubConfig(
          hasBiopay: true,
          hasFanClubs: true,
          hasShop: true,
          hasTicketing: true,
        );

        await coordinator.initialize(config);
        expect(steps, <String>['critical']);

        await tester.pumpWidget(const SizedBox.shrink());
        coordinator.scheduleDeferredInitialization(config);
        expect(steps, <String>['critical']);

        await tester.pump();
        await deferredInitialization.future.timeout(const Duration(seconds: 1));
        expect(steps, <String>['critical', 'deferred']);
      },
    );

    testWidgets(
      'coalesces repeated deferred initialization requests into a single run',
      (tester) async {
        final steps = <String>[];
        final deferredInitialization = Completer<void>();
        final coordinator = AppStartupCoordinator(
          options: AppStartupOptions(
            configureDeviceChrome: false,
            initializePersistence: false,
            initializeSmsAutoread: false,
            criticalBackendOverride: (_) async => steps.add('critical'),
            deferredBackendOverride: (_) async {
              steps.add('deferred');
              if (!deferredInitialization.isCompleted) {
                deferredInitialization.complete();
              }
            },
          ),
        );

        const config = _FakeClubConfig(
          hasBiopay: true,
          hasFanClubs: true,
          hasShop: true,
          hasTicketing: true,
        );

        await coordinator.initialize(config);
        await tester.pumpWidget(const SizedBox.shrink());

        final first = coordinator.scheduleDeferredInitialization(config);
        final second = coordinator.scheduleDeferredInitialization(config);

        expect(first, same(second));

        await tester.pump();
        await deferredInitialization.future.timeout(const Duration(seconds: 1));
        expect(steps, <String>['critical', 'deferred']);
      },
    );

    testWidgets('runs deferred backend inline when deferral is disabled', (
      tester,
    ) async {
      final steps = <String>[];
      final coordinator = AppStartupCoordinator(
        options: AppStartupOptions(
          configureDeviceChrome: false,
          initializePersistence: false,
          initializeSmsAutoread: false,
          deferNonCriticalBackendInitialization: false,
          criticalBackendOverride: (_) async => steps.add('critical'),
          deferredBackendOverride: (_) async => steps.add('deferred'),
        ),
      );

      await coordinator.initialize(
        const _FakeClubConfig(
          hasBiopay: true,
          hasFanClubs: true,
          hasShop: true,
          hasTicketing: true,
        ),
      );

      expect(steps, <String>['critical', 'deferred']);
      await tester.pumpWidget(const SizedBox.shrink());
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
  String get currencySymbol => 'FRw';

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
}
