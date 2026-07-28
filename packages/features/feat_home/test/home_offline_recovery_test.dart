import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_home/src/providers/home_feed_provider.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));

  test('retains Home data throughout a slow refresh', () async {
    final pending = Completer<HomeFeedSnapshot>();
    final repository = _SequencedHomeFeedRepository([
      () async => _currentSnapshot,
      () => pending.future,
    ]);
    final container = ProviderContainer(
      overrides: [homeFeedRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(homeFeedProvider.future);
    final refresh = container.read(homeFeedProvider.notifier).refresh();

    final refreshing = container.read(homeFeedProvider);
    expect(refreshing.isRefreshing, isTrue);
    expect(refreshing.valueOrNull?.userFet, 120);

    pending.complete(_currentSnapshot.copyWith(userFet: 140));
    await refresh;

    expect(container.read(homeFeedProvider).valueOrNull?.userFet, 140);
  });

  test('labels retained Home data stale while offline', () async {
    final repository = _SequencedHomeFeedRepository([
      () async => _currentSnapshot,
    ]);
    final container = ProviderContainer(
      overrides: [homeFeedRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(homeFeedProvider.future);
    ConnectivityService.setOnlineForTest(false);

    final retained = container.read(homeFeedProvider).valueOrNull;
    expect(retained?.userFet, 120);
    expect(retained?.status, HomeFeedStatus.degraded);
    expect(retained?.message, contains('Showing saved Home content'));
  });

  test('automatically refreshes retained Home data after reconnect', () async {
    final refreshed = Completer<HomeFeedSnapshot>();
    final repository = _SequencedHomeFeedRepository([
      () async => _currentSnapshot,
      () => refreshed.future,
    ]);
    final container = ProviderContainer(
      overrides: [homeFeedRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(homeFeedProvider.future);
    ConnectivityService.setOnlineForTest(false);
    ConnectivityService.setOnlineForTest(true);
    await Future<void>.delayed(Duration.zero);

    expect(repository.calls, 2);
    expect(container.read(homeFeedProvider).valueOrNull?.userFet, 120);
    expect(container.read(homeFeedProvider).isRefreshing, isTrue);

    refreshed.complete(_currentSnapshot.copyWith(userFet: 180));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(homeFeedProvider).valueOrNull?.userFet, 180);
    expect(container.read(homeFeedProvider).valueOrNull?.status, isNotNull);
  });
}

const _currentSnapshot = HomeFeedSnapshot(
  userFet: 120,
  status: HomeFeedStatus.success,
);

class _SequencedHomeFeedRepository implements HomeFeedRepository {
  _SequencedHomeFeedRepository(this._loads);

  final List<Future<HomeFeedSnapshot> Function()> _loads;
  int calls = 0;

  @override
  Future<HomeFeedSnapshot> load() {
    final index = calls;
    calls += 1;
    return _loads[index]();
  }
}
