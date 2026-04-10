import 'package:core_app/core_app.dart';
import 'package:core_auth/core_auth.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/widgets/match_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rayon_sports/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('restores an authenticated fan into the production home shell', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          disableAnimations: true,
          reduceMotion: true,
        );

    await startRayonSportsApp(
      options: AfriClubBootstrapOptions(
        startupOptions: const AppStartupOptions.integrationTest(),
        authRepository: _FakeAuthRepository(
          restoreResult: const UserProfile(
            id: 'user-1',
            clubId: '24',
            publicUserId: '483912',
            momoNumber: '0788123456',
            momoProvider: 'MoMo',
            languageCode: 'en',
          ),
        ),
        providerOverrides: [
          homeFeedRepositoryProvider.overrideWithValue(
            const _FakeHomeFeedRepository(
              snapshot: HomeFeedSnapshot(
                heroSlides: [
                  MatchSlide(
                    homeTeam: 'RAYON SPORTS',
                    awayTeam: 'APR FC',
                    venue: 'AMAHORO STADIUM',
                    status: 'ON SALE',
                    dateInfo: '12 APR • 18:00',
                    route: '/tickets',
                  ),
                ],
                status: HomeFeedStatus.success,
              ),
            ),
          ),
          latestIntelRepositoryProvider.overrideWithValue(
            const _FakeLatestIntelRepository(
              LatestIntelSnapshot(
                status: LatestIntelStatus.ready,
                articles: [
                  {
                    'id': 'article-1',
                    'title': 'Training ground update',
                    'subtitle': 'First-team preparations continue this week.',
                  },
                ],
              ),
            ),
          ),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text('QUICK ACTIONS'));

    expect(find.text('QUICK ACTIONS'), findsOneWidget);
    expect(find.text('LATEST INTEL'), findsOneWidget);
    expect(find.text('Training ground update'), findsOneWidget);
  });

  testWidgets(
    'routes back to onboarding when an existing session cannot be restored safely',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            accessibleNavigation: true,
            disableAnimations: true,
            reduceMotion: true,
          );

      await startRayonSportsApp(
        options: AfriClubBootstrapOptions(
          startupOptions: const AppStartupOptions.integrationTest(),
          authRepository: _FakeAuthRepository(
            restoreError: Exception('temporary profile hydration failure'),
          ),
          providerOverrides: [
            homeFeedRepositoryProvider.overrideWithValue(
              const _FakeHomeFeedRepository(
                snapshot: HomeFeedSnapshot(
                  heroSlides: [
                    MatchSlide(
                      homeTeam: 'RAYON SPORTS',
                      awayTeam: 'APR FC',
                      venue: 'AMAHORO STADIUM',
                      status: 'ON SALE',
                      dateInfo: '12 APR • 18:00',
                      route: '/tickets',
                    ),
                  ],
                  status: HomeFeedStatus.success,
                ),
              ),
            ),
            latestIntelRepositoryProvider.overrideWithValue(
              const _FakeLatestIntelRepository(
                LatestIntelSnapshot(
                  status: LatestIntelStatus.ready,
                  articles: [
                    {
                      'id': 'article-1',
                      'title': 'Training ground update',
                      'subtitle': 'First-team preparations continue this week.',
                    },
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('NEXT'));

      expect(find.text('NEXT'), findsOneWidget);
    },
  );

  testWidgets('current production release keeps BioPay entry points visible', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          disableAnimations: true,
          reduceMotion: true,
        );

    await startRayonSportsApp(
      options: AfriClubBootstrapOptions(
        startupOptions: const AppStartupOptions.integrationTest(),
        authRepository: _FakeAuthRepository(),
        initialLocation: '/settings',
        providerOverrides: [
          currentUserProvider.overrideWith(
            (ref) => const UserProfile(
              id: 'user-1',
              clubId: '24',
              publicUserId: '483912',
              momoNumber: '0788123456',
              momoProvider: 'MoMo',
              languageCode: 'en',
            ),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text('BioPay & Privacy'));

    expect(find.text('BioPay & Privacy'), findsOneWidget);
    expect(find.text('Privacy Controls'), findsOneWidget);
    expect(find.text('BioPay Home'), findsOneWidget);
    expect(find.text('Face ID & Enrollment'), findsOneWidget);
  });
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.restoreResult, this.restoreError})
    : super(clubId: '24');

  final UserProfile? restoreResult;
  final Object? restoreError;

  @override
  Future<UserProfile?> restoreCurrentUser() async {
    if (restoreError != null) {
      throw restoreError!;
    }
    return restoreResult;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<UserProfile> signInAnonymously() async {
    throw UnimplementedError('Anonymous sign-in is not used in smoke tests.');
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async => profile;

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return AdminWorkspaceAccess.none;
  }
}

class _FakeHomeFeedRepository implements HomeFeedRepository {
  const _FakeHomeFeedRepository({required this.snapshot});

  final HomeFeedSnapshot snapshot;

  @override
  Future<HomeFeedSnapshot> load() async => snapshot;
}

class _FakeLatestIntelRepository implements LatestIntelRepository {
  const _FakeLatestIntelRepository(this.snapshot);

  final LatestIntelSnapshot snapshot;

  @override
  Future<LatestIntelSnapshot> loadPublishedArticles() async => snapshot;
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 150));
  }

  expect(finder, findsOneWidget);
}
