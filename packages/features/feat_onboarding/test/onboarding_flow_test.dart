import 'package:core_auth/core_auth.dart';
import 'package:feat_onboarding/src/screens/onboarding_screen.dart';
import 'package:feat_onboarding/src/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({
    this.restoreResult,
    this.restoreError,
    this.fallbackProfile,
    this.signInResult,
    this.updateResult,
  }) : super(clubId: '24');

  final UserProfile? restoreResult;
  final Object? restoreError;
  final UserProfile? fallbackProfile;
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
  Future<UserProfile?> restoreSessionFallbackProfile() async {
    return fallbackProfile;
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
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return AdminWorkspaceAccess.none;
  }
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: _buildRouter(initialLocation)),
    ),
  );
}

void main() {
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

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Home Route'), findsOneWidget);
    });

    testWidgets(
      '§2.2: splash routes restored users WITHOUT MOMO straight to home (no gate)',
      (tester) async {
        // Previously this test expected /profile_setup. §2.2 mandates
        // that users ALWAYS land on /home after restore — no MOMO gate.
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

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // §2.2: Always go to /home — never gate on MOMO during launch
        expect(find.text('Home Route'), findsOneWidget);
      },
    );

    testWidgets(
      '§2.2: onboarding GET STARTED signs in anonymously then goes straight to home',
      (tester) async {
        // Previously this test expected /profile_setup after GET STARTED.
        // §2.2 mandates: anonymous sign-in → /home immediately.
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

        await tester.pumpAndSettle();
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('GET STARTED'));
        await tester.pumpAndSettle();

        // §2.2: Go straight to home after anonymous sign-in
        expect(find.text('Home Route'), findsOneWidget);
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

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets(
      'splash preserves an existing user via fallback profile when restore throws',
      (tester) async {
        final repository = FakeAuthRepository(
          restoreError: Exception('temporary backend outage'),
          fallbackProfile: const UserProfile(
            id: 'user-fallback',
            clubId: '24',
            publicUserId: '483912',
            momoNumber: '0781234567',
            momoProvider: 'MoMo',
          ),
        );

        await _pumpApp(
          tester,
          initialLocation: '/splash',
          repository: repository,
        );

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(find.text('Home Route'), findsOneWidget);
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

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingScreen), findsOneWidget);
      },
    );
  });
}
