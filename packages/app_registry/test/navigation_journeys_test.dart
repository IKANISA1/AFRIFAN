import 'package:app_registry/app_registry.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late List<FeatureModule> modules;
  late AppRouter appRouter;

  setUp(() {
    modules = AppModuleRegistry.build(const _AllFeaturesConfig());
    appRouter = AppRouter(
      modules: modules,
      initialLocation: '/home',
      shellBuilder: (_, shell) => Scaffold(body: shell),
    );
  });

  group('Home quick actions', () {
    test('standalone destinations remain reachable', () {
      final allPaths = <String>{};

      void collect(List<RouteBase> routes) {
        for (final route in routes.whereType<GoRoute>()) {
          allPaths.add(route.path);
          collect(route.routes);
        }
      }

      for (final module in modules) {
        collect(module.routes);
        collect(module.standaloneRoutes);
        final tab = module.tabRoute;
        if (tab != null) {
          allPaths.add(tab.path);
        }
      }

      expect(
        allPaths,
        containsAll(<String>{
          '/fanzone',
          '/live',
          '/contribute',
          '/shop',
          '/tickets',
          '/fan-clubs',
          '/membership',
        }),
      );
    });
  });

  group('Fanzone surface', () {
    late FeatureModule fanzone;

    setUp(() {
      fanzone = modules.firstWhere((m) => m.featureKey == 'fanzone');
    });

    test('/fanzone keeps the main engagement routes', () {
      final subPaths = fanzone.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();

      expect(
        subPaths,
        containsAll(<String>{
          'fixtures',
          'live',
          'my',
          'match/:fixtureId',
          'wallet',
          'rewards',
          'history',
          'offers',
          'leaderboard',
          'notifications',
          'badges',
          'streak',
          'share',
          'league',
          'league/:competitionSlug',
          'standings/:competitionSlug',
          'team/:teamSlug',
          'club-zone',
          'fan-id',
          'social',
          'privacy',
        }),
      );
      expect(subPaths, isNot(contains('challenges')));
      expect(subPaths, isNot(contains('jackpot')));
      expect(subPaths, isNot(contains('friends')));
      expect(subPaths, isNot(contains('challenge')));
    });
  });

  group('Settings and admin', () {
    test('/settings keeps edit-profile, notifications, privacy', () {
      final settings = modules.firstWhere((m) => m.featureKey == 'settings');
      final paths = settings.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();

      expect(
        paths,
        containsAll(<String>{'edit-profile', 'notifications', 'privacy'}),
      );
    });

    test('/admin keeps the operations routes', () {
      final admin = modules.firstWhere((m) => m.featureKey == 'admin');
      final root = admin.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/admin',
      );
      final subPaths = root.routes
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
    });
  });

  group('Contributions public flow', () {
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

    test('/contribute exposes projects, groups, and group detail only', () {
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

    test('group detail keeps statement only', () {
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

  group('Fan clubs public flow', () {
    test('/fan-clubs exposes detail but not creation', () {
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

  group('Ticketing surface', () {
    late FeatureModule ticketing;

    setUp(() {
      ticketing = modules.firstWhere((m) => m.featureKey == 'ticketing');
    });

    test('/tickets, /my-tickets, and /e-ticket/:id resolve', () {
      final paths = ticketing.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(
        paths,
        containsAll(<String>{'/tickets', '/my-tickets', '/e-ticket/:id'}),
      );
    });
  });

  group('Router surface size', () {
    test('retains a broad route graph after removals', () {
      var count = 0;

      void countRoutes(List<RouteBase> routes) {
        for (final route in routes.whereType<GoRoute>()) {
          count++;
          countRoutes(route.routes);
        }
      }

      for (final module in modules) {
        final tab = module.tabRoute;
        if (tab != null) {
          count++;
        }
        countRoutes(module.routes);
        countRoutes(module.standaloneRoutes);
      }

      expect(count, greaterThanOrEqualTo(40));
      expect(appRouter.tabs, hasLength(3));
    });
  });
}

class _AllFeaturesConfig implements ClubConfig {
  const _AllFeaturesConfig();

  @override
  String get clubId => '24';
  @override
  String get clubName => 'Test Club';
  @override
  String get appName => 'TestApp';
  @override
  String get country => 'Rwanda';
  @override
  String get countryCode => 'RW';
  @override
  String get language => 'en';
  @override
  String get momoPrefix => '*182*';
  @override
  String get currency => 'RWF';
  @override
  String get currencySymbol => 'RWF';
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
  String get crestAsset => 'assets/crest/test.png';
  @override
  String get supabaseUrl => 'https://test.supabase.co';
  @override
  String get supabaseAnonKey => 'test-key';
  @override
  List<String> get supportedLanguages => const <String>['en'];
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
  Map<String, bool> get features => const <String, bool>{
    'fan_clubs': true,
    'shop': true,
    'ticketing': true,
    'chat': true,
    'sms_ledger': true,
  };
  @override
  MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*182*{amount}*{momo}#',
    senderName: 'Test',
    countryCode: 'RW',
  );
  @override
  String get environment => 'test';
}
