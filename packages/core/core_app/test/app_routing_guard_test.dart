import 'dart:async';

import 'package:core_app/core_app.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AfriClubApp route guards', () {
    late _FakeClubConfig config;

    setUp(() {
      config = const _FakeClubConfig();
      ColorTokens.init(config.colors);
    });

    testWidgets(
      'redirects unauthenticated deep links to onboarding through splash recovery',
      (tester) async {
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
              _AdminModule(),
            ],
            authRepository: FakeAuthRepository(restoreResult: null),
            initialLocation: '/settings',
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakeOnboardingScreen), findsOneWidget);
      },
    );

    testWidgets(
      'redirects non-admin authenticated deep links away from admin routes',
      (tester) async {
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
              _AdminModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
            ),
            initialLocation: '/admin',
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakeSettingsScreen), findsOneWidget);
        expect(find.byType(_FakeOnboardingScreen), findsNothing);
      },
    );

    testWidgets('redirects disabled deep links to the unavailable screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: <FeatureModule>[
            _HomeModule(),
            _OnboardingModule(),
            _SettingsModule(),
            _AdminModule(),
            _TicketsModule(),
          ],
          authRepository: FakeAuthRepository(
            restoreResult: const UserProfile(
              id: 'user-1',
              clubId: '1',
              publicUserId: '483912',
            ),
          ),
          platformConfigSnapshot: <String, dynamic>{
            'channel': 'mobile',
            'features': <Map<String, dynamic>>[
              <String, dynamic>{
                'feature_key': 'ticketing',
                'display_name': 'Ticketing',
                'is_enabled': true,
                'visibility_state': 'hidden',
                'channel': <String, dynamic>{
                  'is_enabled': true,
                  'is_visible': false,
                  'show_in_navigation': false,
                  'show_on_home': false,
                  'route_key': '/tickets',
                },
              },
            ],
            'content_blocks': const <Map<String, dynamic>>[],
          },
          initialLocation: '/tickets',
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('This feature is currently unavailable.'),
        findsOneWidget,
      );
      expect(find.text('Tickets'), findsNothing);
    });
  });
}

class _FakeSplashScreen extends ConsumerStatefulWidget {
  const _FakeSplashScreen();

  @override
  ConsumerState<_FakeSplashScreen> createState() => _FakeSplashScreenState();
}

class _FakeSplashScreenState extends ConsumerState<_FakeSplashScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    unawaited(_navigateToNext());
  }

  Future<void> _navigateToNext() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _hasNavigated) return;

    final authNotifier = ref.read(authStateProvider.notifier);
    final currentState = ref.read(authStateProvider);

    if (currentState is AuthInitial) {
      await authNotifier.restore();
    }

    if (!mounted || _hasNavigated) return;

    final resolvedState = ref.read(authStateProvider);
    final deferredLocation = _deferredLocation();

    _hasNavigated = true;
    if (resolvedState is AuthAuthenticated) {
      context.go(deferredLocation ?? '/home');
      return;
    }

    if (deferredLocation == null) {
      context.go('/onboarding');
      return;
    }

    context.go(
      Uri(
        path: '/onboarding',
        queryParameters: <String, String>{'from': deferredLocation},
      ).toString(),
    );
  }

  String? _deferredLocation() {
    final raw = GoRouterState.of(context).uri.queryParameters['from']?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(raw);
    final path = uri?.path;
    if (path == null ||
        path.isEmpty ||
        !path.startsWith('/') ||
        path == '/splash' ||
        path == '/onboarding') {
      return null;
    }

    if (GoRouter.of(context).configuration.findMatch(uri!).isError) {
      return null;
    }

    return uri.toString();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Splash'));
}

class _FakeOnboardingScreen extends StatelessWidget {
  const _FakeOnboardingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Onboarding'));
}

class _FakeSettingsScreen extends StatelessWidget {
  const _FakeSettingsScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Settings'));
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({
    this.restoreResult,
    this.restoreError,
    this.adminAccess = AdminWorkspaceAccess.none,
  }) : super(clubId: '1');

  final UserProfile? restoreResult;
  final Object? restoreError;
  final AdminWorkspaceAccess adminAccess;

  @override
  Future<UserProfile?> restoreCurrentUser() async {
    if (restoreError != null) {
      throw restoreError!;
    }
    return restoreResult;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return adminAccess;
  }

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();
}

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig();

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
  bool get hasFanClubs => false;

  @override
  bool get hasShop => false;

  @override
  bool get hasSmsLedger => false;

  @override
  bool get hasTicketing => false;

  @override
  Map<String, bool> get features => const <String, bool>{
    'home': true,
    'onboarding': true,
    'settings': true,
    'admin': true,
    'ticketing': true,
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
    icon: AfriIcons.home,
    activeIcon: AfriIcons.home,
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
      builder: (context, state) => const _FakeSplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const _FakeOnboardingScreen(),
    ),
  ];

  @override
  Set<String> get publicPaths => const <String>{'/splash', '/onboarding'};
}

class _SettingsModule extends FeatureModule {
  @override
  String get featureKey => 'settings';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/settings',
    label: 'Settings',
    icon: AfriIcons.settings,
    activeIcon: AfriIcons.settings,
    builder: (context, state) => const _FakeSettingsScreen(),
  );
}

class _AdminModule extends FeatureModule {
  @override
  String get featureKey => 'admin';

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: '/admin',
      builder: (context, state) => const Scaffold(body: Text('Admin')),
    ),
  ];
}

class _TicketsModule extends FeatureModule {
  @override
  String get featureKey => 'ticketing';

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: '/tickets',
      builder: (context, state) => const Scaffold(body: Text('Tickets')),
    ),
  ];
}
