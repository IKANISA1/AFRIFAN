import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge_models.dart';
import '../prediction_providers.dart';

class ChallengeFeedState {
  const ChallengeFeedState({
    this.featured = const <Challenge>[],
    this.open = const <Challenge>[],
    this.mine = const <Challenge>[],
    this.settled = const <Challenge>[],
  });

  final List<Challenge> featured;
  final List<Challenge> open;
  final List<Challenge> mine;
  final List<Challenge> settled;

  bool get isEmpty =>
      featured.isEmpty && open.isEmpty && mine.isEmpty && settled.isEmpty;

  List<Challenge> allVisible() {
    final seen = <String>{};
    final merged = <Challenge>[...featured, ...open, ...mine, ...settled];
    return merged.where((challenge) => seen.add(challenge.id)).toList();
  }
}

final challengeFeedProvider =
    StateNotifierProvider<
      ChallengeFeedController,
      AsyncValue<ChallengeFeedState>
    >((ref) => ChallengeFeedController(ref.watch(challengeRepositoryProvider)));

final myChallengesProvider =
    StateNotifierProvider<MyChallengesController, AsyncValue<List<Challenge>>>(
      (ref) => MyChallengesController(ref.watch(challengeRepositoryProvider)),
    );

class ChallengeFeedController
    extends StateNotifier<AsyncValue<ChallengeFeedState>> {
  ChallengeFeedController(this._repository)
    : super(const AsyncValue.loading()) {
    unawaited(load());
  }

  final ChallengeRepository _repository;

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final results = await Future.wait<List<Challenge>>([
        _repository.loadChallenges(
          statuses: const <String>['open'],
          sort: 'high_pool',
          limit: 5,
        ),
        _repository.loadChallenges(
          statuses: const <String>['open'],
          sort: 'ending_soon',
          limit: 24,
        ),
        _repository.loadMyChallenges(
          statuses: const <String>['open', 'locked'],
          sort: 'ending_soon',
          limit: 12,
        ),
        _repository.loadChallenges(
          statuses: const <String>['settled', 'void', 'cancelled'],
          sort: 'settled',
          limit: 12,
        ),
      ]);

      state = AsyncValue.data(
        ChallengeFeedState(
          featured: results[0],
          open: results[1],
          mine: results[2],
          settled: results[3],
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => load();
}

class MyChallengesController
    extends StateNotifier<AsyncValue<List<Challenge>>> {
  MyChallengesController(this._repository) : super(const AsyncValue.loading()) {
    unawaited(loadOpen());
  }

  final ChallengeRepository _repository;

  Future<void> loadOpen() => _load(const <String>['open'], sort: 'ending_soon');

  Future<void> loadLocked() =>
      _load(const <String>['locked'], sort: 'ending_soon');

  Future<void> loadSettled() =>
      _load(const <String>['settled'], sort: 'settled');

  Future<void> loadVoided() =>
      _load(const <String>['void', 'cancelled'], sort: 'settled');

  Future<void> _load(List<String> statuses, {required String sort}) async {
    state = const AsyncLoading();
    try {
      final items = await _repository.loadMyChallenges(
        statuses: statuses,
        sort: sort,
        limit: 40,
      );
      state = AsyncValue.data(items);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
