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
            initialLocation: '/contribute/group/grp-123/chat',
          ),
        );

        // Allow splash, auth resolution, and redirect to happen
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify that the deeply nested route is rendered, NOT just home
        expect(find.byType(_FakeGroupChatScreen), findsOneWidget);
        
        // Verify parameter passing
        final screen = tester.widget<_FakeGroupChatScreen>(
          find.byType(_FakeGroupChatScreen),
        );
        expect(screen.groupId, 'grp-123');
      },
    );

    testWidgets(
      'preserves deep link across login if originally unauthenticated',
      (tester) async {
         await tester.pumpWidget(
          AfriClubApp(
            config: config,
            modules: <FeatureModule>[
              _HomeModule(),
              _OnboardingModule(),
              _ContributionsModule(),
            ],
            authRepository: FakeAuthRepository(restoreResult: null),
            initialLocation: '/contribute/group/grp-789/chat',
          ),
        );

        // Initially goes to splash which triggers auth, auth fails, goes to onboarding with `from` parameter
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(_FakeOnboardingScreen), findsOneWidget);

        // Simulate successful login
        final BuildContext context = tester.element(find.byType(_FakeOnboardingScreen));
        
        // The onboarding screen has a 'from' query parameter attached to its location
        // In reality, the login logic reads this and pushes to the 'from' route after login.
        // We will mock this behavior by reading the Router location.
        final uri = GoRouterState.of(context).uri;
        final fromPath = uri.queryParameters['from'];
        
        expect(fromPath, contains('/contribute/group/grp-789/chat'));
        
        // Let's sign in through the notifier
        final container = ProviderScope.containerOf(context);
        final router = GoRouter.of(context);
        final mockRepo = container.read(authRepositoryProvider) as FakeAuthRepository;
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
        expect(find.byType(_FakeGroupChatScreen), findsOneWidget);
        final screen = tester.widget<_FakeGroupChatScreen>(
          find.byType(_FakeGroupChatScreen),
        );
        expect(screen.groupId, 'grp-789');
      },
    );
  });
}

class _FakeGroupChatScreen extends StatelessWidget {
  final String groupId;
  const _FakeGroupChatScreen({required this.groupId});
  @override
  Widget build(BuildContext context) => Scaffold(body: Text('Chat: $groupId'));
}

class _FakeHomeScreen extends StatelessWidget {
  const _FakeHomeScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Home'));
}

class _ContributionsModule extends FeatureModule {
  @override
  String get featureKey => 'contribute';

  @override
  List<RouteBase> get standaloneRoutes => <RouteBase>[
    GoRoute(
      path: '/contribute',
      builder: (context, state) => const Scaffold(body: Text('Contributions')),
      routes: [
        GoRoute(
          path: 'group/:groupId',
          builder: (context, state) => const Scaffold(body: Text('Group')),
          routes: [
            GoRoute(
              path: 'chat',
              builder: (context, state) {
                final groupId = state.pathParameters['groupId']!;
                return _FakeGroupChatScreen(groupId: groupId);
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
    _navigateToNext();
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
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    final path = uri?.path;
    if (path == null || !path.startsWith('/') || path == '/splash' || path == '/onboarding') {
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
  Widget build(BuildContext context) => const Scaffold(body: Text('Onboarding'));
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
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async => adminAccess;

  @override
  Stream<supabase.AuthState> get authStateChanges => const Stream<supabase.AuthState>.empty();
}

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig();
  @override String get appName => 'Test';
  @override String get clubId => '1';
  @override String get clubName => 'Test';
  @override ClubColors get colors => const ClubColors(primary: Colors.red, secondary: Colors.red, accent: Colors.red, gradient: [Colors.red, Colors.red]);
  @override String get country => 'Rwanda';
  @override String get countryCode => 'RW';
  @override String get crestAsset => '';
  @override String get currency => 'RWF';
  @override String get currencySymbol => 'RWF';
  @override bool get hasBiopay => false;
  @override bool get hasChat => false;
  @override bool get hasFanClubs => false;
  @override bool get hasShop => false;
  @override bool get hasSmsLedger => false;
  @override bool get hasTicketing => false;
  @override Map<String, bool> get features => {};
  @override String get language => 'en';
  @override String get momoPrefix => '*182*';
  @override MomoConfig get momo => const MomoConfig(ussdTemplate: '', senderName: '', countryCode: '');
  @override String get supabaseAnonKey => 'anon';
  @override String get supabaseUrl => 'https://example';
  @override List<String> get supportedLanguages => ['en'];
  @override String get environment => 'test';
}

class _HomeModule extends FeatureModule {
  @override String get featureKey => 'home';
  @override TabRoute get tabRoute => TabRoute(path: '/home', label: 'Home', icon: Icons.home, builder: (c, s) => const _FakeHomeScreen());
}

class _OnboardingModule extends FeatureModule {
  @override String get featureKey => 'onboarding';
  @override List<RouteBase> get standaloneRoutes => [
    GoRoute(path: '/splash', builder: (c, s) => const _FakeSplashScreen()),
    GoRoute(path: '/onboarding', builder: (c, s) => const _FakeOnboardingScreen()),
  ];
}
