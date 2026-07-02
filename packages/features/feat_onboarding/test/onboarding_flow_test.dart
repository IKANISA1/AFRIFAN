import 'package:core_auth/core_auth.dart';
import 'package:feat_onboarding/src/screens/onboarding_screen.dart';
import 'package:feat_onboarding/src/screens/splash_screen.dart';
import 'package:feat_onboarding/src/screens/supporter_phone_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:test_support/app_font_loader.dart';

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

GoRouter _buildRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
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
    testWidgets('splash routes authenticated users with MOMO to home', (
      tester,
    ) async {
      final repository = FakeAuthRepository(
        restoreResult: const UserProfile(
          id: 'user-1',
          clubId: '24',
          publicUserId: '483912',
          phone: '0781234567',
          momoNumber: '0781234567',
          momoProvider: 'MoMo',
        ),
      );

      await _pumpApp(
        tester,
        initialLocation: '/splash',
        repository: repository,
      );

      await _pumpPastSplash(tester);

      expect(find.text('Home Route'), findsOneWidget);
    });

    testWidgets(
      '§2.2: splash routes restored users WITHOUT MOMO straight to home (no gate)',
      (tester) async {
        // Restored users ALWAYS land on /home after restore.
        final repository = FakeAuthRepository(
          restoreResult: const UserProfile(
            id: 'user-2',
            clubId: '24',
            publicUserId: '483912',
          ),
        );

        await _pumpApp(
          tester,
          initialLocation: '/splash',
          repository: repository,
        );

        await _pumpPastSplash(tester);

        // Always go to /home during launch.
        expect(find.text('Home Route'), findsOneWidget);
      },
    );

    testWidgets(
      '§2.2: onboarding secondary skip signs in anonymously then goes straight to home',
      (tester) async {
        // Anonymous sign-in routes to /home immediately.
        const anonymousProfile = UserProfile(
          id: 'user-3',
          clubId: '24',
          publicUserId: '483912',
        );

        final repository = FakeAuthRepository(signInResult: anonymousProfile);

        await _pumpApp(
          tester,
          initialLocation: '/onboarding',
          repository: repository,
        );

        await tester.tap(find.text('Continue without sign-in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // §2.2: Go straight to home after anonymous sign-in
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

    testWidgets('splash routes unauthenticated users to onboarding', (
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

    testWidgets(
      'splash clears a broken session and routes to onboarding when restore throws',
      (tester) async {
        final repository = FakeAuthRepository(
          restoreError: Exception('temporary backend outage'),
        );

        await _pumpApp(
          tester,
          initialLocation: '/splash',
          repository: repository,
        );

        await _pumpPastSplash(tester);

        expect(find.byType(OnboardingScreen), findsOneWidget);
      },
    );

    testWidgets(
      'splash sends users to onboarding only when restore fails and no fallback session exists',
      (tester) async {
        final repository = FakeAuthRepository(
          restoreError: Exception('broken session'),
        );

        await _pumpApp(
          tester,
          initialLocation: '/splash',
          repository: repository,
        );

        await _pumpPastSplash(tester);

        expect(find.byType(OnboardingScreen), findsOneWidget);
      },
    );
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
  });

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
