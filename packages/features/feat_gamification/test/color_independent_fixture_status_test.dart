import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/widgets/fixtures_browser_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('live fixture meaning survives without the green indicator', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FixtureBrowserCard(
            fixture: FixtureSummary(
              id: 'fixture-live',
              competitionSlug: 'rpl',
              competitionName: 'Rwanda Premier League',
              seasonLabel: '2026',
              matchday: 1,
              homeTeamName: 'Rayon Sports',
              homeTeamShort: 'RAY',
              awayTeamName: 'Police FC',
              awayTeamShort: 'POL',
              kickoffAt: DateTime.utc(2026, 7, 24, 18),
              venueName: 'Kigali Pele Stadium',
              status: 'live',
              homeScore: 1,
              awayScore: 0,
            ),
            onOpen: () {},
          ),
        ),
      ),
    );

    expect(find.text('LIVE'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Rayon Sports vs Police FC. Live match'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
