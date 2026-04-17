import 'package:core_app/core_app.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Rayon Sports app shell', () {
    late _FakeClubConfig config;
    late List<FeatureModule> modules;
    late AppRouter router;

    setUp(() {
      config = const _FakeClubConfig();
      modules = <FeatureModule>[
        _FakeHomeModule(),
        _FakeChallengeModule(),
        _FakeSettingsModule(),
      ];
      ColorTokens.init(config.colors);
      router = AppRouter(
        modules: modules,
        initialLocation: '/home',
        shellBuilder: (context, shell) => AppShell(
          shell: shell,
          config: config,
          modules: modules,
        ),
      );
    });

    testWidgets('renders the home shell with bottom navigation', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('CHALLENGES'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
    });

    testWidgets('navigates between challenge and settings tabs', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHALLENGES'));
      await tester.pumpAndSettle();
      expect(find.text('Challenge Screen'), findsOneWidget);

      await tester.tap(find.text('SETTINGS'));
      await tester.pumpAndSettle();
      expect(find.text('Settings Screen'), findsOneWidget);
    });
  });
}

Widget _buildApp(AppRouter router) {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: router.router,
      theme: ThemeData(useMaterial3: true),
    ),
  );
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
    primary: Color(0xFF0038A8),
    secondary: Color(0xFF001742),
    accent: Color(0xFFD9B24C),
    gradient: <Color>[Color(0xFF001742), Color(0xFF0038A8)],
  );

  @override
  String get country => 'Rwanda';

  @override
  String get countryCode => 'RW';

  @override
  String get crestAsset => 'assets/crest/rayon_sports_crest.png';

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
    'challenge': true,
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

class _FakeChallengeModule extends FeatureModule {
  @override
  String get featureKey => 'challenge';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/challenge',
    label: 'Challenges',
    icon: AfriIcons.versus,
    activeIcon: AfriIcons.versus,
    builder: (context, state) =>
        const Scaffold(body: Center(child: Text('Challenge Screen'))),
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
