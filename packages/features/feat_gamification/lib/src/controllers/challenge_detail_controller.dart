import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge_models.dart';
import '../prediction_providers.dart';

final challengeDetailProvider =
    StateNotifierProvider.family<
      ChallengeDetailController,
      AsyncValue<ChallengeDetailPayload>,
      String
    >((ref, id) {
      return ChallengeDetailController(
        ref.watch(challengeRepositoryProvider),
        id,
      );
    });

class ChallengeDetailController
    extends StateNotifier<AsyncValue<ChallengeDetailPayload>> {
  ChallengeDetailController(this._repository, this._id)
    : super(const AsyncValue.loading()) {
    unawaited(load());
  }

  final ChallengeRepository _repository;
  final String _id;

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final payload = await _repository.loadChallengeDetail(_id);
      if (payload == null) {
        state = AsyncValue.error(
          StateError('Challenge not found.'),
          StackTrace.current,
        );
        return;
      }
      state = AsyncValue.data(payload);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<ChallengeMutationResult> join(int homeScore, int awayScore) async {
    final result = await _repository.joinChallenge(
      challengeId: _id,
      homeScore: homeScore,
      awayScore: awayScore,
    );
    if (result.isSuccess) {
      await load();
    }
    return result;
  }

  Future<ChallengeMutationResult> cancel() async {
    final result = await _repository.cancelChallenge(_id);
    if (result.isSuccess) {
      await load();
    }
    return result;
  }
}
