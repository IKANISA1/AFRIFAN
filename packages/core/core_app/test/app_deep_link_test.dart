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

  group('AfriClubApp deep linking', () {
    late _FakeClubConfig config;

    setUp(() {
      config = const _FakeClubConfig();
      ColorTokens.init(config.colors);
    });

    testWidgets(
      'navigates correctly to authenticated deep link after splash and authentication',
      (tester) async {
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _ContributionsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-1',
                clubId: '1',
                publicUserId: '483912',
              ),
            ),
            initialLocation: '/contribute/group/grp-123/statement',
          ),
        );

        // Allow splash, auth resolution, and redirect to happen
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify that the deeply nested route is rendered, NOT just home
        expect(find.byType(_FakeGroupStatementScreen), findsOneWidget);

        // Verify parameter passing
        final screen = tester.widget<_FakeGroupStatementScreen>(
          find.byType(_FakeGroupStatementScreen),
        );
        expect(screen.groupId, 'grp-123');
      },
    );

    testWidgets('preserves deep link across login if originally unauthenticated', (
      tester,
    ) async {
      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: <FeatureModule>[
            _HomeModule(),
            _OnboardingModule(),
            _ContributionsModule(),
          ],
          authRepository: FakeAuthRepository(restoreResult: null),
          initialLocation: '/contribute/group/grp-789/statement',
        ),
      );

      // Initially goes to splash which triggers auth, auth fails, goes to onboarding with `from` parameter
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(_FakeOnboardingScreen), findsOneWidget);

      // Simulate successful login
      final BuildContext context = tester.element(
        find.byType(_FakeOnboardingScreen),
      );

      // The onboarding screen has a 'from' query parameter attached to its location
      // In reality, the login logic reads this and pushes to the 'from' route after login.
      // We will mock this behavior by reading the Router location.
      final uri = GoRouterState.of(context).uri;
      final fromPath = uri.queryParameters['from'];

      expect(fromPath, contains('/contribute/group/grp-789/statement'));

      // Let's sign in through the notifier
      final container = ProviderScope.containerOf(context);
      final router = GoRouter.of(context);
      final mockRepo =
          container.read(authRepositoryProvider) as FakeAuthRepository;
      mockRepo.restoreResult = const UserProfile(
        id: 'user-2',
        clubId: '1',
        publicUserId: '999',
      );

      await container.read(authStateProvider.notifier).restore();
      await tester.pumpAndSettle();

      // Emulate the routing login page does: `context.go(fromPath)`
      router.go(fromPath!);
      await tester.pumpAndSettle();

      // Deep link correctly resolved after login
      expect(find.byType(_FakeGroupStatementScreen), findsOneWidget);
      final screen = tester.widget<_FakeGroupStatementScreen>(
        find.byType(_FakeGroupStatementScreen),
      );
      expect(screen.groupId, 'grp-789');
    });

    testWidgets(
      'falls back to home when deferred destination does not match a known route',
      (tester) async {
        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _ContributionsModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-3',
                clubId: '1',
                publicUserId: '123456',
              ),
            ),
            initialLocation: '/splash?from=%2Fnot-a-real-route',
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakeHomeScreen), findsOneWidget);
        expect(find.byType(_FakeGroupStatementScreen), findsNothing);
      },
    );

    testWidgets(
      'pushes a valid warm deep link received while the app is running',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final links = StreamController<Uri>();
        addTearDown(links.close);

        await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _ClubModule(),
            ],
            authRepository: FakeAuthRepository(
              restoreResult: const UserProfile(
                id: 'user-warm-link',
                clubId: '1',
                publicUserId: '654321',
              ),
            ),
            initialLocation: '/home',
            deepLinkParser: DeepLinkParser(customScheme: 'gikundiro'),
            deepLinkService: FakeDeepLinkService(stream: links.stream),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(_FakeHomeScreen), findsOneWidget);

        links.add(Uri.parse('gikundiro://club/news'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakeClubNewsScreen), findsOneWidget);
        expect(
          tester
              .widget<AfriClubBottomNav>(find.byType(AfriClubBottomNav))
              .currentIndex,
          1,
        );
      },
    );
  });
}

class _FakeGroupStatementScreen extends StatelessWidget {
  final String groupId;
  const _FakeGroupStatementScreen({required this.groupId});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text('Statement: $groupId'));
}

