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

  group('Default supporter exposure', () {
    test('keeps only approved bottom tabs in the shell', () {
      expect(
        appRouter.tabs.map((tab) => tab.path),
        orderedEquals(<String>['/home', '/club', '/fanzone', '/membership']),
      );
    });

    test(
      'keeps secondary compatibility paths registered without promoting them to tabs',
      () {
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
        expect(appRouter.tabs.map((tab) => tab.path), isNot(contains('/live')));
        expect(
          appRouter.tabs.map((tab) => tab.path),
          isNot(contains('/contribute')),
        );
        expect(
          appRouter.tabs.map((tab) => tab.path),
          isNot(contains('/fan-clubs')),
        );
      },
    );
  });

  group('Fanzone surface', () {
    late FeatureModule fanzone;

    setUp(() {
      fanzone = modules.firstWhere((m) => m.featureKey == 'fanzone');
    });

    test(
      '/fanzone keeps compatibility routes but redirects section content',
      () {
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
        expect(subPaths, isNot(contains('predict')));

        final decisions = {
          for (final decision in fanzone.routePresentationDecisions)
            decision.path: decision.presentation,
        };
        expect(decisions['/fanzone'], RoutePresentation.fullScreen);
        expect(
          decisions['/fanzone/match/:fixtureId'],
          RoutePresentation.fullScreen,
        );
        expect(decisions['/fanzone/wallet'], RoutePresentation.fullScreen);
        expect(decisions['/fanzone/fixtures'], RoutePresentation.redirect);
        expect(decisions['/fanzone/leaderboard'], RoutePresentation.redirect);
        expect(decisions['/fanzone/offers'], RoutePresentation.redirect);
        expect(decisions['/fanzone/rewards'], RoutePresentation.redirect);
        expect(decisions['/fanzone/history'], RoutePresentation.redirect);
        expect(decisions['/fanzone/club-zone'], RoutePresentation.redirect);
      },
    );
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

    test('mobile admin is excluded from default supporter route graph', () {
      expect(
        modules.map((module) => module.featureKey),
        isNot(contains('admin')),
      );
    });

    test('/admin keeps the operations routes for explicit internal builds', () {
      final internalModules = AppModuleRegistry.build(
        const _AllFeaturesConfig(mobileAdmin: true),
        allowInternalMobileAdmin: true,
      );
      final admin = internalModules.firstWhere((m) => m.featureKey == 'admin');
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

  group('Contributions compatibility flow', () {
    late FeatureModule contributions;

    setUp(() {
      contributions = modules.firstWhere(
        (m) => m.featureKey == 'contributions',
      );
    });

    test('/contribute resolves as a compatibility redirect', () {
      final paths = contributions.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();
      expect(paths, contains('/contribute'));
      final root = contributions.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/contribute',
      );
      expect(root.redirect, isNotNull);
    });

    test('/contribute keeps deep-link utilities but redirects mini-hubs', () {
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
      expect(
        root.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == 'projects')
            .redirect,
        isNotNull,
      );
      expect(
        root.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == 'groups')
            .redirect,
        isNotNull,
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

  group('Fan clubs compatibility flow', () {
    test('/fan-clubs redirects root but keeps detail compatibility', () {
      final fanClubs = modules.firstWhere((m) => m.featureKey == 'fan_clubs');
      final root = fanClubs.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == '/fan-clubs',
      );
      final subPaths = root.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();

      expect(root.redirect, isNotNull);
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

  group('Official Club surface', () {
    test('registers the complete canonical football and club route family', () {
      final club = modules.firstWhere((module) => module.featureKey == 'club');
      final paths = <String>{club.tabRoute!.path};

      void collect(GoRoute route, String parent) {
        final path = route.path.startsWith('/')
            ? route.path
            : '$parent/${route.path}';
        paths.add(path);
        for (final child in route.routes.whereType<GoRoute>()) {
          collect(child, path);
        }
      }

      for (final route in club.routes.whereType<GoRoute>()) {
        collect(route, club.tabRoute!.path);
      }
      expect(
        paths,
        equals(<String>{
          '/club',
          '/club/team',
          '/club/news',
          '/club/news/:articleId',
          '/club/fixtures',
          '/club/fixtures/:matchId',
          '/club/results',
          '/club/standings',
          '/club/history',
          '/club/projects',
          '/club/projects/:projectId',
        }),
      );
    });
  });

  group('Router surface size', () {
    test('approved full-screen set stays intentionally bounded', () {
      final fullScreens = modules
          .expand((module) => module.routePresentationDecisions)
          .where(
            (decision) => decision.presentation == RoutePresentation.fullScreen,
          )
          .map((decision) => decision.path)
          .toSet();

      expect(
        fullScreens,
        equals(<String>{
          '/onboarding',
          '/auth/phone',
          '/auth/otp',
          '/home',
          '/search',
          '/club',
          '/club/team',
          '/club/news',
          '/club/news/:articleId',
          '/club/fixtures',
          '/club/fixtures/:matchId',
          '/club/results',
          '/club/standings',
          '/club/history',
          '/club/projects',
          '/club/projects/:projectId',
          '/fanzone',
          '/fanzone/venue',
          '/fanzone/venue/order',
          '/fanzone/match/:fixtureId',
          '/fanzone/wallet',
          '/settings',
          '/tickets',
          '/e-ticket/:id',
          '/membership',
          '/shop',
        }),
      );
    });
  });
}

class _AllFeaturesConfig implements ClubConfig {
  const _AllFeaturesConfig({this.mobileAdmin = false});

  final bool mobileAdmin;

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
  Map<String, bool> get features => <String, bool>{
    'fan_clubs': true,
    'shop': true,
    'ticketing': true,
    'chat': true,
    'sms_ledger': true,
    'mobile_admin': mobileAdmin,
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
