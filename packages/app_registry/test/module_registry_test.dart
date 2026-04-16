import 'dart:ui';

import 'package:app_registry/app_registry.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('AppModuleRegistry', () {
    test('filters disabled modules from club feature flags', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false,
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
          hasBioPay: true,
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
          'BioPay',
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

  group('Module featureKey uniqueness', () {
    test('all 12 modules have unique featureKeys', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: true,
          hasFanClubs: true,
          hasShop: true,
          hasTicketing: true,
        ),
      );
      final keys = modules.map((m) => m.featureKey).toList();
      expect(keys.toSet().length, keys.length, reason: 'Duplicate featureKeys');
    });
  });

  group('Tab route validation', () {
    late List<FeatureModule> modules;

    setUp(() {
      modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: true,
          hasFanClubs: true,
          hasShop: true,
          hasTicketing: true,
        ),
      );
    });

    test('home tab exists at /home', () {
      expect(modules.any((m) => m.tabRoute?.path == '/home'), isTrue);
    });

    test('settings tab exists at /settings', () {
      expect(modules.any((m) => m.tabRoute?.path == '/settings'), isTrue);
    });

    test('fanzone is NOT a tab (standalone module)', () {
      expect(modules.any((m) => m.tabRoute?.path == '/fanzone'), isFalse);
    });

    test('live is NOT a tab (standalone module)', () {
      expect(modules.any((m) => m.tabRoute?.path == '/live'), isFalse);
    });

    test('BioPay tab exists at /BioPay', () {
      expect(modules.any((m) => m.tabRoute?.path == '/BioPay'), isTrue);
    });

    test('has exactly 3 bottom nav tabs (Home, BioPay, Settings)', () {
      final tabs = modules.where((m) => m.tabRoute != null);
      expect(tabs.length, 3);
    });

    test('all tab paths start with /', () {
      for (final module in modules) {
        final tab = module.tabRoute;
        if (tab == null) continue;
        expect(
          tab.path.startsWith('/'),
          isTrue,
          reason: '${module.featureKey} tab path must start with /',
        );
      }
    });

    test('all tab paths are unique', () {
      final tabPaths = modules
          .where((m) => m.tabRoute != null)
          .map((m) => m.tabRoute!.path)
          .toList();
      expect(
        tabPaths.toSet().length,
        tabPaths.length,
        reason: 'Duplicate tab paths found',
      );
    });

    test('tab labels are non-empty', () {
      for (final module in modules) {
        final tab = module.tabRoute;
        if (tab == null) continue;
        expect(
          tab.label.isNotEmpty,
          isTrue,
          reason: '${module.featureKey} tab label must not be empty',
        );
      }
    });
  });

  group('Non-tab module validation', () {
    late List<FeatureModule> modules;

    setUp(() {
      modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: true,
          hasFanClubs: true,
          hasShop: true,
          hasTicketing: true,
        ),
      );
    });

    test('onboarding is not a tab', () {
      final m = modules.firstWhere((m) => m.featureKey == 'onboarding');
      expect(m.tabRoute, isNull);
    });

    test('admin is not a tab', () {
      final m = modules.firstWhere((m) => m.featureKey == 'admin');
      expect(m.tabRoute, isNull);
    });

    test('membership is not a tab', () {
      final m = modules.firstWhere((m) => m.featureKey == 'membership');
      expect(m.tabRoute, isNull);
    });

    test('contributions is not a tab', () {
      final m = modules.firstWhere((m) => m.featureKey == 'contributions');
      expect(m.tabRoute, isNull);
    });

    test('shop is not a tab', () {
      final m = modules.firstWhere((m) => m.featureKey == 'shop');
      expect(m.tabRoute, isNull);
    });

    test('ticketing is not a tab', () {
      final m = modules.firstWhere((m) => m.featureKey == 'ticketing');
      expect(m.tabRoute, isNull);
    });

    test('fan_clubs is not a tab', () {
      final m = modules.firstWhere((m) => m.featureKey == 'fan_clubs');
      expect(m.tabRoute, isNull);
    });

    test('fanzone is not a tab (standalone)', () {
      final m = modules.firstWhere((m) => m.featureKey == 'fanzone');
      expect(m.tabRoute, isNull);
    });

    test('live is not a tab (standalone)', () {
      final m = modules.firstWhere((m) => m.featureKey == 'live');
      expect(m.tabRoute, isNull);
    });
  });

  group('Route graph construction', () {
    late List<FeatureModule> modules;

    setUp(() {
      modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: true,
          hasFanClubs: true,
          hasShop: true,
          hasTicketing: true,
        ),
      );
    });

    test('builds a valid GoRouter without errors', () {
      expect(
        () => AppRouter(
          modules: modules,
          initialLocation: '/home',
          shellBuilder: (_, __) => const SizedBox.shrink(),
        ),
        returnsNormally,
      );
    });

    test('initial location resolves to /home when specified', () {
      final router = AppRouter(
        modules: modules,
        initialLocation: '/home',
        shellBuilder: (_, __) => const SizedBox.shrink(),
      );
      expect(router.initialLocation, '/home');
    });

    test('tabs getter returns exactly 3 tab routes', () {
      final router = AppRouter(
        modules: modules,
        initialLocation: '/home',
        shellBuilder: (_, __) => const SizedBox.shrink(),
      );
      final tabPaths = router.tabs.map((t) => t.path).toSet();
      expect(tabPaths, containsAll(['/home', '/settings', '/BioPay']));
      expect(tabPaths, isNot(contains('/fanzone')));
      expect(tabPaths, isNot(contains('/live')));
      expect(router.tabs, hasLength(3));
    });
  });

  group('Feature flag gating', () {
    test('disabling BioPay removes BioPay module', () {
      final config = _FakeClubConfig(
        hasBioPay: false, hasFanClubs: true, hasShop: true, hasTicketing: true,
      );
      final mods = AppModuleRegistry.build(config);
      expect(mods.any((m) => m.featureKey == 'BioPay'), isFalse);
    });

    test('disabling fan_clubs removes fan_clubs module', () {
      final config = _FakeClubConfig(
        hasBioPay: true, hasFanClubs: false, hasShop: true, hasTicketing: true,
      );
      final mods = AppModuleRegistry.build(config);
      expect(mods.any((m) => m.featureKey == 'fan_clubs'), isFalse);
    });

    test('disabling shop removes shop module', () {
      final config = _FakeClubConfig(
        hasBioPay: true, hasFanClubs: true, hasShop: false, hasTicketing: true,
      );
      final mods = AppModuleRegistry.build(config);
      expect(mods.any((m) => m.featureKey == 'shop'), isFalse);
    });

    test('disabling ticketing removes ticketing module', () {
      final config = _FakeClubConfig(
        hasBioPay: true, hasFanClubs: true, hasShop: true, hasTicketing: false,
      );
      final mods = AppModuleRegistry.build(config);
      expect(mods.any((m) => m.featureKey == 'ticketing'), isFalse);
    });

    test('core modules survive when optional features disabled', () {
      final config = _FakeClubConfig(
        hasBioPay: false, hasFanClubs: false, hasShop: false, hasTicketing: false,
      );
      final mods = AppModuleRegistry.build(config);
      expect(mods.any((m) => m.featureKey == 'home'), isTrue);
      expect(mods.any((m) => m.featureKey == 'settings'), isTrue);
      expect(mods.any((m) => m.featureKey == 'fanzone'), isTrue);
      expect(mods.any((m) => m.featureKey == 'live'), isTrue);
      expect(mods.any((m) => m.featureKey == 'onboarding'), isTrue);
      expect(mods.any((m) => m.featureKey == 'admin'), isTrue);
    });
  });

  group('Onboarding routes', () {
    test('provides /splash, /onboarding, /auth/phone', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: false, hasShop: false, hasTicketing: false,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'onboarding');
      final paths = m.routes.whereType<GoRoute>().map((r) => r.path).toSet();
      expect(paths, containsAll(['/splash', '/onboarding', '/auth/phone']));
    });
  });

  group('Admin routes', () {
    test('/admin has CMS, matches, contributions, notifications, sms-monitor sub-routes', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: false, hasShop: false, hasTicketing: false,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'admin');
      final adminRoute = m.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/admin',
      );
      final subPaths = adminRoute.routes.whereType<GoRoute>().map(
        (r) => r.path,
      ).toSet();
      expect(
        subPaths,
        containsAll(['cms', 'matches', 'contributions', 'notifications', 'sms-monitor']),
      );
    });
  });

  group('Contributions routes', () {
    test('/contribute has projects, groups, create, join, group/:groupId sub-routes', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: false, hasShop: false, hasTicketing: false,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'contributions');
      final root = m.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/contribute',
      );
      final subPaths = root.routes.whereType<GoRoute>().map(
        (r) => r.path,
      ).toSet();
      expect(subPaths, containsAll(['projects', 'groups', 'create', 'join', 'group/:groupId']));
    });

    test('group/:groupId has chat, settings, statement sub-routes', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: false, hasShop: false, hasTicketing: false,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'contributions');
      final root = m.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/contribute',
      );
      final groupRoute = root.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == 'group/:groupId',
      );
      final subPaths = groupRoute.routes.whereType<GoRoute>().map(
        (r) => r.path,
      ).toSet();
      expect(subPaths, containsAll(['chat', 'settings', 'statement']));
    });
  });

  group('Shop routes', () {
    test('/shop has cart and product/:productId sub-routes', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: false, hasShop: true, hasTicketing: false,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'shop');
      final root = m.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/shop',
      );
      final subPaths = root.routes.whereType<GoRoute>().map(
        (r) => r.path,
      ).toSet();
      expect(subPaths, containsAll(['cart', 'product/:productId']));
    });
  });

  group('Ticketing routes', () {
    test('provides /tickets, /my-tickets, /e-ticket/:id', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: false, hasShop: false, hasTicketing: true,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'ticketing');
      final paths = m.routes.whereType<GoRoute>().map((r) => r.path).toSet();
      expect(paths, containsAll(['/tickets', '/my-tickets', '/e-ticket/:id']));
    });

    test('/tickets has detail/:id and map/:id sub-routes', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: false, hasShop: false, hasTicketing: true,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'ticketing');
      final root = m.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/tickets',
      );
      final subPaths = root.routes.whereType<GoRoute>().map(
        (r) => r.path,
      ).toSet();
      expect(subPaths, containsAll(['detail/:id', 'map/:id']));
    });
  });

  group('Fanzone sub-routes', () {
    late FeatureModule fanzone;

    setUp(() {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: true, hasFanClubs: true, hasShop: true, hasTicketing: true,
        ),
      );
      fanzone = modules.firstWhere((m) => m.featureKey == 'fanzone');
    });

    test('has all 21 top-level sub-routes', () {
      final fanzoneRoute = fanzone.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/fanzone',
      );
      final subPaths = fanzoneRoute.routes.whereType<GoRoute>().map(
        (r) => r.path,
      ).toSet();
      expect(
        subPaths,
        containsAll([
          'fixtures', 'live', 'my',
          'match/:fixtureId', 'wallet', 'rewards', 'history',
          'leaderboard', 'notifications',
          'challenges', 'badges', 'streak', 'jackpot',
          'share', 'friends', 'challenge',
          'league', 'league/:competitionSlug',
          'standings/:competitionSlug', 'team/:teamSlug',
          'club-zone',
        ]),
      );
    });

    test('my → :predictionId → settlement nesting', () {
      final fanzoneRoute = fanzone.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/fanzone',
      );
      final myRoute = fanzoneRoute.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == 'my',
      );
      final detailRoute = myRoute.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == ':predictionId',
      );
      final settlementPaths = detailRoute.routes.whereType<GoRoute>().map(
        (r) => r.path,
      );
      expect(settlementPaths, contains('settlement'));
    });
  });

  group('BioPay routes', () {
    test('/BioPay has all expected sub-routes', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: true, hasFanClubs: false, hasShop: false, hasTicketing: false,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'BioPay');
      final subPaths = m.routes.whereType<GoRoute>().map(
        (r) => r.path,
      ).toSet();
      expect(subPaths, containsAll([
        'profile', 'register', 'review', 'result',
        'recovery', 'scan', 'qr', 'nfc',
      ]));
    });
  });

  group('Settings routes', () {
    test('/settings has edit-profile, notifications, privacy sub-routes', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: false, hasShop: false, hasTicketing: false,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'settings');
      final subPaths = m.routes.whereType<GoRoute>().map(
        (r) => r.path,
      ).toSet();
      expect(subPaths, containsAll(['edit-profile', 'notifications', 'privacy']));
    });

    test('settings provides /profile_setup standalone route', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: false, hasShop: false, hasTicketing: false,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'settings');
      final standalonePaths = m.standaloneRoutes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(standalonePaths, contains('/profile_setup'));
    });
  });

  group('Membership routes', () {
    test('provides /membership, /membership/fans, /membership/tier/:tierId', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: false, hasShop: false, hasTicketing: false,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'membership');
      final paths = m.routes.whereType<GoRoute>().map((r) => r.path).toSet();
      expect(paths, containsAll(['/membership', '/membership/fans']));
    });
  });

  group('Fan Clubs routes', () {
    test('/fan-clubs has create and :clubId sub-routes', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: true, hasShop: false, hasTicketing: false,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'fan_clubs');
      final root = m.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/fan-clubs',
      );
      final subPaths = root.routes.whereType<GoRoute>().map(
        (r) => r.path,
      ).toSet();
      expect(subPaths, containsAll(['create', ':clubId']));
    });
  });

  group('Live routes', () {
    test('/live has news/:articleId sub-route', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(
          hasBioPay: false, hasFanClubs: false, hasShop: false, hasTicketing: false,
        ),
      );
      final m = modules.firstWhere((m) => m.featureKey == 'live');
      final subPaths = m.routes.whereType<GoRoute>().map(
        (r) => r.path,
      ).toSet();
      expect(subPaths, contains('news/:articleId'));
    });
  });
}

