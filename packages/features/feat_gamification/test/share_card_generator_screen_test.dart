import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/screens/share_card_generator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  Widget buildSubject({
    required List<UserPrediction> history,
    required UserPrediction? selected,
    void Function(UserPrediction prediction)? onSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ShareCardGeneratorContent(
          history: history,
          selected: selected,
          onRefresh: () async {},
          onSelected: onSelected ?? (_) {},
          onShare: (_) {},
          onCopy: (_) {},
        ),
      ),
    );
  }

  testWidgets(
    'shows compact share card empty state when no predictions exist',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(history: const <UserPrediction>[], selected: null),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('share-card-empty')), findsOne);
      expect(find.text('No share card yet'), findsOneWidget);
      expect(find.text('Back to Picks'), findsOneWidget);
    },
  );

  testWidgets(
    'renders share card and prediction selector when history exists',
    (tester) async {
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
        fixtureStatus: 'finished',
        competitionName: 'Rwanda Premier League',
        selectedOutcome: 'Rayon Sports',
        status: PredictionStatus.won,
        fetPotential: 100,
        fetEarned: 100,
        placedAt: null,
        settledAt: null,
      );

      await tester.pumpWidget(
        buildSubject(
          history: const <UserPrediction>[prediction],
          selected: prediction,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('share-card-empty')),
        findsNothing,
      );
      expect(find.text('SELECT A PREDICTION'), findsOneWidget);
      expect(find.text('RAY vs APR'), findsWidgets);
      expect(find.text('Selected'), findsOneWidget);
    },
  );
}
