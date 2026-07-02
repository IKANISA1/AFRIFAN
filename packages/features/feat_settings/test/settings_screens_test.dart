import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_settings/src/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  testWidgets('settings shows streamlined menu items', (tester) async {
    await tester.pumpWidget(_buildSettingsApp());
    await tester.pumpAndSettle();

    // Account section
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);

    // Scroll to reveal Support section
    await tester.scrollUntilVisible(find.text('Help & support'), 200);
    await tester.pumpAndSettle();

    // Support section
    expect(find.text('Help & support'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('settings does not show removed items', (tester) async {
    await tester.pumpWidget(_buildSettingsApp());
    await tester.pumpAndSettle();

    // Deleted screens
    expect(find.text('Language & region'), findsNothing);
    expect(find.text('About Gikundiro'), findsNothing);
    expect(find.text('Rate Gikundiro'), findsNothing);

    // Report a problem merged into Help
    expect(find.text('Report a problem'), findsNothing);
  });

  testWidgets('settings no longer shows account-level MOMO linking', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSettingsApp());
    await tester.pumpAndSettle();

    expect(find.text('MOMO linked'), findsNothing);
    expect(find.text('MOMO (optional)'), findsNothing);
    expect(find.text('Link MoMo number'), findsNothing);
  });

  testWidgets('matches the streamlined settings layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_screen.png'),
    );
  });

  testWidgets('matches the streamlined settings layout at 200 percent text', (
    tester,
  ) async {
    _setMobileSurface(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_screen_large_text.png'),
    );
  });
}

Widget _buildSettingsApp({_FakeClubConfig? config}) {
  final effectiveConfig = config ?? const _FakeClubConfig();
  final router = GoRouter(
    initialLocation: '/settings',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [currentUserProvider.overrideWith((ref) => null)],
    child: ClubConfigScope(
      config: effectiveConfig,
      child: MaterialApp.router(
        theme: ClubTheme.from(effectiveConfig),
        routerConfig: router,
      ),
    ),
  );
}

class _FakeClubConfig implements ClubConfig {
  const _FakeClubConfig();

  @override
  String get appName => 'Gikundiro';

  @override
  String get clubId => '24';

  @override
  String get clubName => 'Rayon Sports FC';

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
  String get crestAsset => 'assets/crest/rayon_sports_crest.png';

  @override
  String get currency => 'RWF';

  @override
  String get currencySymbol => 'RWF';

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

  @override
  String get environment => 'test';

  @override
  Map<String, bool> get features => const <String, bool>{
    'fan_clubs': true,
    'shop': true,
    'ticketing': true,
    'chat': true,
    'sms_ledger': true,
  };
}

void _setMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
