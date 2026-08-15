import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_settings/src/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:test_support/app_font_loader.dart';
import 'package:test_support/touch_target_audit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets('settings shows streamlined menu items', (tester) async {
    await tester.pumpWidget(_buildSettingsApp());
    await tester.pumpAndSettle();

    // Account section
    expect(find.text('Edit profile'), findsOneWidget);

    // Scroll to reveal Preferences.
    await tester.scrollUntilVisible(find.text('Notifications'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expectTapTargetsMeetMinimum(tester);

    // Scroll to reveal Support section
    await tester.scrollUntilVisible(find.text('Help & support'), 200);
    await tester.pumpAndSettle();

    // Support section
    expect(find.text('Help & support'), findsOneWidget);
    expect(find.text('Privacy policy'), findsNothing);
    expectTapTargetsMeetMinimum(tester);

    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    expectTapTargetsMeetMinimum(tester);
  });

  testWidgets('settings does not show removed items', (tester) async {
    await tester.pumpWidget(_buildSettingsApp());
    await tester.pumpAndSettle();

    // Deleted screens
    expect(find.text('Language & region'), findsNothing);
    expect(find.text('About Gikundiro'), findsNothing);
    expect(find.text('Rate Gikundiro'), findsNothing);
    expect(find.text('Heritage'), findsNothing);
    expect(find.text('History & honors'), findsNothing);
    expect(find.text('Hall of fame'), findsNothing);
    expect(find.text('Admin workspace'), findsNothing);

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

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('matches the streamlined settings layout at 200 percent text', (
    tester,
  ) async {
    _setMobileSurface(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets(
    'reserves floating navigation clearance in landscape without keyboard double padding',
    (tester) async {
      tester.view.physicalSize = const Size(852, 393);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewPadding = const FakeViewPadding(bottom: 18);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(_buildSettingsApp());
      await tester.pumpAndSettle();

      final inset = tester.widget<Padding>(
        find.byKey(const ValueKey('afri-screen-bottom-inset')),
      );
      final bottom = inset.padding.resolve(TextDirection.ltr).bottom;
      expect(
        bottom,
        AfriClubBottomNav.regularHeight +
            AfriClubBottomNav.bottomMargin +
            AfriClubBottomNav.contentClearance,
      );
      // SafeArea consumes the 18 px system inset before the ListView resolves
      // its own floating-navigation clearance.
      expect(find.byType(SafeArea), findsWidgets);
      expect(bottom, lessThan(220));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact-height landscape keeps Settings navigation and actions usable',
    (tester) async {
      tester.view.physicalSize = const Size(720, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildSettingsApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Edit profile'), 120);
      await tester.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Help & support'), 120);
      await tester.pumpAndSettle();
      expect(find.text('Help & support'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uses compact navigation clearance at 200 percent text', (
    tester,
  ) async {
    _setMobileSurface(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pumpAndSettle();

    final inset = tester.widget<Padding>(
      find.byKey(const ValueKey('afri-screen-bottom-inset')),
    );
    expect(
      inset.padding.resolve(TextDirection.ltr).bottom,
      AfriClubBottomNav.compactHeight +
          AfriClubBottomNav.bottomMargin +
          AfriClubBottomNav.contentClearance,
    );
    expect(tester.takeException(), isNull);
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
    overrides: [
      currentUserProvider.overrideWith((ref) => null),
      supportWhatsAppProvider.overrideWith((ref) async => '250000000000'),
    ],
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
