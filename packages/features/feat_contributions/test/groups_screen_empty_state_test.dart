import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_contributions/src/screens/club_projects_screen.dart'
    as contribution_projects;
import 'package:feat_contributions/src/screens/contributions_hub_screen.dart';
import 'package:feat_contributions/src/screens/groups_screen.dart';
import 'package:feat_sms_ledger/feat_sms_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_support/app_font_loader.dart';
import 'package:test_support/touch_target_audit.dart';

class MockClubRepository extends Mock implements ClubRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  late MockClubRepository repository;

  setUp(() {
    repository = MockClubRepository();
    ConnectivityService.setOnlineForTest(true);
  });

  Widget createSubject(
    Widget child, {
    Brightness brightness = Brightness.dark,
    Key? goldenKey,
  }) {
    return ProviderScope(
      overrides: [
        clubRepositoryProvider.overrideWithValue(repository),
        currentUserProvider.overrideWithValue(null),
        momoSmsSyncEnabledProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp(
        theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
        home: ClubConfigScope(
          config: ClubConfig.fallback(),
          child: RepaintBoundary(key: goldenKey, child: child),
        ),
      ),
    );
  }

  group('GroupsScreen Empty State', () {
    testWidgets('hides visible empty sections when there are no groups', (
      tester,
    ) async {
      when(
        () => repository.getContributionGroups(),
      ).thenAnswer((_) async => <ContributionGroup>[]);

      await tester.pumpWidget(createSubject(const GroupsScreen()));

      await tester.pumpAndSettle();

      expect(find.text('No communities yet'), findsNothing);
      expect(
        find.text(
          'Team projects and communities appear here after admin setup.',
        ),
        findsNothing,
      );
      expect(find.text('Browse fan clubs'), findsNothing);
      expect(find.text('Active initiatives'), findsNothing);
      expect(find.byType(AfriMetricTile), findsNothing);
    });

    testWidgets('renders group content when groups are available', (
      tester,
    ) async {
      when(() => repository.getContributionGroups()).thenAnswer(
        (_) async => [
          ContributionGroup(
            id: 'group-1',
            creatorId: 'fan-1',
            name: 'Away Day Support',
            description: 'Travel support',
            targetAmount: 100000,
            currentTotal: 40000,
            memberCount: 12,
            createdAt: DateTime.utc(2026, 6, 1),
          ),
        ],
      );

      await tester.pumpWidget(createSubject(const GroupsScreen()));

      await tester.pumpAndSettle();

      expect(find.text('Active initiatives'), findsOneWidget);
      expect(find.text('AWAY DAY SUPPORT'), findsOneWidget);
      expect(find.byType(AfriMetricTile), findsNWidgets(2));
    });
  });

  group('ContributionsHubScreen Empty State', () {
    testWidgets('hides visible empty campaign sections when groups are empty', (
      tester,
    ) async {
      when(
        () => repository.getContributionGroups(),
      ).thenAnswer((_) async => <ContributionGroup>[]);

      await tester.pumpWidget(createSubject(const ContributionsHubScreen()));

      await tester.pumpAndSettle();

      expect(find.text('No campaigns yet.'), findsNothing);
      expect(find.text('No public communities yet.'), findsNothing);
      expect(find.text('No community activity yet.'), findsNothing);
      expect(find.text('No public groups yet'), findsNothing);
      expect(find.text('Live campaigns'), findsNothing);
      expect(find.text('MoMo SMS sync'), findsOneWidget);
      expect(find.byType(AfriScreenScaffold), findsOneWidget);
      expectTapTargetsMeetMinimum(tester);
    });

    testWidgets('caps hub content on tablet at 200 percent text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1024);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      when(
        () => repository.getContributionGroups(),
      ).thenAnswer((_) async => <ContributionGroup>[]);

      await tester.pumpWidget(createSubject(const ContributionsHubScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AfriScreenScaffold), findsOneWidget);
      expect(
        tester.getSize(find.byType(ListView).first).width,
        AfriResponsive.tabletContentMax,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('blocks the initial network load while offline', (
      tester,
    ) async {
      ConnectivityService.setOnlineForTest(false);

      await tester.pumpWidget(createSubject(const ContributionsHubScreen()));
      await tester.pumpAndSettle();

      verifyNever(() => repository.getContributionGroups());
      expect(
        find.text('Connect to load contribution initiatives.'),
        findsOneWidget,
      );
      expect(find.text('Connection required'), findsWidgets);
    });

    testWidgets('retains groups as stale and refreshes them after reconnect', (
      tester,
    ) async {
      final refreshed = Completer<List<ContributionGroup>>();
      var calls = 0;
      when(() => repository.getContributionGroups()).thenAnswer((_) {
        calls += 1;
        if (calls > 1) return refreshed.future;
        return Future.value(<ContributionGroup>[_cachedCampaign]);
      });

      await tester.pumpWidget(createSubject(const ContributionsHubScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Cached campaign'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Cached campaign'), findsWidgets);

      ConnectivityService.setOnlineForTest(false);
      await tester.pump();

      expect(find.text('Cached campaign'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Saved contribution data'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved contribution data'), findsOneWidget);

      ConnectivityService.setOnlineForTest(true);
      await tester.pump();
      expect(find.text('Refreshing contributions'), findsOneWidget);

      refreshed.complete(<ContributionGroup>[_cachedCampaign]);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Cached campaign'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Cached campaign'), findsWidgets);
      expect(find.text('Saved contribution data'), findsNothing);
      verify(() => repository.getContributionGroups()).called(2);
    });
  });

  group('ClubProjectsScreen Empty State', () {
    testWidgets('hides visible empty project copy when groups are empty', (
      tester,
    ) async {
      when(
        () => repository.getContributionGroups(),
      ).thenAnswer((_) async => <ContributionGroup>[]);

      await tester.pumpWidget(
        createSubject(const contribution_projects.ClubProjectsScreen()),
      );

      await tester.pumpAndSettle();

      expect(find.text('CLUB PROJECTS'), findsOneWidget);
      expect(find.textContaining('No campaigns'), findsNothing);
      expect(find.textContaining('Start a new Group'), findsNothing);
    });

    testWidgets('renders project content when groups are available', (
      tester,
    ) async {
      when(() => repository.getContributionGroups()).thenAnswer(
        (_) async => [
          ContributionGroup(
            id: 'project-1',
            creatorId: 'fan-1',
            name: 'Away Day Support',
            description: 'Travel support',
            targetAmount: 100000,
            currentTotal: 40000,
            memberCount: 12,
            createdAt: DateTime.utc(2026, 6, 1),
          ),
        ],
      );

      await tester.pumpWidget(
        createSubject(const contribution_projects.ClubProjectsScreen()),
      );

      await tester.pumpAndSettle();

      expect(find.text('AWAY DAY SUPPORT'), findsOneWidget);
      expect(find.text('Travel support'), findsOneWidget);
      expect(find.textContaining('No campaigns'), findsNothing);
    });

    testWidgets(
      'keeps project details visible but disables contribution offline',
      (tester) async {
        when(() => repository.getContributionGroups()).thenAnswer(
          (_) async => [
            ContributionGroup(
              id: 'project-1',
              creatorId: 'fan-1',
              name: 'Away Day Support',
              description: 'Travel support',
              targetAmount: 100000,
              currentTotal: 40000,
              memberCount: 12,
              createdAt: DateTime.utc(2026, 6, 1),
            ),
          ],
        );

        await tester.pumpWidget(
          createSubject(const contribution_projects.ClubProjectsScreen()),
        );
        await tester.pumpAndSettle();
        ConnectivityService.setOnlineForTest(false);
        await tester.pump();

        expect(find.text('AWAY DAY SUPPORT'), findsOneWidget);
        final blocked = find.widgetWithText(AfriButton, 'Connection required');
        expect(blocked, findsOneWidget);
        expect(tester.widget<AfriButton>(blocked).enabled, isFalse);
      },
    );
  });

  for (final profile in _compactGoldenProfiles) {
    testWidgets('golden compact Contributions route ${profile.id}', (
      tester,
    ) async {
      _setGoldenSurface(tester, profile.size);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      ColorTokens.setBrightness(profile.brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      when(() => repository.getContributionGroups()).thenAnswer(
        (_) async => [
          ContributionGroup(
            id: 'group-1',
            creatorId: 'fan-1',
            name: 'Away Day Support',
            description: 'Travel support for the next away fixture.',
            targetAmount: 100000,
            currentTotal: 40000,
            memberCount: 12,
            createdAt: DateTime.utc(2026, 6, 1),
          ),
        ],
      );

      await tester.pumpWidget(
        createSubject(
          const ContributionsHubScreen(),
          brightness: profile.brightness,
          goldenKey: const ValueKey<String>('contributions-route-golden'),
        ),
      );
      await tester.pumpAndSettle();

      final routeScrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('contributions-route-golden'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      final routePosition = tester
          .state<ScrollableState>(routeScrollable)
          .position;
      routePosition.jumpTo(routePosition.minScrollExtent);
      await tester.pumpAndSettle();
      expect(routePosition.pixels, routePosition.minScrollExtent);

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey<String>('contributions-route-golden')),
        matchesGoldenFile('goldens/contributions_${profile.id}.png'),
      );
    });
  }
}

final _cachedCampaign = ContributionGroup(
  id: 'group-1',
  creatorId: 'fan-1',
  name: 'Cached campaign',
  description: 'Retained while offline',
  targetAmount: 100000,
  currentTotal: 40000,
  memberCount: 12,
  createdAt: DateTime.utc(2026, 6, 1),
);

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
