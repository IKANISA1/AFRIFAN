import 'dart:typed_data';

import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_settings/src/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDownAll(() {
    TypographyTokens.debugUseFallbackFonts = false;
  });

  testWidgets('golden shared governed action components', (tester) async {
    _setGoldenSurface(tester, const Size(430, 760));
    const config = _GoldenClubConfig();

    await tester.pumpWidget(
      ClubConfigScope(
        config: config,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ClubTheme.from(config),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('shared-component-golden'),
              child: ColoredBox(
                color: ColorTokens.background,
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Governed actions',
                        style: TypographyTokens.headlineMedium(),
                      ),
                      const SizedBox(height: SpacingTokens.spacing5),
                      AfriButton(label: 'Primary action', onTap: () {}),
                      const SizedBox(height: SpacingTokens.spacing3),
                      AfriButton(
                        label: 'Delete permanently',
                        onTap: () {},
                        variant: AfriButtonVariant.destructive,
                      ),
                      const SizedBox(height: SpacingTokens.spacing5),
                      AfriSplitButton<String>(
                        label: 'Save changes',
                        onPressed: () {},
                        itemBuilder: (context) =>
                            const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'draft',
                                child: Text('Save draft'),
                              ),
                            ],
                        onSelected: (_) {},
                      ),
                      const SizedBox(height: SpacingTokens.spacing5),
                      const AfriMaskedValue(
                        label: 'Private reference',
                        value: 'RW-248391',
                        visibleCharacterCount: 4,
                      ),
                      const SizedBox(height: SpacingTokens.spacing5),
                      AfriGovernedImage(
                        image: MemoryImage(Uint8List(0)),
                        width: 382,
                        height: 150,
                        semanticLabel: 'Supporter media',
                        provenanceId: 'golden-rights-denied',
                        rightsApproved: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey('shared-component-golden')),
      matchesGoldenFile('goldens/shared_governed_actions_430x760.png'),
    );
  });

  for (final scenario in _settingsGoldenScenarios) {
    testWidgets('golden Settings route ${scenario.id}', (tester) async {
      ColorTokens.setBrightness(scenario.brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      await _pumpSettingsGolden(
        tester,
        scenario.size,
        brightness: scenario.brightness,
      );

      await expectLater(
        find.byKey(const ValueKey('dense-settings-golden')),
        matchesGoldenFile('goldens/${scenario.id}.png'),
      );
    });
  }

  testWidgets('golden high-contrast Settings route light', (tester) async {
    ColorTokens.setBrightness(Brightness.light);
    addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
    await _pumpSettingsGolden(
      tester,
      const Size(390, 844),
      brightness: Brightness.light,
      highContrast: true,
    );

    await expectLater(
      find.byKey(const ValueKey('dense-settings-golden')),
      matchesGoldenFile('goldens/settings_high_contrast_light_390x844.png'),
    );
  });
}

const _settingsGoldenScenarios =
    <({String id, Size size, Brightness brightness})>[
      (
        id: 'settings_compact_dark_320x760',
        size: Size(320, 760),
        brightness: Brightness.dark,
      ),
      (
        id: 'settings_compact_light_320x760',
        size: Size(320, 760),
        brightness: Brightness.light,
      ),
      (
        id: 'settings_compact_dark_374x812',
        size: Size(374, 812),
        brightness: Brightness.dark,
      ),
      (
        id: 'settings_compact_light_374x812',
        size: Size(374, 812),
        brightness: Brightness.light,
      ),
      (
        id: 'settings_standard_dark_390x844',
        size: Size(390, 844),
        brightness: Brightness.dark,
      ),
      (
        id: 'settings_standard_light_390x844',
        size: Size(390, 844),
        brightness: Brightness.light,
      ),
      (
        id: 'settings_dense_dark_393x852',
        size: Size(393, 852),
        brightness: Brightness.dark,
      ),
      (
        id: 'settings_large_dark_430x900',
        size: Size(430, 900),
        brightness: Brightness.dark,
      ),
      (
        id: 'settings_large_dark_599x900',
        size: Size(599, 900),
        brightness: Brightness.dark,
      ),
      (
        id: 'settings_foldable_half_light_674x842',
        size: Size(674, 842),
        brightness: Brightness.light,
      ),
      (
        id: 'settings_tablet_dark_720x1024',
        size: Size(720, 1024),
        brightness: Brightness.dark,
      ),
      (
        id: 'settings_tablet_dark_834x1194',
        size: Size(834, 1194),
        brightness: Brightness.dark,
      ),
    ];

const _goldenProfile = UserProfile(
  id: 'golden-user',
  clubId: '24',
  publicUserId: '483912',
  languageCode: 'en',
);

Future<void> _pumpSettingsGolden(
  WidgetTester tester,
  Size size, {
  Brightness brightness = Brightness.dark,
  bool highContrast = false,
}) async {
  _setGoldenSurface(tester, size, highContrast: highContrast);
  const config = _GoldenClubConfig();
  final router = GoRouter(
    initialLocation: '/settings',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings',
        builder: (context, state) => const RepaintBoundary(
          key: ValueKey('dense-settings-golden'),
          child: SettingsScreen(),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        currentUserProvider.overrideWith((ref) => _goldenProfile),
        supportWhatsAppProvider.overrideWith((ref) async => '250000000000'),
      ],
      child: ClubConfigScope(
        config: config,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ClubTheme.from(
            config,
            brightness: brightness,
            highContrast: highContrast,
          ),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Membership details'), findsOneWidget);
  expect(
    tester.getRect(find.text('Membership details')).top,
    lessThan(size.height),
  );
}

void _setGoldenSurface(
  WidgetTester tester,
  Size size, {
  bool highContrast = false,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: true,
        highContrast: highContrast,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

class _GoldenClubConfig implements ClubConfig {
  const _GoldenClubConfig();

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
  bool get hasTicketing => true;
  @override
  String get language => 'en';
  @override
  String get momoPrefix => '*182*';
  @override
  MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*182*{amount}*{momo}#',
    countryCode: 'RW',
  );
  @override
  String get supabaseAnonKey => 'anon';
  @override
  String get supabaseUrl => 'https://example.supabase.co';
  @override
  List<String> get supportedLanguages => const <String>['en'];
  @override
  String get environment => 'golden';
  @override
  Map<String, bool> get features => const <String, bool>{};
}
