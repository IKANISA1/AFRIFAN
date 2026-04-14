import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_contributions/src/screens/groups_screen.dart';
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

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        clubRepositoryProvider.overrideWithValue(repository),
        currentUserProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        home: ClubConfigScope(
          config: ClubConfig.fallback(),
          child: const GroupsScreen(),
        ),
      ),
    );
  }

  group('GroupsScreen Empty State', () {
    testWidgets('renders empty state when there are no groups', (tester) async {
      when(() => repository.getContributionGroups())
          .thenAnswer((_) async => <ContributionGroup>[]);

      await tester.pumpWidget(createSubject());
      
      // Wait for loading to finish
      await tester.pumpAndSettle();

      expect(find.text('No contribution groups yet'), findsOneWidget);
      expect(
        find.text('Create or join a group to start contributing.'),
        findsOneWidget,
      );
      expect(find.text('CREATE GROUP'), findsOneWidget);
      expect(find.byIcon(Icons.group_work_outlined), findsOneWidget);
    });
  });
}
