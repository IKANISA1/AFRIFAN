import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/widgets/prediction_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('team picks use registered crests and initials at 200% text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SizedBox(
              width: 160,
              child: PredictionSelection(
                selection: 'Rayon Sports FC',
                homeTeam: 'Rayon Sports FC',
                awayTeam: 'APR FC',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AfriTeamCrest), findsOneWidget);
    expect(find.text('RAY'), findsOneWidget);
    expect(find.text('Rayon Sports FC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('non-team outcomes are preserved and team aliases stay concise', () {
    String label(String selection) => predictionSelectionLabel(
      selection: selection,
      homeTeam: 'Rayon Sports FC',
      awayTeam: 'APR FC',
    );
    expect(label('APR FC'), 'APR');
    expect(label('Rayon Sports'), 'RAY');
    expect(label('Over 2.5'), 'Over 2.5');
    expect(label('Draw'), 'Draw');
    expect(label('1'), '1');
    expect(label('home'), 'RAY');
    expect(label('away'), 'APR');
  });
}
