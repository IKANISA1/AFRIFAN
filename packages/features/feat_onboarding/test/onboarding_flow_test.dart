import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_onboarding/feat_onboarding.dart';
import 'package:feat_onboarding/src/screens/onboarding_screen.dart';
import 'package:feat_onboarding/src/screens/supporter_phone_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:test_support/app_font_loader.dart';
import 'package:test_support/touch_target_audit.dart';

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({
    this.restoreResult,
    this.restoreError,
    this.signInResult,
    this.updateResult,
  }) : super(clubId: '24');

  final UserProfile? restoreResult;
  final Object? restoreError;
  final UserProfile? signInResult;
  final UserProfile? updateResult;

  UserProfile? lastUpdatedProfile;

  @override
  Future<UserProfile?> restoreCurrentUser() async {
    if (restoreError != null) {
      throw restoreError!;
    }
    return restoreResult;
  }

  @override
  Future<UserProfile> signInAnonymously() async {
    if (signInResult == null) {
      throw Exception('No fake anonymous sign-in profile configured.');
    }
    return signInResult!;
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    lastUpdatedProfile = profile;
    return updateResult ?? profile;
  }

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

class _RayonTestConfig extends ClubConfig {
  const _RayonTestConfig({
    this.id = '24',
    this.club = 'Rayon Sports FC',
    this.app = 'Gikundiro',
  });

  final String id;
  final String club;
  final String app;

  @override
  String get clubId => id;

  @override
  String get clubName => club;

  @override
  String get appName => app;

  @override
  String get country => 'Rwanda';

  @override
  String get countryCode => 'RW';

  @override
  String get language => 'en';

  @override
  String get momoPrefix => '*182*';

  @override
  String get currency => 'RWF';

  @override
  String get currencySymbol => 'RWF';

  @override
  ClubColors get colors => const ClubColors(
    primary: ColorTokens.referenceAccountBlue,
    secondary: ColorTokens.referenceAccountNavy,
    accent: ColorTokens.referenceTrophyGold,
    gradient: [
      ColorTokens.referenceAccountNavy,
      ColorTokens.referenceAccountBlue,
    ],
  );

  @override
  String get supabaseUrl => 'https://example.supabase.co';

  @override
  String get supabaseAnonKey => 'anon';

  @override
  List<String> get supportedLanguages => const ['en'];

  @override
  bool get hasFanClubs => true;

  @override
  bool get hasShop => true;

  @override
  bool get hasTicketing => true;

  @override
  bool get hasChat => true;

  @override
  MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*182*8*1*{amount}*{momo}#',
    countryCode: 'RW',
  );
}

GoRouter _buildRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      OnboardingModule().routes.whereType<GoRoute>().singleWhere(
        (route) => route.path == '/splash',
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/phone',
        builder: (context, state) => const SupporterPhoneAuthScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => const SupporterOtpVerificationScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home Route')),
      ),
    ],
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  required FakeAuthRepository repository,
}) async {
  _setMobileSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        theme: _testTheme(),
        routerConfig: _buildRouter(initialLocation),
      ),
    ),
  );
}

