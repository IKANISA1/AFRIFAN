import 'prediction_models.dart';

class FanzoneSlipSelection {
  const FanzoneSlipSelection({
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

  String get id => '$fixtureMarketId::$outcomeKey';

  factory FanzoneSlipSelection.fromFixtureMarket({
    required FixtureSummary fixture,
    required FixtureMarket market,
    required MarketOutcomeOption outcome,
  }) {
    return FanzoneSlipSelection(
      fixtureId: fixture.id,
      fixtureLabel: fixture.fixtureLabel,
      fixtureMarketId: market.fixtureMarketId,
      marketName: market.marketName,
      marketSlug: market.marketSlug,
      outcomeKey: outcome.key,
      outcomeLabel: outcome.label,
      fetPotential: market.fetValue,
      competitionName: fixture.competitionName,
    );
  }

  FanzoneSlipSelection copyWith({
    String? fixtureId,
    String? fixtureLabel,
    String? fixtureMarketId,
    String? marketName,
    String? marketSlug,
    String? outcomeKey,
    String? outcomeLabel,
    int? fetPotential,
    String? competitionName,
  }) {
    return FanzoneSlipSelection(
      fixtureId: fixtureId ?? this.fixtureId,
      fixtureLabel: fixtureLabel ?? this.fixtureLabel,
      fixtureMarketId: fixtureMarketId ?? this.fixtureMarketId,
      marketName: marketName ?? this.marketName,
      marketSlug: marketSlug ?? this.marketSlug,
      outcomeKey: outcomeKey ?? this.outcomeKey,
      outcomeLabel: outcomeLabel ?? this.outcomeLabel,
      fetPotential: fetPotential ?? this.fetPotential,
      competitionName: competitionName ?? this.competitionName,
    );
  }
}

class FanzoneSlipSubmissionResult {
  const FanzoneSlipSubmissionResult({
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
}

class FanzoneSlipState {
  const FanzoneSlipState({
    this.items = const <FanzoneSlipSelection>[],
    this.accaMode = false,
    this.isSubmitting = false,
  });

  final List<FanzoneSlipSelection> items;
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

  FanzoneSlipState copyWith({
    List<FanzoneSlipSelection>? items,
    bool? accaMode,
    bool? isSubmitting,
  }) {
    return FanzoneSlipState(
      items: items ?? this.items,
      accaMode: accaMode ?? this.accaMode,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}