// ── Test Config ──────────────────────────────────────────────────────

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig({
    required this.hasBioPay,
    required this.hasFanClubs,
    required this.hasShop,
    required this.hasTicketing,
  });

  @override final bool hasBioPay;
  @override final bool hasFanClubs;
  @override final bool hasShop;
  @override final bool hasTicketing;
  @override String get appName => 'AFRICLUB Test';
  @override String get clubId => '1';
  @override String get clubName => 'AFRICLUB Test Club';
  @override ClubColors get colors => const ClubColors(
    primary: Color(0xFF0038A8),
    secondary: Color(0xFF001F5C),
    accent: Color(0xFFD4A017),
    gradient: <Color>[Color(0xFF001F5C), Color(0xFF0038A8)],
  );
  @override String get country => 'Rwanda';
  @override String get countryCode => 'RW';
  @override String get crestAsset => 'assets/crest/test.png';
  @override String get currency => 'RWF';
  @override String get currencySymbol => 'RWF';
  @override bool get hasChat => false;
  @override bool get hasSmsLedger => false;
  @override Map<String, bool> get features => <String, bool>{
    'BioPay': hasBioPay,
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
  };
  @override String get language => 'en';
  @override String get momoPrefix => '*182*';
  @override MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*182*8*1*{amount}*{momo}#',
    senderName: 'MTN MoMo',
    countryCode: 'RW',
  );
  @override String get supabaseAnonKey => 'anon';
  @override String get supabaseUrl => 'https://example.supabase.co';
  @override List<String> get supportedLanguages => const <String>['en'];
  @override String get environment => 'test';
}
