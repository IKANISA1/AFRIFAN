import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/widgets/latest_intel_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLatestIntelRepository extends Mock implements LatestIntelRepository {}

void main() {
  late MockLatestIntelRepository repository;

  setUp(() {
    repository = MockLatestIntelRepository();
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        latestIntelRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: ClubConfigScope(
          config: ClubConfig.fallback(),
          child: const Scaffold(
            body: LatestIntelSection(),
          ),
        ),
      ),
    );
  }

  group('LatestIntelSection', () {
    testWidgets('renders SizedBox.shrink() when there is no news',
        (tester) async {
      when(() => repository.loadPublishedArticles()).thenAnswer(
        (_) async => const LatestIntelSnapshot(
          status: LatestIntelStatus.empty,
          articles: [],
        ),
      );

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsWidgets);
      
      // Because we return `const SizedBox.shrink()` at the top level of the build method
      // when empty, we expect no column or section headers.
      expect(find.text('News'), findsNothing);
      expect(find.text('Latest club updates'), findsNothing);
    });
  });
}
