import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/fanzone_slip_models.dart';
import 'models/prediction_models.dart';
import 'prediction_providers.dart';

final fanzoneSlipProvider =
    NotifierProvider<FanzoneSlipController, FanzoneSlipState>(
      FanzoneSlipController.new,
    );

class FanzoneSlipController extends Notifier<FanzoneSlipState> {
  @override
  FanzoneSlipState build() => const FanzoneSlipState();

  void addSelection(FanzoneSlipSelection selection) {
    final existing = state.items.where(
      (item) => item.fixtureMarketId != selection.fixtureMarketId,
    );
    state = state.copyWith(
      items: <FanzoneSlipSelection>[...existing, selection],
    );
  }

  void addFromMarket({
    required FixtureSummary fixture,
    required FixtureMarket market,
    required MarketOutcomeOption outcome,
  }) {
    addSelection(
      FanzoneSlipSelection.fromFixtureMarket(
        fixture: fixture,
        market: market,
        outcome: outcome,
      ),
    );
  }

  void removeSelection(String fixtureMarketId) {
    state = state.copyWith(
      items: state.items
          .where((item) => item.fixtureMarketId != fixtureMarketId)
          .toList(growable: false),
    );
  }

  void clear() {
    state = state.copyWith(items: const <FanzoneSlipSelection>[]);
  }

  void toggleAcca(bool value) {
    state = state.copyWith(accaMode: value);
  }

  Future<FanzoneSlipSubmissionResult> submit() async {
    if (state.items.isEmpty) {
      return const FanzoneSlipSubmissionResult(
        submittedCount: 0,
        failedCount: 0,
        totalPotential: 0,
        messages: <String>['No predictions selected.'],
      );
    }

    state = state.copyWith(isSubmitting: true);
    final repository = ref.read(predictionRepositoryProvider);
    final messages = <String>[];
    var submittedCount = 0;
    var failedCount = 0;
    final totalPotential = state.totalPotential;

    try {
      if (state.accaMode && state.items.length > 1) {
        final result = await repository.placeAcca(
          state.items
              .map(
                (item) => <String, String>{
                  'fixture_market_id': item.fixtureMarketId,
                  'selected_outcome': item.outcomeKey,
                },
              )
              .toList(growable: false),
        );

        if (result.isSuccess) {
          submittedCount = state.items.length;
          clear();
          return FanzoneSlipSubmissionResult(
            submittedCount: submittedCount,
            failedCount: 0,
            totalPotential: totalPotential,
            messages: <String>[
              result.message.isEmpty
                  ? 'Acca placed successfully.'
                  : result.message,
            ],
            slipId: result.slipId,
          );
        }

        return FanzoneSlipSubmissionResult(
          submittedCount: 0,
          failedCount: state.items.length,
          totalPotential: totalPotential,
          messages: <String>[
            result.message.isEmpty
                ? 'Could not place your acca right now.'
                : result.message,
          ],
          slipId: result.slipId,
        );
      }

      for (final item in state.items) {
        try {
          final result = await repository.placePrediction(
            fixtureMarketId: item.fixtureMarketId,
            selectedOutcome: item.outcomeKey,
          );
          if (result.isSuccess) {
            submittedCount += 1;
          } else {
            failedCount += 1;
            messages.add(result.message);
          }
        } catch (_) {
          failedCount += 1;
          messages.add(
            'Could not submit ${item.marketName} for ${item.fixtureLabel}.',
          );
        }
      }

      if (failedCount == 0) {
        clear();
      }

      return FanzoneSlipSubmissionResult(
        submittedCount: submittedCount,
        failedCount: failedCount,
        totalPotential: totalPotential,
        messages: messages,
      );
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}
