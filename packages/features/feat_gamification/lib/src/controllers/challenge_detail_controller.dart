import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/challenge_models.dart';
import '../prediction_providers.dart';

final challengeDetailProvider = StateNotifierProvider.family<ChallengeDetailController, AsyncValue<ChallengeDetailState>, String>((ref, id) {
  return ChallengeDetailController(ref.watch(challengeRepositoryProvider), id);
});

class ChallengeDetailState {
  const ChallengeDetailState({
    required this.challenge,
    required this.entries,
    this.userEntry,
  });

  final Challenge challenge;
  final List<ChallengeEntry> entries;
  final ChallengeEntry? userEntry;

  bool get hasJoined => userEntry != null;
}

class ChallengeDetailController extends StateNotifier<AsyncValue<ChallengeDetailState>> {
  ChallengeDetailController(this._repository, this._id) : super(const AsyncValue.loading()) {
    load();
  }

  final ChallengeRepository _repository;
  final String _id;

  Future<void> load() async {
    try {
      final challenge = await _repository.loadChallengeDetail(_id);
      if (challenge == null) {
        state = AsyncValue.error('Challenge not found', StackTrace.current);
        return;
      }

      final entries = await _repository.loadChallengeEntries(_id);
      final userEntry = await _repository.loadUserEntry(_id);

      state = AsyncValue.data(ChallengeDetailState(
        challenge: challenge,
        entries: entries,
        userEntry: userEntry,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> join(int homeScore, int awayScore) async {
    final success = await _repository.joinChallenge(
      challengeId: _id,
      homeScore: homeScore,
      awayScore: awayScore,
    );
    if (success) {
      await load();
    }
    return success;
  }
}
