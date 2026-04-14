import 'prediction_models.dart';

class PredictionSlipSelection {
  const PredictionSlipSelection({
    required this.fixtureId,
    required this.fixtureLabel,
    required this.fixtureMarketId,
    required this.marketName,
    required this.marketSlug,
    required this.outcomeKey,
    required this.outcomeLabel,
    required this.fetPotential,
    this.competitionName,
  });

  final String fixtureId;
  final String fixtureLabel;
  final String fixtureMarketId;
  final String marketName;
  final String marketSlug;
  final String outcomeKey;
  final String outcomeLabel;
  final int fetPotential;
  final String? competitionName;

  factory PredictionSlipSelection.fromFixtureMarket({
    required FixtureSummary fixture,
    required FixtureMarket market,
    required MarketOutcomeOption outcome,
  }) {
    return PredictionSlipSelection(
      fixtureId: fixture.id,
      fixtureLabel:
          '${fixture.homeTeamShort.toUpperCase()} vs ${fixture.awayTeamShort.toUpperCase()}',
      fixtureMarketId: market.fixtureMarketId,
      marketName: market.marketName,
      marketSlug: market.marketSlug,
      outcomeKey: outcome.key,
      outcomeLabel: outcome.label,
      fetPotential: market.fetValue,
      competitionName: fixture.competitionName,
    );
  }
}

class PredictionSlipSubmissionResult {
  const PredictionSlipSubmissionResult({
    required this.submittedCount,
    required this.failedCount,
    required this.totalPotential,
    required this.messages,
    this.slipId,
  });

  final int submittedCount;
  final int failedCount;
  final int totalPotential;
  final List<String> messages;
  final String? slipId;

  bool get hasFailures => failedCount > 0;
  bool get isSuccess => submittedCount > 0 && failedCount == 0;
}

class PredictionSlipState {
  const PredictionSlipState({
    this.items = const <PredictionSlipSelection>[],
    this.accaMode = false,
    this.isSubmitting = false,
  });

  final List<PredictionSlipSelection> items;
  final bool accaMode;
  final bool isSubmitting;

  int get totalPotential {
    final base = items.fold<int>(0, (sum, item) => sum + item.fetPotential);
    if (!accaMode || items.length < 2) {
      return base;
    }

    final multiplier = switch (items.length) {
      2 => 1.5,
      3 => 2.0,
      _ => 3.0,
    };
    return (base * multiplier).floor();
  }

  PredictionSlipState copyWith({
    List<PredictionSlipSelection>? items,
    bool? accaMode,
    bool? isSubmitting,
  }) {
    return PredictionSlipState(
      items: items ?? this.items,
      accaMode: accaMode ?? this.accaMode,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}
