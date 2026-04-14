import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/prediction_models.dart';
import 'models/prediction_slip_models.dart';
import 'prediction_providers.dart';

final predictionSlipProvider =
    NotifierProvider<PredictionSlipController, PredictionSlipState>(
      PredictionSlipController.new,
    );

class PredictionSlipController extends Notifier<PredictionSlipState> {
  @override
  PredictionSlipState build() => const PredictionSlipState();

  void addSelection(PredictionSlipSelection selection) {
    final retained = state.items.where(
      (item) => item.fixtureMarketId != selection.fixtureMarketId,
    );
    state = state.copyWith(
      items: <PredictionSlipSelection>[...retained, selection],
    );
  }

  void addFromMarket({
    required FixtureSummary fixture,
    required FixtureMarket market,
    required MarketOutcomeOption outcome,
  }) {
    addSelection(
      PredictionSlipSelection.fromFixtureMarket(
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
    state = state.copyWith(items: const <PredictionSlipSelection>[]);
  }

  void toggleAcca(bool value) {
    state = state.copyWith(accaMode: value);
  }

  Future<PredictionSlipSubmissionResult> submit() async {
    if (state.items.isEmpty) {
      return const PredictionSlipSubmissionResult(
        submittedCount: 0,
        failedCount: 0,
        totalPotential: 0,
        messages: <String>['No predictions selected.'],
      );
    }

    state = state.copyWith(isSubmitting: true);
    final repository = ref.read(predictionRepositoryProvider);
    final totalPotential = state.totalPotential;
    final messages = <String>[];
    var submittedCount = 0;
    var failedCount = 0;
    String? slipId;

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
          slipId = result.slipId;
          submittedCount = state.items.length;
          clear();
          return PredictionSlipSubmissionResult(
            submittedCount: submittedCount,
            failedCount: 0,
            totalPotential: totalPotential,
            messages: <String>[
              result.message.isEmpty
                  ? 'Acca locked in successfully.'
                  : result.message,
            ],
            slipId: slipId,
          );
        }

        return PredictionSlipSubmissionResult(
          submittedCount: 0,
          failedCount: state.items.length,
          totalPotential: totalPotential,
          messages: <String>[
            result.message.isEmpty
                ? 'Could not lock in your acca right now.'
                : result.message,
          ],
          slipId: result.slipId,
        );
      }

      final successfulIds = <String>{};
      for (final item in state.items) {
        try {
          final result = await repository.placePrediction(
            fixtureMarketId: item.fixtureMarketId,
            selectedOutcome: item.outcomeKey,
          );
          if (result.isSuccess) {
            submittedCount += 1;
            slipId ??= result.slipId;
            successfulIds.add(item.fixtureMarketId);
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

      if (successfulIds.isNotEmpty) {
        state = state.copyWith(
          items: state.items
              .where((item) => !successfulIds.contains(item.fixtureMarketId))
              .toList(growable: false),
        );
      }

      return PredictionSlipSubmissionResult(
        submittedCount: submittedCount,
        failedCount: failedCount,
        totalPotential: totalPotential,
        messages: messages,
        slipId: slipId,
      );
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}
