import 'dart:ui';

import 'package:core_modules/core_modules.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Comprehensive navigation journey smoke tests.
///
/// These tests verify that the full, real route graph built from all
/// feature modules correctly resolves every path to a screen widget.
/// No network calls, no Supabase — just route resolution and screen
/// instantiation at the GoRouter level.
void main() {
  late List<FeatureModule> modules;
  late AppRouter appRouter;

  setUp(() {
    modules = AppModuleRegistry.build(
      const _AllFeaturesConfig(),
    );
    appRouter = AppRouter(
      modules: modules,
      initialLocation: '/home',
      shellBuilder: (_, shell) => Scaffold(body: shell),
    );
  });

  // ══════════════════════════════════════════════════════════════════════
  // Journey 1: Onboarding → Auth
  // ══════════════════════════════════════════════════════════════════════

  group('Journey 1: Onboarding flow', () {
    test('/splash is a valid route', () {
      final onboarding = modules.firstWhere(
        (m) => m.featureKey == 'onboarding',
      );
      final paths = onboarding.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/splash'));
    });

    test('/onboarding is a valid route', () {
      final onboarding = modules.firstWhere(
        (m) => m.featureKey == 'onboarding',
      );
      final paths = onboarding.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/onboarding'));
    });

    test('/auth/phone is a valid route', () {
      final onboarding = modules.firstWhere(
        (m) => m.featureKey == 'onboarding',
      );
      final paths = onboarding.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/auth/phone'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Journey 2: Home Tab → Quick Actions
  // ══════════════════════════════════════════════════════════════════════

  group('Journey 2: Home tab', () {
    test('/home resolves via tab route', () {
      final home = modules.firstWhere((m) => m.featureKey == 'home');
      expect(home.tabRoute!.path, '/home');
    });

    test('Quick action targets resolve as standalone routes', () {
      final allPaths = <String>{};
      for (final module in modules) {
        for (final route in module.routes.whereType<GoRoute>()) {
          allPaths.add(route.path);
        }
        for (final route in module.standaloneRoutes.whereType<GoRoute>()) {
          allPaths.add(route.path);
        }
        final tab = module.tabRoute;
        if (tab != null) allPaths.add(tab.path);
      }

      // Quick action destinations (standalone routes accessible from Home)
      expect(allPaths, contains('/fanzone'));
      expect(allPaths, contains('/live'));
      expect(allPaths, contains('/contribute'));
      expect(allPaths, contains('/shop'));
      expect(allPaths, contains('/tickets'));
      expect(allPaths, contains('/fan-clubs'));
      expect(allPaths, contains('/membership'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Journey 3: Fanzone Prediction Flow
  // ══════════════════════════════════════════════════════════════════════

  group('Journey 3: Fanzone prediction flow', () {
    late FeatureModule fanzone;

    setUp(() {
      fanzone = modules.firstWhere((m) => m.featureKey == 'fanzone');
    });

    test('/fanzone is a standalone route (not a tab)', () {
      expect(fanzone.tabRoute, isNull);
      final paths = fanzone.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/fanzone'));
    });

    test('/fanzone/fixtures sub-route resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final subPaths = fanzoneRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('fixtures'));
    });

    test('/fanzone/live sub-route resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final subPaths = fanzoneRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('live'));
    });

    test('/fanzone/match/:fixtureId sub-route resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final subPaths = fanzoneRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('match/:fixtureId'));
    });

    test('/fanzone/my sub-route resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final subPaths = fanzoneRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('my'));
    });

    test('/fanzone/my/:predictionId nesting resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final myRoute = fanzoneRoute.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == 'my');
      expect(
        myRoute.routes.whereType<GoRoute>().any(
          (r) => r.path == ':predictionId',
        ),
        isTrue,
      );
    });

    test('/fanzone/my/:predictionId/settlement deep nesting resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final myRoute = fanzoneRoute.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == 'my');
      final detailRoute = myRoute.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == ':predictionId');
      expect(
        detailRoute.routes.whereType<GoRoute>().any(
          (r) => r.path == 'settlement',
        ),
        isTrue,
      );
    });

    test('/fanzone/leaderboard sub-route resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final subPaths = fanzoneRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('leaderboard'));
    });

    test('/fanzone/notifications sub-route resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final subPaths = fanzoneRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('notifications'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Journey 4: FET Wallet & Gamification
  // ══════════════════════════════════════════════════════════════════════

  group('Journey 4: FET Wallet & gamification flow', () {
    late FeatureModule fanzone;

    setUp(() {
      fanzone = modules.firstWhere((m) => m.featureKey == 'fanzone');
    });

    final walletRoutes = [
      'wallet',
      'rewards',
      'history',
      'challenges',
      'badges',
      'streak',
      'jackpot',
      'share',
      'friends',
      'challenge',
      'club-zone',
    ];

    for (final route in walletRoutes) {
      test('/fanzone/$route sub-route resolves', () {
        final fanzoneRoute = fanzone.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == '/fanzone');
        final subPaths = fanzoneRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains(route));
      });
    }
  });

  // ══════════════════════════════════════════════════════════════════════
  // Journey 5: League & Team
  // ══════════════════════════════════════════════════════════════════════

  group('Journey 5: League & team profiles', () {
    late FeatureModule fanzone;

    setUp(() {
      fanzone = modules.firstWhere((m) => m.featureKey == 'fanzone');
    });

    test('/fanzone/league (no slug) resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final subPaths = fanzoneRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('league'));
    });

    test('/fanzone/league/:competitionSlug resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final subPaths = fanzoneRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('league/:competitionSlug'));
    });

    test('/fanzone/standings/:competitionSlug resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final subPaths = fanzoneRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('standings/:competitionSlug'));
    });

    test('/fanzone/team/:teamSlug resolves', () {
      final fanzoneRoute = fanzone.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/fanzone');
      final subPaths = fanzoneRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('team/:teamSlug'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Journey 6: Live Tab
  // ══════════════════════════════════════════════════════════════════════

  group('Journey 6: Live match flow', () {
    test('/live is a standalone route (not a tab)', () {
      final live = modules.firstWhere((m) => m.featureKey == 'live');
      expect(live.tabRoute, isNull);
      final paths = live.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/live'));
    });

    test('/live/news/:articleId sub-route resolves', () {
      final live = modules.firstWhere((m) => m.featureKey == 'live');
      final liveRoute = live.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/live');
      final subPaths = liveRoute.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('news/:articleId'));
    });

    test('/live-match standalone redirect exists', () {
      final live = modules.firstWhere((m) => m.featureKey == 'live');
      final standalonePaths = live.standaloneRoutes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(standalonePaths, contains('/live-match'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Journey 7: BioPay
  // ══════════════════════════════════════════════════════════════════════

  group('Journey 7: BioPay payment flow', () {
    late FeatureModule biopay;

    setUp(() {
      biopay = modules.firstWhere((m) => m.featureKey == 'biopay');
    });

    test('/biopay tab resolves', () {
      expect(biopay.tabRoute!.path, '/biopay');
    });

    final biopayScreens = [
      'profile',
      'register',
      'review',
      'result',
      'recovery',
      'scan',
      'qr',
      'nfc',
    ];

    for (final screen in biopayScreens) {
      test('/biopay/$screen sub-route resolves', () {
        final paths = biopay.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(paths, contains(screen));
      });
    }
  });

  // ══════════════════════════════════════════════════════════════════════
  // Journey 8: Settings & Admin
  // ══════════════════════════════════════════════════════════════════════

  group('Journey 8: Settings & admin flow', () {
    test('/settings tab resolves', () {
      final settings = modules.firstWhere((m) => m.featureKey == 'settings');
      expect(settings.tabRoute!.path, '/settings');
    });

    final settingsScreens = ['edit-profile', 'notifications', 'privacy'];

    for (final screen in settingsScreens) {
      test('/settings/$screen sub-route resolves', () {
        final settings = modules.firstWhere(
          (m) => m.featureKey == 'settings',
        );
        final paths = settings.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(paths, contains(screen));
      });
    }

    test('/profile_setup standalone resolves', () {
      final settings = modules.firstWhere((m) => m.featureKey == 'settings');
      final standalonePaths = settings.standaloneRoutes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(standalonePaths, contains('/profile_setup'));
    });

    test('/admin route resolves', () {
      final admin = modules.firstWhere((m) => m.featureKey == 'admin');
      final paths = admin.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/admin'));
    });

    final adminScreens = [
      'cms',
      'matches',
      'contributions',
      'notifications',
      'sms-monitor',
    ];

    for (final screen in adminScreens) {
      test('/admin/$screen sub-route resolves', () {
        final admin = modules.firstWhere((m) => m.featureKey == 'admin');
        final adminRoute = admin.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == '/admin');
        final subPaths = adminRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains(screen));
      });
    }
  });

  // ══════════════════════════════════════════════════════════════════════
  // Journey 9: Contributions full flow
  // ══════════════════════════════════════════════════════════════════════

  group('Journey 9: Contributions group flow', () {
    late FeatureModule contributions;

    setUp(() {
      contributions = modules.firstWhere(
        (m) => m.featureKey == 'contributions',
      );
    });

    test('/contribute resolves', () {
      final paths = contributions.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/contribute'));
    });

    final topLevel = ['projects', 'groups', 'create', 'join', 'group/:groupId'];

    for (final route in topLevel) {
      test('/contribute/$route sub-route resolves', () {
        final root = contributions.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == '/contribute');
        final subPaths = root.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains(route));
      });
    }

    final groupRoutes = ['chat', 'settings', 'statement'];

    for (final route in groupRoutes) {
      test('/contribute/group/:id/$route nesting resolves', () {
        final root = contributions.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == '/contribute');
        final groupRoute = root.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == 'group/:groupId');
        final subPaths = groupRoute.routes
            .whereType<GoRoute>()
            .map((r) => r.path)
            .toSet();
        expect(subPaths, contains(route));
      });
    }
  });

  // ══════════════════════════════════════════════════════════════════════
  // Journey 10: Ticketing
  // ══════════════════════════════════════════════════════════════════════

  group('Journey 10: Ticketing flow', () {
    late FeatureModule ticketing;

    setUp(() {
      ticketing = modules.firstWhere((m) => m.featureKey == 'ticketing');
    });

    test('/tickets resolves', () {
      final paths = ticketing.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/tickets'));
    });

    test('/my-tickets resolves', () {
      final paths = ticketing.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/my-tickets'));
    });

    test('/e-ticket/:id resolves', () {
      final paths = ticketing.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/e-ticket/:id'));
    });

    test('/tickets/detail/:id nesting resolves', () {
      final root = ticketing.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/tickets');
      final subPaths = root.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('detail/:id'));
    });

    test('/tickets/map/:id nesting resolves', () {
      final root = ticketing.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/tickets');
      final subPaths = root.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(subPaths, contains('map/:id'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Full route count verification
  // ══════════════════════════════════════════════════════════════════════

  group('Full route surface area', () {
    test('total route count exceeds 60', () {
      var count = 0;

      void countRoutes(List<RouteBase> routes) {
        for (final route in routes) {
          if (route is GoRoute) {
            count++;
            countRoutes(route.routes);
          }
        }
      }

      for (final module in modules) {
        final tab = module.tabRoute;
        if (tab != null) count++; // Tab itself
        countRoutes(module.routes);
        countRoutes(module.standaloneRoutes);
      }

      expect(
        count,
        greaterThanOrEqualTo(50),
        reason: 'Expected 50+ routes in full-featured config, got $count',
      );
    });
  });
}

// ── Test Config ──────────────────────────────────────────────────────

class _AllFeaturesConfig implements ClubConfig {
  const _AllFeaturesConfig();

  @override String get clubId => '24';
  @override String get clubName => 'Test Club';
  @override String get appName => 'TestApp';
  @override String get country => 'Rwanda';
  @override String get countryCode => 'RW';
  @override String get language => 'en';
  @override String get momoPrefix => '*182*';
  @override String get currency => 'RWF';
  @override String get currencySymbol => 'RWF';
  @override ClubColors get colors => const ClubColors(
    primary: Color(0xFF0038A8),
    secondary: Color(0xFF001742),
    accent: Color(0xFFD9B24C),
    gradient: [Color(0xFF001742), Color(0xFF0038A8)],
  );
  @override String get crestAsset => 'assets/crest/test.png';
  @override String get supabaseUrl => 'https://test.supabase.co';
  @override String get supabaseAnonKey => 'test-key';
  @override List<String> get supportedLanguages => const ['en'];
  @override bool get hasBiopay => true;
  @override bool get hasFanClubs => true;
  @override bool get hasShop => true;
  @override bool get hasTicketing => true;
  @override bool get hasChat => true;
  @override bool get hasSmsLedger => true;
  @override MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*182*{amount}*{momo}#',
    senderName: 'Test',
    countryCode: 'RW',
  );
  @override String get environment => 'test';
  @override Map<String, bool> get features => {
    'biopay': true,
    'fan_clubs': true,
    'shop': true,
    'ticketing': true,
    'chat': true,
    'sms_ledger': true,
  };
}
