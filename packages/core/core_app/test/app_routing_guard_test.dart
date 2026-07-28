import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_app/core_app.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(_loadFlutterArtifactFont('MaterialIcons-Regular.otf'));
    final roboto = FontLoader('GoldenRoboto')
      ..addFont(_loadFlutterArtifactFont('Roboto-Regular.ttf'));
    await Future.wait<void>([materialIcons.load(), roboto.load()]);
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDownAll(() {
    TypographyTokens.debugUseFallbackFonts = false;
  });

  group('AfriClubApp route guards', () {
    late _FakeClubConfig config;

    setUp(() {
      config = const _FakeClubConfig();
      ColorTokens.init(config.colors);
    });

    testWidgets('applies the OS high-contrast variant to routed content', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(highContrast: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: <FeatureModule>[
            _HomeModule(),
            _OnboardingModule(),
            _SettingsModule(),
          ],
          authRepository: FakeAuthRepository(
            restoreResult: const UserProfile(
              id: 'user-1',
              clubId: '1',
              publicUserId: '483912',
            ),
          ),
          initialLocation: '/home',
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(_FakeHomeScreen));
      final theme = Theme.of(context);
      expect(theme.extension<AfriDesignTokens>()!.focusRingWidth, equals(4));
      expect(
        theme.extension<AfriSemanticColors>()!.secondaryText,
        theme.extension<AfriSemanticColors>()!.primaryText,
      );
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
        final context = tester.element(find.byType(_FakeOnboardingScreen));
        expect(
          GoRouterState.of(context).uri.queryParameters['from'],
          '/settings',
        );
      },
    );

    testWidgets(
      'redirects an expired startup session to reauthentication with destination',
      (tester) async {
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreError: StateError('expired session'),
            ),
            initialLocation: '/settings/notifications',
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakePhoneAuthScreen), findsOneWidget);
        expect(
          find.text('reauth-from:/settings/notifications'),
          findsOneWidget,
        );
      },
    );

    testWidgets('rejects external deferred destinations after authentication', (
      tester,
    ) async {
      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: <FeatureModule>[
            _HomeModule(),
            _OnboardingModule(),
            _SettingsModule(),
          ],
          authRepository: FakeAuthRepository(
            restoreResult: const UserProfile(
              id: 'user-1',
              clubId: '1',
              publicUserId: '483912',
            ),
          ),
          initialLocation:
              '/onboarding?from=https%3A%2F%2Fattacker.example%2Fsettings',
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(_FakeHomeScreen), findsOneWidget);
      expect(find.byType(_FakeSettingsScreen), findsNothing);
    });

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

    testWidgets(
      'routes an involuntary session loss to reauthentication and preserves destination',
      (tester) async {
        final authChanges = StreamController<supabase.AuthState>();
        addTearDown(authChanges.close);
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
              authChanges: authChanges.stream,
            ),
            initialLocation: '/settings',
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(_FakeSettingsScreen), findsOneWidget);

        authChanges.add(
          const supabase.AuthState(supabase.AuthChangeEvent.signedOut, null),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakePhoneAuthScreen), findsOneWidget);
        expect(find.text('reauth-from:/settings'), findsOneWidget);
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

    testWidgets('preserves 200 percent platform text scaling', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: <FeatureModule>[_HomeModule(), _OnboardingModule()],
          authRepository: FakeAuthRepository(
            restoreResult: const UserProfile(
              id: 'user-1',
              clubId: '1',
              publicUserId: '483912',
            ),
          ),
          initialLocation: '/home',
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('text-scale:2.0'), findsOneWidget);
    });

    testWidgets(
      'adapts bottom navigation to a tablet rail while preserving branch state',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
            ),
            initialLocation: '/home',
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(AfriClubBottomNav), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('home-route-draft')),
          'Preserve this draft',
        );
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.byType(_FakeSettingsScreen), findsOneWidget);

        tester.view.physicalSize = const Size(834, 1194);
        await tester.pumpAndSettle();

        expect(find.byType(AfriClubBottomNav), findsNothing);
        expect(find.byType(NavigationRail), findsOneWidget);
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        rail.onDestinationSelected!(0);
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('home-route-draft')))
              .controller
              ?.text,
          'Preserve this draft',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'deep-linked full-height task pops back to its canonical parent',
      (tester) async {
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
            ),
            initialLocation: '/settings/edit-profile',
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakeSettingsDetailScreen), findsOneWidget);
        final context = tester.element(find.byType(_FakeSettingsDetailScreen));
        GoRouter.of(context).pop();
        await tester.pumpAndSettle();

        expect(find.byType(_FakeSettingsDetailScreen), findsNothing);
        expect(find.byType(_FakeSettingsScreen), findsOneWidget);
      },
    );

    testWidgets('uses one hinge-safe mobile shell on a dual-screen posture', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(850, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(850, 900),
            platformBrightness: Brightness.dark,
            displayFeatures: [
              ui.DisplayFeature(
                bounds: Rect.fromLTWH(417, 0, 16, 900),
                type: ui.DisplayFeatureType.hinge,
                state: ui.DisplayFeatureState.postureHalfOpened,
              ),
            ],
          ),
          child: AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
            ),
            initialLocation: '/home',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AfriClubBottomNav), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      final shellRect = tester.getRect(find.byType(AfriClubBottomNav));
      expect(shellRect.right, lessThanOrEqualTo(417));
      expect(tester.takeException(), isNull);
    });

    testWidgets('golden adaptive shell uses a tablet rail', (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: <FeatureModule>[
            _HomeModule(),
            _OnboardingModule(),
            _SettingsModule(),
          ],
          authRepository: FakeAuthRepository(
            restoreResult: const UserProfile(
              id: 'user-1',
              clubId: '1',
              publicUserId: '483912',
            ),
          ),
          initialLocation: '/home',
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      await expectLater(
        find.byKey(const ValueKey('adaptive-app-shell')),
        matchesGoldenFile('goldens/adaptive_shell_tablet_dark_834x1194.png'),
      );
    });

    testWidgets('golden adaptive shell avoids a separating hinge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(850, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(850, 900),
            platformBrightness: Brightness.dark,
            displayFeatures: [
              ui.DisplayFeature(
                bounds: Rect.fromLTWH(417, 0, 16, 900),
                type: ui.DisplayFeatureType.hinge,
                state: ui.DisplayFeatureState.postureHalfOpened,
              ),
            ],
          ),
          child: AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _SettingsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
            ),
            initialLocation: '/home',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AfriClubBottomNav), findsOneWidget);
      await expectLater(
        find.byKey(const ValueKey('adaptive-app-shell')),
        matchesGoldenFile('goldens/adaptive_shell_hinge_dark_850x900.png'),
      );
    });
  });
}