ThemeData _testTheme() {
  return ThemeData(splashFactory: NoSplash.splashFactory);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
  });
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          disableAnimations: true,
          reduceMotion: true,
        );
  });
  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  group('Onboarding auth flow — §2.2 compliant', () {
    testWidgets(
      '§2.2: onboarding guest browsing reaches Home without authentication',
      (tester) async {
        // Public browsing must work without the anonymous authentication service.
        final repository = FakeAuthRepository(restoreResult: null);

        await _pumpApp(
          tester,
          initialLocation: '/onboarding',
          repository: repository,
        );

        await tester.tap(find.text('Continue without sign-in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Guest discovery remains available without a session.
        expect(find.text('Home Route'), findsOneWidget);
      },
    );

    testWidgets(
      'onboarding exposes the OTP entry route from the welcome screen',
      (tester) async {
        final repository = FakeAuthRepository(restoreResult: null);

        await _pumpApp(
          tester,
          initialLocation: '/onboarding',
          repository: repository,
        );

        await tester.tap(find.text('Continue with WhatsApp'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(SupporterPhoneAuthScreen), findsOneWidget);
      },
    );

    testWidgets('legacy splash link opens the canonical onboarding screen', (
      tester,
    ) async {
      final repository = FakeAuthRepository(restoreResult: null);

      await _pumpApp(
        tester,
        initialLocation: '/splash',
        repository: repository,
      );

      await _pumpPastSplash(tester);

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });

  testWidgets('matches the onboarding editorial layout on mobile', (
    tester,
  ) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: _testTheme(), home: const OnboardingScreen()),
      ),
    );

    await tester.pump();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expectTapTargetsMeetMinimum(tester);
  });

  for (final club in const [
    _RayonTestConfig(id: '44', club: "Vital'O FC", app: "Vital'O"),
    _RayonTestConfig(id: '26', club: 'Nkana FC', app: 'Nkana FC'),
    _RayonTestConfig(id: '6', club: 'AS Vita Club', app: 'AS Vita Club'),
  ]) {
    testWidgets(
      '${club.appName} keeps its identity and excludes Rayon photos',
      (tester) async {
        _setMobileSurface(tester);
        await tester.pumpWidget(
          ProviderScope(
            child: ClubConfigScope(
              config: club,
              child: const MaterialApp(
                home: OnboardingScreen(mediaRightsApproved: true),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text('Follow ${club.clubName} wherever supporters gather.'),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Image && widget.image is! AssetImage,
          ),
          findsNothing,
        );
        expect(
          tester
              .widget<AfriGovernedImage>(find.byType(AfriGovernedImage))
              .rightsApproved,
          isFalse,
        );
        await tester.flingFrom(
          const Offset(350, 250),
          const Offset(-320, 0),
          900,
        );
        await tester.pumpAndSettle();
        expect(find.text('Every moment.\nOne club family.'), findsOneWidget);
        await tester.flingFrom(
          const Offset(350, 250),
          const Offset(-320, 0),
          900,
        );
        await tester.pumpAndSettle();
        expect(find.text('Closer to\n${club.appName}.'), findsOneWidget);
        expect(find.textContaining('Gikundiro'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Image && widget.image is! AssetImage,
          ),
          findsNothing,
        );
      },
    );
  }

  testWidgets('onboarding first viewport uses Rayon club identity', (
    tester,
  ) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      const ProviderScope(
        child: ClubConfigScope(
          config: _RayonTestConfig(),
          child: MaterialApp(home: OnboardingScreen()),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Your club.\nYour matchday.'), findsOneWidget);
    expect(
      find.text('Follow Rayon Sports FC wherever supporters gather.'),
      findsOneWidget,
    );
    expect(find.text('RS'), findsNothing);
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .where((image) => image.image is AssetImage),
      hasLength(1),
    );
    expect(find.byType(PageView), findsOneWidget);
    final governedImage = tester.widget<AfriGovernedImage>(
      find.byType(AfriGovernedImage),
    );
    expect(governedImage.rightsApproved, isFalse);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is! AssetImage,
      ),
      findsNothing,
    );
  });

  testWidgets('onboarding exposes three swipeable governed media slides', (
    tester,
  ) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      const ProviderScope(
        child: ClubConfigScope(
          config: _RayonTestConfig(),
          child: MaterialApp(home: OnboardingScreen(mediaRightsApproved: true)),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is! AssetImage,
      ),
      findsOneWidget,
    );

    await tester.flingFrom(const Offset(350, 250), const Offset(-320, 0), 900);
    await tester.pumpAndSettle();
    expect(find.text('Every moment.\nOne club family.'), findsOneWidget);

    await tester.flingFrom(const Offset(350, 250), const Offset(-320, 0), 900);
    await tester.pumpAndSettle();
    expect(find.text('Closer to\nGikundiro.'), findsOneWidget);
    expect(find.text('Continue with WhatsApp'), findsOneWidget);
  });

  testWidgets(
    'reduced motion keeps onboarding static without delaying its actions',
    (tester) async {
      _setMobileSurface(tester);

      await tester.pumpWidget(
        const ProviderScope(
          child: ClubConfigScope(
            config: _RayonTestConfig(),
            child: MaterialApp(home: OnboardingScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Your club.\nYour matchday.'), findsOneWidget);
      expect(
        tester
            .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
            .every((widget) => widget.duration == Duration.zero),
        isTrue,
      );
      expect(
        tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .every((widget) => widget.duration == Duration.zero),
        isTrue,
      );

      await tester.pump(AfriMotion.carouselInterval * 2);

      expect(find.text('Your club.\nYour matchday.'), findsOneWidget);
      expect(find.text('Continue with WhatsApp'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets(
    'preserves the active onboarding media slide across rotation and resume',
    (tester) async {
      _setMobileSurface(tester);

      await tester.pumpWidget(
        const ProviderScope(
          child: ClubConfigScope(
            config: _RayonTestConfig(),
            child: MaterialApp(home: OnboardingScreen()),
          ),
        ),
      );
      await tester.pump();

      await tester.flingFrom(
        const Offset(350, 250),
        const Offset(-320, 0),
        900,
      );
      await tester.pumpAndSettle();
      expect(find.text('Every moment.\nOne club family.'), findsOneWidget);

      tester.view.physicalSize = const Size(852, 393);
      await tester.pumpAndSettle();
      expect(find.text('Every moment.\nOne club family.'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Every moment.\nOne club family.'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('matches the compressed onboarding surface at 200 percent text', (
    tester,
  ) async {
    _setMobileSurface(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: _testTheme(), home: const OnboardingScreen()),
      ),
    );

    await tester.pump();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('onboarding stays usable on compact-height viewports', (
    tester,
  ) async {
    _setCompactSurface(tester);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: _testTheme(), home: const OnboardingScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Continue with WhatsApp'), findsOneWidget);
    expect(find.text('Continue without sign-in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in const <Locale>[
    Locale('en'),
    Locale('en'),
    Locale('en'),
  ]) {
    testWidgets('localized onboarding fits compact 200 percent text in '
        '${locale.languageCode}', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final l10n = lookupAfriLocalizations(locale);

      await tester.pumpWidget(
        ProviderScope(
          child: ClubConfigScope(
            config: const _RayonTestConfig(),
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: const <Locale>[Locale('en')],
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                AfriLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => AfriLocalizationsScope(
                locale: locale,
                child: child ?? const SizedBox.shrink(),
              ),
              theme: _testTheme(),
              home: const OnboardingScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(l10n.onboardingBelongTitle), findsOneWidget);
      await tester.ensureVisible(find.text(l10n.onboardingContinueWhatsApp));
      await tester.ensureVisible(
        find.text(l10n.onboardingContinueWithoutSignIn),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'onboarding media and actions stay usable in compact-height landscape',
    (tester) async {
      tester.view.physicalSize = const Size(720, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: _testTheme(),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
      await tester.ensureVisible(find.text('Continue with WhatsApp'));
      await tester.ensureVisible(find.text('Continue without sign-in'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('onboarding caps interactive content on tablet width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: _testTheme(), home: const OnboardingScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(AfriScreenScaffold), findsOneWidget);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('onboarding-responsive-content')),
          )
          .width,
      AfriResponsive.tabletContentMax,
    );
    expect(tester.takeException(), isNull);
  });

  for (final profile in _compactGoldenProfiles) {
    testWidgets('golden compact onboarding route ${profile.id}', (
      tester,
    ) async {
      _setGoldenSurface(tester, profile.size);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      ColorTokens.setBrightness(profile.brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(restoreResult: null),
            ),
          ],
          child: ClubConfigScope(
            config: const _RayonTestConfig(),
            child: MaterialApp(
              theme: ClubTheme.from(
                const _RayonTestConfig(),
                brightness: profile.brightness,
              ),
              home: const RepaintBoundary(
                key: ValueKey<String>('onboarding-route-golden'),
                child: OnboardingScreen(),
              ),
            ),
          ),
        ),
      );
      // Decode the published crest before capture; a single fake-clock frame
      // can finish before AssetImage IO and produce a blank brand mark.
      final brand = find.byType(AfriBrandMark);
      final crest = tester.widget<Image>(
        find.descendant(of: brand, matching: find.byType(Image)),
      );
      await tester.runAsync(
        () => precacheImage(crest.image, tester.element(brand)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RawImage>(
              find.descendant(of: brand, matching: find.byType(RawImage)),
            )
            .image,
        isNotNull,
      );
      final whatsapp = find.byKey(
        const ValueKey<String>('onboarding-whatsapp-action'),
      );
      expect(
        find.descendant(
          of: whatsapp,
          matching: find.text('Continue with WhatsApp'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: whatsapp, matching: find.byType(Icon)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey<String>('onboarding-route-golden')),
        matchesGoldenFile('goldens/onboarding_${profile.id}.png'),
      );
    });
  }
}

const _compactGoldenProfiles =
    <({String id, Size size, Brightness brightness})>[
      (
        id: 'compact_dark_320x760',
        size: Size(320, 760),
        brightness: Brightness.dark,
      ),
      (
        id: 'compact_light_374x812',
        size: Size(374, 812),
        brightness: Brightness.light,
      ),
      (
        id: 'standard_dark_390x844',
        size: Size(390, 844),
        brightness: Brightness.dark,
      ),
      (
        id: 'large_light_430x900',
        size: Size(430, 900),
        brightness: Brightness.light,
      ),
      (
        id: 'wide_dark_599x900',
        size: Size(599, 900),
        brightness: Brightness.dark,
      ),
      (
        id: 'foldable_half_light_674x842',
        size: Size(674, 842),
        brightness: Brightness.light,
      ),
      (
        id: 'tablet_dark_834x1194',
        size: Size(834, 1194),
        brightness: Brightness.dark,
      ),
    ];

void _setGoldenSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: true,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _pumpPastSplash(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump();
}

void _setMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setCompactSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(752, 435);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
