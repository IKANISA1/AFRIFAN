import 'package:core_l10n/core_l10n.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/predict/predict_share_screen.dart';
import 'package:feat_gamification/src/widgets/prediction_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Widget buildSubject({
    required UserPrediction? selected,
    Future<void> Function(UserPrediction)? onShare,
    Future<void> Function(UserPrediction)? onCopy,
    bool actionsEnabled = true,
    Locale appCopyLocale = const Locale('en'),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AfriLocalizationsScope(
          locale: appCopyLocale,
          child: ShareCardGeneratorContent(
            selected: selected,
            onRefresh: () async {},
            onShare: onShare ?? (_) async {},
            onCopy: onCopy ?? (_) async {},
            actionsEnabled: actionsEnabled,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'shows compact share card empty state when no predictions exist',
    (tester) async {
      await tester.pumpWidget(buildSubject(selected: null));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('share-card-empty')), findsOne);
      expect(find.text('Make a pick first'), findsOneWidget);
      expect(find.text('Back to picks'), findsOneWidget);
    },
  );

  testWidgets('localizes the empty task in English', (tester) async {
    await tester.pumpWidget(
      buildSubject(selected: null, appCopyLocale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make a pick first'), findsOneWidget);
    expect(find.text('Back to picks'), findsOneWidget);

    await tester.pumpWidget(
      buildSubject(selected: null, appCopyLocale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make a pick first'), findsOneWidget);
    expect(find.text('Back to picks'), findsOneWidget);
  });

  testWidgets(
    'shows one preview and omits the selector when there is only one pick',
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

      await tester.pumpWidget(buildSubject(selected: prediction));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('share-card-empty')),
        findsNothing,
      );
      expect(find.text('Change pick'), findsNothing);
      expect(find.byType(PredictionShareCard), findsOneWidget);
      expect(find.text('RAY'), findsWidgets);
      expect(find.text('APR'), findsWidgets);
      expect(find.text('Your pick'), findsOneWidget);
      expect(
        find.text('Share a text summary of this prediction.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('share and copy use the current prediction without a picker', (
    tester,
  ) async {
    const first = UserPrediction(
      id: 'first',
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
      competitionName: 'Premier League',
      selectedOutcome: 'Rayon Sports',
      status: PredictionStatus.won,
      fetPotential: 100,
      fetEarned: 100,
      placedAt: null,
      settledAt: null,
    );
    const second = UserPrediction(
      id: 'second',
      fixtureId: 'fixture-2',
      marketSlug: 'total_goals',
      marketName: 'Total Goals',
      marketGroup: MarketGroup.goals,
      homeTeam: 'Police FC',
      homeTeamShort: 'POL',
      awayTeam: 'Rayon Sports',
      awayTeamShort: 'RAY',
      kickoffAt: null,
      fixtureStatus: 'scheduled',
      competitionName: 'Premier League',
      selectedOutcome: 'Over 2.5',
      status: PredictionStatus.pending,
      fetPotential: 140,
      fetEarned: 0,
      placedAt: null,
      settledAt: null,
    );
    final shared = <String>[];
    final copied = <String>[];
    await tester.pumpWidget(buildSubject(selected: first));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      buildSubject(
        selected: second,
        onShare: (value) async => shared.add(value.id),
        onCopy: (value) async => copied.add(value.id),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Change pick'), findsNothing);
    expect(find.text('Choose a prediction'), findsNothing);
    expect(find.byType(PredictionShareCard), findsOneWidget);
    expect(
      tester
          .widget<PredictionShareCard>(find.byType(PredictionShareCard))
          .data
          .selectedOutcome,
      'Over 2.5',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('share-card-share-action')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('share-card-copy-action')),
    );
    expect(shared, ['second']);
    expect(copied, ['second']);
    expect(tester.takeException(), isNull);
  });

  for (final status in [
    PredictionStatus.lost,
    PredictionStatus.cancelled,
    PredictionStatus.void_,
  ]) {
    testWidgets(
      'settled $status never promises potential rewards in the preview or copied text',
      (tester) async {
        final data = PredictionShareData(
          competitionName: 'Premier League',
          homeTeam: 'Rayon Sports',
          homeTeamShort: 'RAY',
          awayTeam: 'APR FC',
          awayTeamShort: 'APR',
          marketName: 'Match Result',
          selectedOutcome: 'Rayon Sports',
          status: status,
          fetPotential: 100,
          fetEarned: 0,
        );
        String? copied;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PredictionShareCard(data: data)),
          ),
        );
        expect(find.text('Potential'), findsNothing);
        expect(find.text('+100 FET'), findsNothing);
        await PredictionShareService.copy(data: data);
        expect(copied, isNotNull);
        expect(copied, isNot(contains('Potential:')));
        expect(copied, contains('Match Result'));
      },
    );
  }
}
