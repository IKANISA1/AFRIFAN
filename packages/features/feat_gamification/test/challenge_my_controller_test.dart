import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/controllers/challenge_my_controller.dart';
import 'package:feat_gamification/src/models/challenge_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'challenge_test_helpers.dart';

class _QueuedChallengeRepository extends FakeChallengeRepository {
  final List<Completer<List<Challenge>>> responses =
      <Completer<List<Challenge>>>[];
  final List<List<String>> requestedStatuses = <List<String>>[];
  final List<String> requestedSorts = <String>[];
  final List<int> requestedLimits = <int>[];

  int activeLoads = 0;
  int maxActiveLoads = 0;

  @override
  Future<List<Challenge>> loadMyChallenges({
    List<String>? statuses,
    String sort = 'ending_soon',
    int limit = 20,
    int offset = 0,
  }) async {
    loadCalls++;
    requestedStatuses.add(List<String>.of(statuses ?? const <String>[]));
    requestedSorts.add(sort);
    requestedLimits.add(limit);
    activeLoads++;
    if (activeLoads > maxActiveLoads) maxActiveLoads = activeLoads;
    final response = responses.removeAt(0);
    try {
      return await response.future;
    } finally {
      activeLoads--;
    }
  }
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('classifies failures without exposing repository details', () {
    final permission = MyChallengesFailure.fromError(
      StateError('RLS denied for supporter-991@example.test'),
    );
    final conflict = MyChallengesFailure.fromError(
      StateError('stale revision for private-token-123'),
    );
    final unknown = MyChallengesFailure.fromError(
      StateError('private-token-123'),
    );

    expect(permission.kind, MyChallengesFailureKind.permissionDenied);
    expect(conflict.kind, MyChallengesFailureKind.conflict);
    expect(unknown.kind, MyChallengesFailureKind.unknown);
    expect(permission.toString(), isNot(contains('supporter-991')));
    expect(conflict.toString(), isNot(contains('private-token-123')));
    expect(unknown.toString(), isNot(contains('private-token-123')));
  });

  test(
    'loads the selected filter with bounded repository parameters',
    () async {
      final repository = FakeChallengeRepository()
        ..mySettledChallenges = <Challenge>[
          buildChallenge(id: 'settled', status: ChallengeStatus.settled),
        ];
      final controller = MyChallengesController(repository, autoLoad: false);
      addTearDown(controller.dispose);

      await controller.select(MyChallengeFilter.settled);

      final value = controller.state.requireValue;
      expect(value.filter, MyChallengeFilter.settled);
      expect(value.items.single.id, 'settled');
      expect(repository.lastMyStatuses, <String>['settled']);
      expect(repository.lastMySort, 'settled');
      expect(repository.loadCalls, 1);
    },
  );

  test('fails offline without reaching the repository', () async {
    ConnectivityService.setOnlineForTest(false);
    final repository = FakeChallengeRepository();
    final controller = MyChallengesController(repository, autoLoad: false);
    addTearDown(controller.dispose);

    await controller.select(MyChallengeFilter.open);

    expect(repository.loadCalls, 0);
    expect(controller.state.hasError, isTrue);
    expect(
      (controller.state.error! as MyChallengesFailure).kind,
      MyChallengesFailureKind.offline,
    );
  });

  test('turns an unbounded repository wait into a security timeout', () async {
    final repository = FakeChallengeRepository()
      ..loadCompleter = Completer<List<Challenge>>();
    final controller = MyChallengesController(
      repository,
      autoLoad: false,
      loadTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(controller.dispose);

    await controller.select(MyChallengeFilter.open);

    expect(controller.state.hasError, isTrue);
    expect(
      (controller.state.error! as MyChallengesFailure).kind,
      MyChallengesFailureKind.securityTimeout,
    );
  });

  test('retains confirmed items when a refresh conflicts', () async {
    final confirmed = buildChallenge(id: 'confirmed-open');
    final repository = FakeChallengeRepository()
      ..myOpenChallenges = <Challenge>[confirmed];
    final controller = MyChallengesController(repository, autoLoad: false);
    addTearDown(controller.dispose);

    await controller.select(MyChallengeFilter.open);
    repository.loadError = StateError('stale revision');
    await controller.refresh();

    final value = controller.state.requireValue;
    expect(value.items, <Challenge>[confirmed]);
    expect(value.phase, MyChallengesPhase.degraded);
    expect(value.actionsBlocked, isTrue);
    expect(value.failure?.kind, MyChallengesFailureKind.conflict);
  });

  test('shows retained items as syncing while refresh is pending', () async {
    final confirmed = buildChallenge(id: 'confirmed-open');
    final repository = FakeChallengeRepository()
      ..myOpenChallenges = <Challenge>[confirmed];
    final controller = MyChallengesController(repository, autoLoad: false);
    addTearDown(controller.dispose);

    await controller.select(MyChallengeFilter.open);
    repository.loadCompleter = Completer<List<Challenge>>();
    final refresh = controller.refresh();
    await _flushAsyncWork();

    final syncing = controller.state.requireValue;
    expect(syncing.items, <Challenge>[confirmed]);
    expect(syncing.phase, MyChallengesPhase.syncing);
    expect(syncing.actionsBlocked, isTrue);

    repository.loadCompleter!.complete(<Challenge>[confirmed]);
    await refresh;
    expect(controller.state.requireValue.phase, MyChallengesPhase.ready);
  });

  test(
    'serializes rapid tab loads and applies only the latest selection',
    () async {
      final repository = _QueuedChallengeRepository();
      final openResponse = Completer<List<Challenge>>();
      final settledResponse = Completer<List<Challenge>>();
      repository.responses.addAll(<Completer<List<Challenge>>>[
        openResponse,
        settledResponse,
      ]);
      final controller = MyChallengesController(repository, autoLoad: false);
      addTearDown(controller.dispose);

      final openLoad = controller.select(MyChallengeFilter.open);
      final skippedLocked = controller.select(MyChallengeFilter.locked);
      final settledLoad = controller.select(MyChallengeFilter.settled);
      await _flushAsyncWork();

      expect(repository.activeLoads, 1);
      expect(repository.maxActiveLoads, 1);
      openResponse.complete(<Challenge>[buildChallenge(id: 'stale-open')]);
      await openLoad;
      await _flushAsyncWork();

      expect(repository.activeLoads, 1);
      expect(repository.requestedStatuses, <List<String>>[
        <String>['open'],
        <String>['settled'],
      ]);
      settledResponse.complete(<Challenge>[
        buildChallenge(id: 'latest-settled', status: ChallengeStatus.settled),
      ]);
      await Future.wait(<Future<void>>[skippedLocked, settledLoad]);

      final value = controller.state.requireValue;
      expect(value.filter, MyChallengeFilter.settled);
      expect(value.items.single.id, 'latest-settled');
      expect(repository.maxActiveLoads, 1);
      expect(repository.requestedSorts, <String>['ending_soon', 'settled']);
      expect(repository.requestedLimits, <int>[40, 40]);
    },
  );
}
