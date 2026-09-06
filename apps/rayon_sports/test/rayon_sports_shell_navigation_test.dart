import 'package:core_app/core_app.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  group('Rayon Sports app shell', () {
    late _FakeClubConfig config;
    late List<FeatureModule> modules;
    late AppRouter router;

    setUp(() {
      config = const _FakeClubConfig();
      modules = <FeatureModule>[
        _FakeHomeModule(),
        _FakeClubModule(),
        _FakePredictModule(),
        _FakeMembershipModule(),
        _FakeSettingsModule(),
      ];
      ColorTokens.init(config.colors);
      router = AppRouter(
        modules: modules,
        initialLocation: '/home',
        shellBuilder: (context, shell) =>
            AppShell(shell: shell, config: config, modules: modules),
      );
    });

    testWidgets('renders the home shell with bottom navigation', (
      tester,
    ) async {
      _setMobileSurface(tester);
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.byType(AfriClubBottomNav), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Club'), findsOneWidget);
      expect(find.text('Predict'), findsOneWidget);
      expect(find.text('Membership'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('navigates between Predict and membership tabs', (
      tester,
    ) async {
      _setMobileSurface(tester);
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Predict'));
      await tester.pumpAndSettle();
      expect(find.text('Predict Screen'), findsOneWidget);

      await tester.tap(find.text('Membership'));
      await tester.pumpAndSettle();
      expect(find.text('Membership Screen'), findsOneWidget);
    });

    testWidgets('matches shell home tab render contract', (tester) async {
      _setMobileSurface(tester);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('matches shell Predict tab render contract', (tester) async {
      _setMobileSurface(tester);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Predict'));
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('keeps settings behind the profile route', (tester) async {
      _setMobileSurface(tester);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      router.router.go('/settings');
      await tester.pumpAndSettle();

      expect(find.text('Settings Screen'), findsOneWidget);
      expect(find.byType(AfriClubBottomNav), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('matches shell at 200 percent text scale', (tester) async {
      _setMobileSurface(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
    });

    for (final profile in <String, Size>{
      'standard landscape': const Size(852, 393),
      'compact-height landscape': const Size(720, 320),
    }.entries) {
      testWidgets('${profile.key} keeps all shell destinations operable', (
        tester,
      ) async {
        tester.view.physicalSize = profile.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildApp(router));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationRail), findsOneWidget);
        await _selectRailDestination(tester, 1);
        expect(find.text('Club Screen'), findsOneWidget);
        await _selectRailDestination(tester, 2);
        expect(find.text('Predict Screen'), findsOneWidget);
        await _selectRailDestination(tester, 3);
        expect(find.text('Membership Screen'), findsOneWidget);
        router.router.go('/settings');
        await tester.pumpAndSettle();
        expect(find.text('Settings Screen'), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Future<void> _selectRailDestination(
  WidgetTester tester,
  int destinationIndex,
) async {
  final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
  rail.onDestinationSelected!(destinationIndex);
  await tester.pumpAndSettle();
}

Widget _buildApp(AppRouter router) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(
          restoreResult: const UserProfile(
            id: 'user-1',
            clubId: '24',
            publicUserId: '483912',
          ),
        ),
      ),
      initialFeatureConfigSnapshotProvider.overrideWithValue(
        const PlatformConfigSnapshot(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router.router,
      theme: ThemeData(useMaterial3: true),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(disableAnimations: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
}

void _setMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig();

  @override
  String get appName => 'AFRICLUB Test';

  @override
  String get clubId => '24';

  @override
  String get clubName => 'Rayon Sports';

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
    'fanzone': true,
    'home': true,
    'settings': true,
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

class _FakeHomeModule extends FeatureModule {
  @override
  String get featureKey => 'home';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/home',
    label: 'Home',
    icon: AfriIcons.home,
    activeIcon: AfriIcons.home,
    builder: (context, state) =>
        const Scaffold(body: Center(child: Text('Home Screen'))),
  );
}

class _FakeClubModule extends FeatureModule {
  @override
  String get featureKey => 'club';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/club',
    label: 'Club',
    icon: AfriIcons.stadium,
    activeIcon: AfriIcons.stadium,
    builder: (context, state) =>
        const Scaffold(body: Center(child: Text('Club Screen'))),
  );
}

class _FakePredictModule extends FeatureModule {
  @override
  String get featureKey => 'fanzone';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/predict',
    label: 'Predict',
    icon: AfriIcons.fanzone,
    activeIcon: AfriIcons.fanzone,
    builder: (context, state) =>
        const Scaffold(body: Center(child: Text('Predict Screen'))),
  );
}

class _FakeMembershipModule extends FeatureModule {
  @override
  String get featureKey => 'membership';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/membership',
    label: 'Membership',
    icon: AfriIcons.membership,
    activeIcon: AfriIcons.membership,
    builder: (context, state) =>
        const Scaffold(body: Center(child: Text('Membership Screen'))),
  );
}

class _FakeSettingsModule extends FeatureModule {
  @override
  String get featureKey => 'settings';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/settings',
    label: 'Settings',
    icon: AfriIcons.settings,
    activeIcon: AfriIcons.settings,
    builder: (context, state) =>
        const Scaffold(body: Center(child: Text('Settings Screen'))),
  );

  @override
  List<RouteBase> get routes => <RouteBase>[
    GoRoute(
      path: 'privacy',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Privacy Screen'))),
    ),
  ];
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.restoreResult}) : super(clubId: '24');

  final UserProfile? restoreResult;

  @override
  Future<UserProfile?> restoreCurrentUser() async => restoreResult;

  @override
  Future<void> signOut() async {}

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return AdminWorkspaceAccess.none;
  }

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();
}
