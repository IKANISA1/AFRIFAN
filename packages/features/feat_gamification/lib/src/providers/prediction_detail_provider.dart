import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prediction_models.dart';
import '../prediction_providers.dart';

/// M-4: AsyncNotifier for PredictionDetail — replaces manual setState in the
/// PredictionDetailScreen with a cacheable, auto-disposing provider pattern.
class PredictionDetailNotifier
    extends FamilyAsyncNotifier<PredictionDetail?, String> {
  @override
  Future<PredictionDetail?> build(String predictionId) async {
    final repo = ref.read(predictionRepositoryProvider);
    return repo.loadPredictionDetail(predictionId);
  }

  /// Refresh the detail from network.
  Future<void> refresh() async {
    state = const AsyncLoading<PredictionDetail?>();
    state = await AsyncValue.guard(() => build(arg));
  }

  /// Cancel a pending prediction and refresh the detail.
  Future<PredictionPlaceResult> cancel() async {
    final repo = ref.read(predictionRepositoryProvider);
    final result = await repo.cancelPrediction(arg);
    if (result.isSuccess) {
      // Refresh to pick up the new status.
      await refresh();
    }
    return result;
  }
}

final predictionDetailProvider = AsyncNotifierProvider.family<
    PredictionDetailNotifier, PredictionDetail?, String>(() {
  return PredictionDetailNotifier();
});