Future<ByteData> _loadFlutterArtifactFont(String fileName) async {
  try {
    return await rootBundle.load('packages/flutter/fonts/$fileName');
  } on Object {
    final flutterExecutable =
        (Process.runSync('which', <String>['flutter']).stdout as String).trim();
    final flutterRoot = File(flutterExecutable).resolveSymbolicLinksSync();
    final bytes = await File(
      '${File(flutterRoot).parent.parent.path}/bin/cache/artifacts/material_fonts/$fileName',
    ).readAsBytes();
    return ByteData.sublistView(bytes);
  }
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

class _FakePhoneAuthScreen extends StatelessWidget {
  const _FakePhoneAuthScreen({required this.from});

  final String? from;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text('reauth-from:${from ?? 'none'}'));
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
    this.authChanges,
  }) : super(clubId: '1');

  final UserProfile? restoreResult;
  final Object? restoreError;
  final AdminWorkspaceAccess adminAccess;
  final Stream<supabase.AuthState>? authChanges;

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
      authChanges ?? const Stream<supabase.AuthState>.empty();
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
    builder: (context, state) => const _FakeHomeScreen(),
  );
}

class _FakeHomeScreen extends StatefulWidget {
  const _FakeHomeScreen();

  @override
  State<_FakeHomeScreen> createState() => _FakeHomeScreenState();
}

class _FakeHomeScreenState extends State<_FakeHomeScreen> {
  final TextEditingController _draftController = TextEditingController();

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).toStringAsFixed(1);
    return Scaffold(
      body: Column(
        children: [
          Text('text-scale:$scale'),
          TextField(
            key: const ValueKey('home-route-draft'),
            controller: _draftController,
          ),
        ],
      ),
    );
  }
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
    GoRoute(
      path: '/auth/phone',
      builder: (context, state) =>
          _FakePhoneAuthScreen(from: state.uri.queryParameters['from']),
    ),
  ];

  @override
  Set<String> get publicPaths => const <String>{
    '/splash',
    '/onboarding',
    '/auth/phone',
  };
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

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: 'edit-profile',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        const _FakeSettingsDetailScreen(),
        fullHeight: true,
      ),
    ),
    GoRoute(
      path: 'notifications',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        const _FakeSettingsDetailScreen(),
        fullHeight: true,
      ),
    ),
  ];
}

class _FakeSettingsDetailScreen extends StatelessWidget {
  const _FakeSettingsDetailScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Settings detail'));
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