class _FakeHomeScreen extends StatelessWidget {
  const _FakeHomeScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Home'));
}

class _FakeClubNewsScreen extends StatelessWidget {
  const _FakeClubNewsScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Club news'));
}

class _ClubModule extends FeatureModule {
  @override
  String get featureKey => 'club';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/club',
    label: 'Club',
    icon: AfriIcons.stadium,
    builder: (context, state) => const Scaffold(body: Text('Club')),
  );

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: 'news',
      builder: (context, state) => const _FakeClubNewsScreen(),
    ),
  ];
}

class _ContributionsModule extends FeatureModule {
  @override
  String get featureKey => 'contribute';

  @override
  List<RouteBase> get standaloneRoutes => <RouteBase>[
    GoRoute(
      path: '/contribute',
      builder: (context, state) => const Scaffold(body: Text('Contributed')),
      routes: [
        GoRoute(
          path: 'group/:groupId',
          builder: (context, state) => const Scaffold(body: Text('Group')),
          routes: [
            GoRoute(
              path: 'statement',
              builder: (context, state) {
                final groupId = state.pathParameters['groupId']!;
                return _FakeGroupStatementScreen(groupId: groupId);
              },
            ),
          ],
        ),
      ],
    ),
  ];
}

// ───────────────────────────────────────────────────────────────────────── //
// Duplicated minimal mocks from app_routing_guard_test.dart to keep it self-contained
// ───────────────────────────────────────────────────────────────────────── //

class _FakeOnboardingScreen extends StatelessWidget {
  const _FakeOnboardingScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Onboarding'));
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({
    this.restoreResult,
    this.adminAccess = AdminWorkspaceAccess.none,
  }) : super(clubId: '1');

  UserProfile? restoreResult;
  final AdminWorkspaceAccess adminAccess;

  @override
  Future<UserProfile?> restoreCurrentUser() async => restoreResult;

  @override
  Future<void> signOut() async {}

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async =>
      adminAccess;

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();
}

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig();
  @override
  String get appName => 'Test';
  @override
  String get clubId => '1';
  @override
  String get clubName => 'Test';
  @override
  ClubColors get colors => const ClubColors(
    primary: ColorTokens.referenceAccountBlue,
    secondary: ColorTokens.referenceChromeBlack,
    accent: ColorTokens.referenceRewardsVioletHot,
    gradient: [
      ColorTokens.referenceAccountBlue,
      ColorTokens.referenceRewardsVioletHot,
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
    'contributions': true,
  };
  @override
  String get language => 'en';
  @override
  String get momoPrefix => '*182*';
  @override
  MomoConfig get momo =>
      const MomoConfig(ussdTemplate: '', senderName: '', countryCode: '');
  @override
  String get supabaseAnonKey => 'anon';
  @override
  String get supabaseUrl => 'https://example';
  @override
  List<String> get supportedLanguages => ['en'];
  @override
  String get environment => 'test';
}

class _HomeModule extends FeatureModule {
  @override
  String get featureKey => 'home';
  @override
  TabRoute get tabRoute => TabRoute(
    path: '/home',
    label: 'Home',
    icon: AfriIcons.home,
    builder: (c, s) => const _FakeHomeScreen(),
  );
}

class _OnboardingModule extends FeatureModule {
  @override
  String get featureKey => 'onboarding';
  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(path: '/splash', redirect: (_, state) => _splashRedirect(state)),
    GoRoute(
      path: '/onboarding',
      builder: (c, s) => const _FakeOnboardingScreen(),
    ),
  ];

  @override
  Set<String> get publicPaths => const <String>{'/splash', '/onboarding'};
}

String _splashRedirect(GoRouterState state) {
  final raw = state.uri.queryParameters['from']?.trim();
  final uri = raw == null || raw.isEmpty ? null : Uri.tryParse(raw);
  final path = uri?.path;
  if (path == null ||
      path.isEmpty ||
      !path.startsWith('/') ||
      path == '/splash' ||
      path == '/onboarding') {
    return '/onboarding';
  }

  return Uri(
    path: '/onboarding',
    queryParameters: <String, String>{'from': uri.toString()},
  ).toString();
}
