import 'package:core_l10n/core_l10n.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/screens/share_card_generator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Widget buildSubject({
    required List<UserPrediction> history,
    required UserPrediction? selected,
    void Function(UserPrediction prediction)? onSelected,
    Locale appCopyLocale = const Locale('en'),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AfriLocalizationsScope(
          locale: appCopyLocale,
          child: ShareCardGeneratorContent(
            history: history,
            selected: selected,
            onRefresh: () async {},
            onSelected: onSelected ?? (_) {},
            onShare: (_) async {},
            onCopy: (_) async {},
          ),
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
      expect(find.text('Make a pick first'), findsOneWidget);
      expect(find.text('Back to picks'), findsOneWidget);
    },
  );

  testWidgets('localizes the empty task in English', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        history: const <UserPrediction>[],
        selected: null,
        appCopyLocale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make a pick first'), findsOneWidget);
    expect(find.text('Back to picks'), findsOneWidget);

    await tester.pumpWidget(
      buildSubject(
        history: const <UserPrediction>[],
        selected: null,
        appCopyLocale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make a pick first'), findsOneWidget);
    expect(find.text('Back to picks'), findsOneWidget);
  });

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
      expect(find.text('Choose pick'), findsOneWidget);
      expect(find.text('RAY vs APR'), findsWidgets);
      expect(find.text('Selected'), findsOneWidget);
    },
  );
}
