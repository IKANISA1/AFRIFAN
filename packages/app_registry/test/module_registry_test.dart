import 'package:app_registry/app_registry.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('AppModuleRegistry', () {
    test('filters disabled optional modules from club feature flags', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
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
        ]),
      );
    });

    test('keeps enabled modules in registry order', () {
      final modules = AppModuleRegistry.build(const _FakeClubConfig());

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
          'ticketing',
          'fan_clubs',
          'shop',
        ]),
      );
    });

    test('all enabled modules have unique feature keys', () {
      final modules = AppModuleRegistry.build(const _FakeClubConfig());
      final keys = modules.map((m) => m.featureKey).toList(growable: false);
      expect(keys.toSet().length, keys.length);
    });

    test('challenge module is not registered from club feature flags', () {
      final defaultModules = AppModuleRegistry.build(const _FakeClubConfig());

      expect(
        defaultModules.map((module) => module.featureKey),
        isNot(contains('challenge')),
      );
    });
  });

  group('Tab routes', () {
    late List<FeatureModule> modules;

    setUp(() {
      modules = AppModuleRegistry.build(const _FakeClubConfig());
    });

    test('home, fanzone, and settings are the only tabs', () {
      final tabs = modules
          .where((m) => m.tabRoute != null)
          .map((m) => (path: m.tabRoute!.path, label: m.tabRoute!.label))
          .toList(growable: false);
      expect(
        tabs,
        orderedEquals(<({String path, String label})>[
          (path: '/home', label: 'Home'),
          (path: '/fanzone', label: 'Fan Zone'),
          (path: '/settings', label: 'Settings'),
        ]),
      );
    });

    test('non-tab modules stay off the bottom navigation', () {
      for (final featureKey in const <String>[
        'live',
        'onboarding',
        'membership',
        'contributions',
        'ticketing',
        'fan_clubs',
        'shop',
      ]) {
        final module = modules.firstWhere((m) => m.featureKey == featureKey);
        expect(
          module.tabRoute,
          isNull,
          reason: '$featureKey should not be a tab',
        );
      }
    });
  });

  group('Route graph', () {
    late List<FeatureModule> modules;

    setUp(() {
      modules = AppModuleRegistry.build(const _FakeClubConfig());
    });

    test('builds a valid GoRouter', () {
      expect(
        () => AppRouter(
          modules: modules,
          initialLocation: '/home',
          shellBuilder: (_, __) => const SizedBox.shrink(),
        ),
        returnsNormally,
      );
    });

    test('router tabs stay aligned with the reduced tab surface', () {
      final router = AppRouter(
        modules: modules,
        initialLocation: '/home',
        shellBuilder: (_, __) => const SizedBox.shrink(),
      );
      final tabs = router.tabs
          .map((tab) => (path: tab.path, label: tab.label))
          .toList(growable: false);
      expect(
        tabs,
        orderedEquals(<({String path, String label})>[
          (path: '/home', label: 'Home'),
          (path: '/fanzone', label: 'Fan Zone'),
          (path: '/settings', label: 'Settings'),
        ]),
      );
    });
  });

  group('Admin routes', () {
    test('mobile admin is not registered unless explicitly opted in', () {
      final modules = AppModuleRegistry.build(const _FakeClubConfig());

      expect(
        modules.map((module) => module.featureKey),
        isNot(contains('admin')),
      );
    });

    test(
      '/admin retains core operations routes for explicit internal builds',
      () {
        final modules = AppModuleRegistry.build(
          const _FakeClubConfig(
            hasFanClubs: false,
            hasShop: false,
            hasTicketing: false,
            hasMobileAdmin: true,
          ),
        );
        final admin = modules.firstWhere((m) => m.featureKey == 'admin');
        final adminRoute = admin.routes.whereType<GoRoute>().firstWhere(
          (r) => r.path == '/admin',
        );
        final subPaths = adminRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();

        expect(
          subPaths,
          containsAll(<String>{
            'cms',
            'matches',
            'contributions',
            'notifications',
            'sms-monitor',
          }),
        );
      },
    );
  });

  group('Contributions routes', () {
    test('/contribute exposes only public initiative flows', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasFanClubs: false,
          hasShop: false,
          hasTicketing: false,
        ),
      );
      final contributions = modules.firstWhere(
        (m) => m.featureKey == 'contributions',
      );
      final root = contributions.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/contribute',
      );
      final subPaths = root.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();

      expect(
        subPaths,
        containsAll(<String>{'projects', 'groups', 'group/:groupId'}),
      );
      expect(subPaths, isNot(contains('create')));
      expect(subPaths, isNot(contains('join')));
    });

    test('group detail nesting exposes statement only', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasFanClubs: false,
          hasShop: false,
          hasTicketing: false,
        ),
      );
      final contributions = modules.firstWhere(
        (m) => m.featureKey == 'contributions',
      );
      final root = contributions.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/contribute',
      );
      final groupRoute = root.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == 'group/:groupId',
      );
      final subPaths = groupRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();

      expect(subPaths, contains('statement'));
      expect(subPaths, isNot(contains('chat')));
      expect(subPaths, isNot(contains('settings')));
    });
  });

  group('Fan clubs routes', () {
    test('/fan-clubs exposes detail only; creation is admin-managed', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasFanClubs: true,
          hasShop: false,
          hasTicketing: false,
        ),
      );
      final fanClubs = modules.firstWhere((m) => m.featureKey == 'fan_clubs');
      final root = fanClubs.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/fan-clubs',
      );
      final subPaths = root.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();

      expect(subPaths, contains(':clubId'));
      expect(subPaths, isNot(contains('create')));
    });
  });
}

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig({
    this.hasFanClubs = true,
    this.hasShop = true,
    this.hasTicketing = true,
    this.hasMobileAdmin = false,
  });

  @override
  final bool hasFanClubs;
  @override
  final bool hasShop;
  @override
  final bool hasTicketing;
  final bool hasMobileAdmin;
  @override
  String get appName => 'AFRICLUB Test';
  @override
  String get clubId => '1';
  @override
  String get clubName => 'AFRICLUB Test Club';
  @override
  ClubColors get colors => const ClubColors(
    primary: ColorTokens.referenceAccountBlue,
    secondary: ColorTokens.referenceChromeBlack,
    accent: ColorTokens.referenceRewardsVioletHot,
    gradient: <Color>[
      ColorTokens.referenceChromeBlack,
      ColorTokens.referenceAccountBlue,
    ],
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
  String get environment => 'test';
  @override
  Map<String, bool> get features => <String, bool>{
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
    'mobile_admin': hasMobileAdmin,
  };
  @override
  String get language => 'en';
  @override
  MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*182*{amount}*{momo}#',
    senderName: 'Test',
    countryCode: 'RW',
  );
  @override
  String get momoPrefix => '*182*';
  @override
  String get supabaseAnonKey => 'anon-key';
  @override
  String get supabaseUrl => 'https://example.supabase.co';
  @override
  List<String> get supportedLanguages => const <String>['en'];
}
