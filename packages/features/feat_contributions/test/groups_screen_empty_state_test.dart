import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_contributions/src/screens/club_projects_screen.dart';
import 'package:feat_contributions/src/screens/contributions_hub_screen.dart';
import 'package:feat_contributions/src/screens/groups_screen.dart';
import 'package:feat_sms_ledger/feat_sms_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockClubRepository extends Mock implements ClubRepository {}

void main() {
  late MockClubRepository repository;

  setUp(() {
    repository = MockClubRepository();
  });

  Widget createSubject(Widget child) {
    return ProviderScope(
      overrides: [
        clubRepositoryProvider.overrideWithValue(repository),
        currentUserProvider.overrideWithValue(null),
        momoSmsSyncEnabledProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp(
        home: ClubConfigScope(config: ClubConfig.fallback(), child: child),
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
    });
  });

  group('ClubProjectsScreen Empty State', () {
    testWidgets('hides visible empty project copy when groups are empty', (
      tester,
    ) async {
      when(
        () => repository.getContributionGroups(),
      ).thenAnswer((_) async => <ContributionGroup>[]);

      await tester.pumpWidget(createSubject(const ClubProjectsScreen()));

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

      await tester.pumpWidget(createSubject(const ClubProjectsScreen()));

      await tester.pumpAndSettle();

      expect(find.text('AWAY DAY SUPPORT'), findsOneWidget);
      expect(find.text('Travel support'), findsOneWidget);
      expect(find.textContaining('No campaigns'), findsNothing);
    });
  });
}
