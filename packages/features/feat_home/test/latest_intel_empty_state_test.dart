import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/widgets/latest_intel_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeLatestIntelRepository repository;

  setUp(() {
    repository = const _FakeLatestIntelRepository(
      LatestIntelSnapshot(status: LatestIntelStatus.empty, articles: []),
    );
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [latestIntelRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: Scaffold(body: LatestIntelSection())),
    );
  }

  group('LatestIntelSection', () {
    testWidgets('hides news labels when nothing is published', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('News'), findsNothing);
      expect(find.text('Club updates will appear here'), findsNothing);
      expect(find.text('Show all'), findsNothing);
    });
  });
}

class _FakeLatestIntelRepository implements LatestIntelRepository {
  const _FakeLatestIntelRepository(this.snapshot);

  final LatestIntelSnapshot snapshot;

  @override
  Future<LatestIntelSnapshot> loadPublishedArticles() async => snapshot;
}
