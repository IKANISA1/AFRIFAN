import 'dart:async';

import 'package:core_app/startup.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('AppRouter', () {
    test('prefers splash when onboarding routes are registered', () {
      final router = AppRouter(
        modules: <FeatureModule>[
          _OnboardingModule(),
          _HomeModule(),
          _SettingsModule(),
        ],
        shellBuilder: (_, shell) => Material(child: shell),
      );

      expect(router.initialLocation, '/splash');
    });

    test('falls back to the first tab when splash is unavailable', () {
      final router = AppRouter(
        modules: <FeatureModule>[_HomeModule(), _SettingsModule()],
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
            criticalBackendOverride: (_) async => steps.add('critical'),
            deferredBackendOverride: (_) async {
              steps.add('deferred');
              deferredInitialization.complete();
            },
          ),
        );

        const config = _FakeClubConfig(
          hasFanClubs: true,
          hasShop: true,
          hasTicketing: true,
        );

        await coordinator.initialize(config);
        expect(steps, <String>['critical']);

        await tester.pumpWidget(const SizedBox.shrink());
        unawaited(coordinator.scheduleDeferredInitialization(config));
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
          deferNonCriticalBackendInitialization: false,
          criticalBackendOverride: (_) async => steps.add('critical'),
          deferredBackendOverride: (_) async => steps.add('deferred'),
        ),
      );

      await coordinator.initialize(
        const _FakeClubConfig(
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
    required this.hasFanClubs,
    required this.hasShop,
    required this.hasTicketing,
  });

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

class _HomeModule extends FeatureModule {
  @override
  String get featureKey => 'home';

  @override
  List<RouteBase> get routes => const <RouteBase>[];

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/home',
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    builder: (context, state) => const Scaffold(body: Text('Home')),
  );
}

class _OnboardingModule extends FeatureModule {
  @override
  String get featureKey => 'onboarding';

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: '/splash',
      builder: (context, state) => const Scaffold(body: Text('Splash')),
    ),
  ];
}

class _SettingsModule extends FeatureModule {
  @override
  String get featureKey => 'settings';

  @override
  List<RouteBase> get routes => const <RouteBase>[];

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    builder: (context, state) => const Scaffold(body: Text('Settings')),
  );
}
