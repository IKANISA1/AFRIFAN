import 'package:feat_gamification/src/predict/predict_fixture_card.dart';
import 'package:feat_gamification/src/predict/predict_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Predict selection is announced without relying on color', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PredictFixtureCard(
            fixture: PredictFixture(
              id: 'fixture',
              poolId: 'pool',
              competitionId: 'rpl',
              competition: 'Rwanda Premier League',
              homeTeam: 'Rayon Sports',
              awayTeam: 'Police FC',
              homeCrest: '',
              awayCrest: '',
              kickoffAt: DateTime(2030),
              locksAt: DateTime(2030),
              stakeFet: 0,
              economicsVersion: 'free_v1',
              selection: PredictSelection.home,
            ),
            enabled: true,
            pending: false,
            onPick: (_) {},
          ),
        ),
      ),
    );
    final home = find.bySemanticsLabel('Rayon Sports, Free');
    expect(home, findsOneWidget);
    expect(
      tester.getSemantics(home),
      matchesSemantics(
        label: 'Rayon Sports, Free',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });
}
