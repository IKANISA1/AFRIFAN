import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_settings/src/screens/about_screen.dart';
import 'package:feat_settings/src/screens/help_support_screen.dart';
import 'package:feat_settings/src/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(loadDesignFonts);

  testWidgets('about screen shows actionable policy and support actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Club Website'), findsOneWidget);
    expect(find.text('Open Source Licenses'), findsOneWidget);
    expect(find.text('CONTACT SUPPORT'), findsOneWidget);
    expect(find.text('RATE THIS APP'), findsOneWidget);
  });

  testWidgets('help screen shows website, whatsapp, and export request', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
    await tester.pumpAndSettle();

    expect(find.text('OFFICIAL WEBSITE'), findsOneWidget);
    expect(find.text('WHATSAPP SUPPORT'), findsOneWidget);

    final returnButton = find.text('RETURN TO SETTINGS');
    await tester.scrollUntilVisible(returnButton, 200);
    expect(returnButton, findsOneWidget);
    expect(find.text('REQUEST DATA EXPORT'), findsOneWidget);
  });

  testWidgets(
    'settings shows BioPay entries only when enabled and routes exist',
    (tester) async {
      const config = _FakeClubConfig(hasBiopay: true);

      await tester.pumpWidget(
        _buildSettingsApp(config: config, includeBiopayRoutes: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('BioPay & Privacy'), findsOneWidget);
      expect(find.text('BioPay Home'), findsOneWidget);
      expect(find.text('Face ID & Enrollment'), findsOneWidget);
      expect(find.text('QR Receive & Pay'), findsOneWidget);
      expect(find.text('NFC Receive & Pay'), findsOneWidget);
    },
  );

  testWidgets('settings hides BioPay entries when routes are unavailable', (
    tester,
  ) async {
    const config = _FakeClubConfig(hasBiopay: true);

    await tester.pumpWidget(
      _buildSettingsApp(config: config, includeBiopayRoutes: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIVACY'), findsOneWidget);
    expect(find.text('BioPay & Privacy'), findsNothing);
    expect(find.text('BioPay Home'), findsNothing);
    expect(find.text('Face ID & Enrollment'), findsNothing);
  });

  testWidgets('settings hides BioPay entries when feature flag is disabled', (
    tester,
  ) async {
    const config = _FakeClubConfig(hasBiopay: false);

    await tester.pumpWidget(
      _buildSettingsApp(config: config, includeBiopayRoutes: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIVACY'), findsOneWidget);
    expect(find.text('BioPay & Privacy'), findsNothing);
    expect(find.text('BioPay Home'), findsNothing);
    expect(find.text('Face ID & Enrollment'), findsNothing);
  });

  testWidgets('matches the shared settings glass layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      _buildSettingsApp(
        config: const _FakeClubConfig(hasBiopay: true),
        includeBiopayRoutes: true,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_screen.png'),
    );
  });
}

Widget _buildSettingsApp({
  required _FakeClubConfig config,
  required bool includeBiopayRoutes,
}) {
  final routes = <RouteBase>[
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ];

  if (includeBiopayRoutes) {
    routes.addAll(<RouteBase>[
      GoRoute(
        path: '/biopay',
        name: 'biopay',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/biopay/profile',
        name: 'biopay_profile',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/biopay/qr',
        name: 'biopay_qr',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/biopay/nfc',
        name: 'biopay_nfc',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ]);
  }

  final router = GoRouter(initialLocation: '/settings', routes: routes);

  return ProviderScope(
    overrides: [currentUserProvider.overrideWith((ref) => null)],
    child: ClubConfigScope(
      config: config,
      child: MaterialApp.router(
        theme: ClubTheme.from(config),
        routerConfig: router,
      ),
    ),
  );
}

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig({required this.hasBiopay});

  @override
  final bool hasBiopay;

  @override
  String get appName => 'Gikundiro';

  @override
  String get clubId => '24';

  @override
  String get clubName => 'Rayon Sports FC';

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
  String get currencySymbol => 'FRw';

  @override
  bool get hasChat => true;

  @override
  bool get hasFanClubs => true;

  @override
  bool get hasShop => true;

  @override
  bool get hasSmsLedger => true;

  @override
  bool get hasTicketing => true;

  @override
  Map<String, bool> get features => <String, bool>{
    'biopay': hasBiopay,
    'fan_clubs': hasFanClubs,
    'shop': hasShop,
    'ticketing': hasTicketing,
    'chat': hasChat,
    'sms_ledger': hasSmsLedger,
  };

  @override
  String get language => 'rw';

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
  List<String> get supportedLanguages => const <String>['rw', 'fr', 'en'];
}

void _setMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
