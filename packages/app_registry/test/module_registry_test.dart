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
          'club',
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
          'club',
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

    test('Predict module is not registered from club feature flags', () {
      final defaultModules = AppModuleRegistry.build(const _FakeClubConfig());

      expect(
        defaultModules.map((module) => module.featureKey),
        isNot(contains('predict')),
      );
    });

    test('production remote Predict enablement is policy fail-closed', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(environment: 'production'),
        configSnapshot: <String, dynamic>{
          'features': <Map<String, dynamic>>[
            <String, dynamic>{
              'feature_key': 'predict',
              'display_name': 'Predict',
              'is_enabled': true,
              'visibility_state': 'visible',
              'rules': <String, dynamic>{
                'rollout_rules': <String, dynamic>{
                  'store_release_authorized': true,
                },
              },
            },
          ],
        },
      );

      expect(
        modules.map((module) => module.featureKey),
        isNot(contains('predict')),
      );
    });

    test('production Predict needs every explicit policy authorization', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(environment: 'production'),
        configSnapshot: <String, dynamic>{
          'features': <Map<String, dynamic>>[
            <String, dynamic>{
              'feature_key': 'predict',
              'display_name': 'Predict',
              'is_enabled': true,
              'visibility_state': 'visible',
              'rules': <String, dynamic>{
                'rollout_rules': <String, dynamic>{
                  'store_release_authorized': true,
                  'stakes_have_no_real_world_value': true,
                  'contest_rules_approved': true,
                },
              },
            },
          ],
        },
      );

      expect(
        modules.where((module) => module.tabRoute?.path == '/predict'),
        hasLength(1),
      );
      expect(
        modules.map((module) => module.featureKey),
        isNot(contains('predict')),
      );
    });
  });

  group('Tab routes', () {
    late List<FeatureModule> modules;

    setUp(() {
      modules = AppModuleRegistry.build(const _FakeClubConfig());
    });

    test('registered shell branches include the hidden settings branch', () {
      final tabs = modules
          .where((m) => m.tabRoute != null)
          .map((m) => (path: m.tabRoute!.path, label: m.tabRoute!.label))
          .toList(growable: false);
      expect(
        tabs,
        orderedEquals(<({String path, String label})>[
          (path: '/home', label: 'Home'),
          (path: '/club', label: 'Club'),
          (path: '/predict', label: 'Predict'),
          (path: '/settings', label: 'Settings'),
          (path: '/membership', label: 'Membership'),
        ]),
      );
    });

    test('non-tab modules stay off the bottom navigation', () {
      for (final featureKey in const <String>[
        'live',
        'onboarding',
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

    test('router tabs expose the approved four-tab supporter surface', () {
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
          (path: '/club', label: 'Club'),
          (path: '/predict', label: 'Predict'),
          (path: '/membership', label: 'Membership'),
        ]),
      );
    });

    test('default supporter app keeps the approved full-screen surfaces', () {
      final decisions = modules
          .expand((module) => module.routePresentationDecisions)
          .toList(growable: false);
      final fullScreens = decisions
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
          '/club/team/:playerId',
          '/club/partners',
          '/club/partners/:partnerId',
          '/club/open-web',
          '/club/news',
          '/club/news/:articleId',
          '/club/fixtures',
          '/club/fixtures/:matchId',
          '/club/results',
          '/club/standings',
          '/club/history',
          '/club/projects',
          '/club/projects/:projectId',
          '/predict',
          '/fanzone/venue',
          '/fanzone/venue/order',
          '/fanzone/match/:fixtureId',
          '/settings',
          '/tickets',
          '/e-ticket/:id',
          '/membership',
          '/shop',
        }),
      );
    });

    test(
      'all registered default supporter routes have presentation decisions',
      () {
        final registeredPaths = <String>{};
        for (final module in modules) {
          final tabRoute = module.tabRoute;
          final routeParent = tabRoute?.path ?? '';
          if (tabRoute != null) {
            registeredPaths.add(tabRoute.path);
          }
          for (final route in module.routes) {
            _collectGoRoutePaths(route, routeParent, registeredPaths);
          }
          for (final route in module.standaloneRoutes) {
            _collectGoRoutePaths(route, '', registeredPaths);
          }
        }

        final decidedPaths = modules
            .expand((module) => module.routePresentationDecisions)
            .map((decision) => decision.path)
            .toSet();

        expect(decidedPaths, containsAll(registeredPaths));
      },
    );
  });

  group('Admin routes', () {
    test('mobile admin is not registered unless explicitly opted in', () {
      final modules = AppModuleRegistry.build(const _FakeClubConfig());

      expect(
        modules.map((module) => module.featureKey),
        isNot(contains('admin')),
      );
    });

    test('remote config cannot enable admin in a consumer build', () {
      final modules = AppModuleRegistry.build(
        const _FakeClubConfig(hasMobileAdmin: true),
        configSnapshot: <String, dynamic>{
          'features': <Map<String, dynamic>>[
            <String, dynamic>{
              'feature_key': 'admin',
              'is_enabled': true,
              'visibility_state': 'visible',
              'channel': <String, dynamic>{'is_enabled': true},
              'rules': <String, dynamic>{'is_within_schedule': true},
            },
          ],
        },
      );

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
          allowInternalMobileAdmin: true,
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
    test('/contribute redirects mini-hubs while keeping detail utilities', () {
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
      expect(root.redirect, isNull);
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
    test('/fan-clubs opens discovery and retains detail', () {
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

      expect(root.redirect, isNull);
      expect(subPaths, contains(':clubId'));
      expect(subPaths, isNot(contains('create')));
    });
  });
}

void _collectGoRoutePaths(
  RouteBase route,
  String parentPath,
  Set<String> paths,
) {
  if (route is! GoRoute) {
    return;
  }

  final path = route.path.startsWith('/')
      ? route.path
      : '${parentPath.endsWith('/') ? parentPath.substring(0, parentPath.length - 1) : parentPath}/${route.path}';
  paths.add(path);

  for (final child in route.routes) {
    _collectGoRoutePaths(child, path, paths);
  }
}

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig({
    this.hasFanClubs = true,
    this.hasShop = true,
    this.hasTicketing = true,
    this.hasMobileAdmin = false,
    this.environment = 'test',
  });

  @override
  final bool hasFanClubs;
  @override
  final bool hasShop;
  @override
  final bool hasTicketing;
  final bool hasMobileAdmin;
  @override
  final String environment;
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
