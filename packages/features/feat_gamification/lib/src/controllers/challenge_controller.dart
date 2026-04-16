import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/challenge_models.dart';
import '../prediction_providers.dart';

final challengeFeedProvider = StateNotifierProvider<ChallengeFeedController, AsyncValue<List<Challenge>>>((ref) {
  return ChallengeFeedController(ref.watch(challengeRepositoryProvider));
});

class ChallengeFeedController extends StateNotifier<AsyncValue<List<Challenge>>> {
  ChallengeFeedController(this._repository) : super(const AsyncValue.loading()) {
    loadChallenges();
  }

  final ChallengeRepository _repository;

  Future<void> loadChallenges({String? status}) async {
    state = const AsyncValue.loading();
    try {
      final challenges = await _repository.loadChallenges(status: status);
      state = AsyncValue.data(challenges);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => loadChallenges();
}
