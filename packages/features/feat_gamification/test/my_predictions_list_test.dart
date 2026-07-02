import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/screens/my_predictions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Widget buildSubject({
    required List<UserPrediction> items,
    Future<void> Function()? onRefresh,
    void Function(UserPrediction prediction)? onOpenDetail,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MyPredictionsList(
          items: items,
          onRefresh: onRefresh ?? () async {},
          onOpenDetail: onOpenDetail,
        ),
      ),
    );
  }

  testWidgets('returns SizedBox.shrink when activity list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(items: const <UserPrediction>[]));

    expect(find.text('No activity yet'), findsNothing);
    expect(find.textContaining('Lock in picks'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('my-predictions-empty')),
      findsOne,
    );
  });

  testWidgets('renders activity cards and forwards detail taps', (
    tester,
  ) async {
    const prediction = UserPrediction(
      id: 'prediction-1',
      fixtureId: 'fixture-1',
      marketSlug: '1x2',
      marketName: 'Match Result',
      marketGroup: MarketGroup.matchResult,
      homeTeam: 'Rayon Sports',
      homeTeamShort: 'RAY',
      awayTeam: 'APR FC',
      awayTeamShort: 'APR',
      kickoffAt: null,
      fixtureStatus: 'scheduled',
      competitionName: 'Rwanda Premier League',
      selectedOutcome: 'Rayon Sports',
      status: PredictionStatus.pending,
      fetPotential: 100,
      fetEarned: 0,
      placedAt: null,
    );
    UserPrediction? openedPrediction;

    await tester.pumpWidget(
      buildSubject(
        items: const <UserPrediction>[prediction],
        onOpenDetail: (value) {
          openedPrediction = value;
        },
      ),
    );

    expect(find.text('RAY vs APR'), findsOneWidget);
    expect(find.text('MATCH RESULT'), findsOneWidget);
    expect(find.text('RAYON SPORTS'), findsOneWidget);

    await tester.tap(find.text('RAY vs APR'));
    await tester.pump();

    expect(openedPrediction, prediction);
  });
}
