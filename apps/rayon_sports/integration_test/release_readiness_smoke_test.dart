import 'package:app_registry/app_registry.dart';
import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_app/bootstrap.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/widgets/match_card.dart';
import 'package:feat_home/src/widgets/quick_actions_grid.dart';
import 'package:feat_onboarding/src/screens/supporter_phone_auth_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:test_support/app_font_loader.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('restores an authenticated fan into the production home shell', (
    tester,
  ) async {
    await _startSmokeApp(
      AfriClubBootstrapOptions(
        modules: AppModuleRegistry.build(const _SmokeRayonSportsConfig()),
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
          initialFeatureConfigSnapshotProvider.overrideWithValue(
            _smokeFeatureSnapshot,
          ),
          homeFeedRepositoryProvider.overrideWithValue(
            const _FakeHomeFeedRepository(
              snapshot: HomeFeedSnapshot(
                heroSlides: [
                  MatchSlide(
                    homeTeam: 'RAYON SPORTS',
                    awayTeam: 'Rayon Sports FC',
                    venue: 'AMAHORO STADIUM',
                    status: 'ON SALE',
                    dateInfo: '12 Rayon Sports • 18:00',
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

    await _pumpAppStartup(tester);
    await _pumpUntilVisible(
      tester,
      find.byType(QuickActionsGrid),
      maxPumps: 60,
    );

    expect(find.byType(QuickActionsGrid), findsOneWidget);
    expect(find.text('Support'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'routes back to onboarding when an existing session cannot be restored safely',
    (tester) async {
      await _startSmokeApp(
        AfriClubBootstrapOptions(
          modules: AppModuleRegistry.build(const _SmokeRayonSportsConfig()),
          startupOptions: const AppStartupOptions.integrationTest(),
          authRepository: _FakeAuthRepository(
            restoreError: Exception('temporary profile hydration failure'),
          ),
          providerOverrides: [
            initialFeatureConfigSnapshotProvider.overrideWithValue(
              _smokeFeatureSnapshot,
            ),
            homeFeedRepositoryProvider.overrideWithValue(
              const _FakeHomeFeedRepository(
                snapshot: HomeFeedSnapshot(
                  heroSlides: [
                    MatchSlide(
                      homeTeam: 'RAYON SPORTS',
                      awayTeam: 'Rayon Sports FC',
                      venue: 'AMAHORO STADIUM',
                      status: 'ON SALE',
                      dateInfo: '12 Rayon Sports • 18:00',
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

      await _pumpAppStartup(tester);
      await _pumpUntilVisible(tester, find.byType(SupporterPhoneAuthScreen));

      expect(find.byType(SupporterPhoneAuthScreen), findsOneWidget);
    },
  );

  testWidgets(
    'current production release keeps settings streamlined after the payment-surface cleanup',
    (tester) async {
      await _startSmokeApp(
        AfriClubBootstrapOptions(
          modules: AppModuleRegistry.build(const _SmokeRayonSportsConfig()),
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
          initialLocation: '/settings',
          providerOverrides: [
            initialFeatureConfigSnapshotProvider.overrideWithValue(
              _smokeFeatureSnapshot,
            ),
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

      await _pumpAppStartup(tester);
      await _pumpUntilVisible(tester, find.text('Settings'), maxPumps: 60);
      await _pumpUntilVisible(tester, find.text('Edit profile'), maxPumps: 60);
      expect(find.text('Privacy'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Help & support'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sign out'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Help & support'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('MOMO linked'), findsNothing);
      expect(find.text('Link MoMo number'), findsNothing);
      expect(find.text('Privacy policy'), findsNothing);
    },
  );
}

Future<void> _startSmokeApp(AfriClubBootstrapOptions options) {
  return bootstrap(const _SmokeRayonSportsConfig(), options: options);
}

const _smokeFeatureSnapshot = PlatformConfigSnapshot(
  contentBlocks: <ContentBlock>[
    ContentBlock(
      blockKey: 'smoke_home_hero',
      blockType: 'widget',
      content: <String, dynamic>{'widget': 'match_score_card'},
      placementKey: 'home_hero',
      sortOrder: 0,
    ),
    ContentBlock(
      blockKey: 'smoke_home_quick_actions',
      blockType: 'widget',
      content: <String, dynamic>{'widget': 'quick_actions_grid'},
      placementKey: 'home_top',
      sortOrder: 10,
    ),
    ContentBlock(
      blockKey: 'smoke_home_latest_intel',
      blockType: 'widget',
      content: <String, dynamic>{'widget': 'latest_intel_section'},
      placementKey: 'home_bottom',
      sortOrder: 20,
    ),
  ],
);

class _SmokeRayonSportsConfig extends RayonSportsConfig {
  const _SmokeRayonSportsConfig();

  @override
  String get clubId => '24';

  @override
  String get supabaseUrl => 'https://example.supabase.co';

  @override
  String get supabaseAnonKey => 'anon';

  @override
  String get environment => 'test';
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

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();
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
  int maxPumps = 60,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 150));
  }

  expect(finder, findsOneWidget);
}

Future<void> _pumpAppStartup(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump();
}
