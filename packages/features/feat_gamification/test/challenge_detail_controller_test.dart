import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/controllers/challenge_detail_controller.dart';
import 'package:feat_gamification/src/models/challenge_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'challenge_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('detail failures sanitize backend categories', () {
    expect(
      ChallengeDetailFailure.fromError(
        StateError('RLS denied for supporter-991 private challenge row'),
      ).kind,
      ChallengeDetailFailureKind.permissionDenied,
    );
    expect(
      ChallengeDetailFailure.fromError(
        StateError('stale revision conflict for supporter-991'),
      ).kind,
      ChallengeDetailFailureKind.conflict,
    );
    expect(
      ChallengeDetailFailure.fromError(
        TimeoutException('private challenge token supporter-991'),
      ).kind,
      ChallengeDetailFailureKind.securityTimeout,
    );
    expect(
      ChallengeDetailFailure.fromError(
        StateError('private challenge token supporter-991'),
      ).toString(),
      'ChallengeDetailFailure(unknown)',
    );
  });

  test('bounded detail load maps timeout to safe failure', () async {
    final repository = FakeChallengeRepository()
      ..detailLoadCompleter = Completer<ChallengeDetailPayload?>();
    final controller = ChallengeDetailController(
      repository,
      'challenge-1',
      loadTimeout: const Duration(milliseconds: 1),
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    final failure = controller.state.error! as ChallengeDetailFailure;
    expect(failure.kind, ChallengeDetailFailureKind.securityTimeout);
    expect(failure.toString(), isNot(contains('supporter')));
    expect(repository.detailLoadCalls, 1);
  });

  test('offline detail load fails before repository access', () async {
    ConnectivityService.setOnlineForTest(false);
    final repository = FakeChallengeRepository();
    final controller = ChallengeDetailController(
      repository,
      'challenge-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    final failure = controller.state.error! as ChallengeDetailFailure;
    expect(failure.kind, ChallengeDetailFailureKind.offline);
    expect(repository.detailLoadCalls, 0);
  });

  test('refresh retains settled detail after conflict', () async {
    final payload = buildDetail(
      challenge: buildChallenge(id: 'retained-detail'),
      entries: const <ChallengeEntry>[],
    );
    final repository = FakeChallengeRepository()
      ..detailsById['retained-detail'] = payload;
    final controller = ChallengeDetailController(
      repository,
      'retained-detail',
      autoLoad: false,
    );
    addTearDown(controller.dispose);
    await controller.load();

    repository.detailLoadError = StateError(
      'stale revision conflict for supporter-991',
    );
    await controller.refresh();

    final retained = controller.state.requireValue;
    expect(retained.payload?.challenge.id, 'retained-detail');
    expect(retained.phase, ChallengeDetailPhase.degraded);
    expect(retained.failure?.kind, ChallengeDetailFailureKind.conflict);
  });

  test('parallel detail refreshes coalesce', () async {
    final payload = buildDetail(
      challenge: buildChallenge(id: 'coalesced-detail'),
      entries: const <ChallengeEntry>[],
    );
    final repository = FakeChallengeRepository()
      ..detailsById['coalesced-detail'] = payload;
    final controller = ChallengeDetailController(
      repository,
      'coalesced-detail',
      autoLoad: false,
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(repository.detailLoadCalls, 1);

    final pending = Completer<ChallengeDetailPayload?>();
    repository.detailLoadCompleter = pending;
    final first = controller.refresh();
    final second = controller.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(repository.detailLoadCalls, 2);
    pending.complete(payload);
    await Future.wait<void>([first, second]);
    expect(repository.detailLoadCalls, 2);
  });

  test(
    'uncertain join timeout retains detail and blocks resubmission',
    () async {
      final payload = buildDetail(
        challenge: buildChallenge(
          id: 'join-timeout',
          permissions: const ChallengePermissions(canJoin: true),
        ),
        entries: const <ChallengeEntry>[],
      );
      final repository = FakeChallengeRepository()
        ..detailsById['join-timeout'] = payload
        ..joinCompleter = Completer<ChallengeMutationResult>();
      final controller = ChallengeDetailController(
        repository,
        'join-timeout',
        mutationTimeout: const Duration(milliseconds: 1),
        autoLoad: false,
      );
      addTearDown(controller.dispose);
      await controller.load();

      final outcome = await controller.join(2, 1);
      final retained = controller.state.requireValue;
      expect(outcome.isSuccess, isFalse);
      expect(outcome.failure?.kind, ChallengeDetailFailureKind.securityTimeout);
      expect(retained.payload?.challenge.id, 'join-timeout');
      expect(retained.phase, ChallengeDetailPhase.degraded);
      expect(retained.actionsBlocked, isTrue);
      expect(repository.joinCalls, 1);

      final repeated = await controller.join(3, 2);
      expect(repeated.isSuccess, isFalse);
      expect(repository.joinCalls, 1);
    },
  );

  test(
    'successful join adopts returned challenge without a stale reload',
    () async {
      final initial = buildChallenge(
        id: 'join-success',
        permissions: const ChallengePermissions(canJoin: true),
      );
      final joined = buildChallenge(
        id: 'join-success',
        permissions: const ChallengePermissions(hasJoined: true),
        myEntry: buildEntry(challengeId: 'join-success'),
      );
      final repository = FakeChallengeRepository()
        ..detailsById['join-success'] = buildDetail(
          challenge: initial,
          entries: const <ChallengeEntry>[],
        )
        ..joinResult = ChallengeMutationResult(
          status: 'joined',
          challenge: joined,
        );
      final controller = ChallengeDetailController(
        repository,
        'join-success',
        autoLoad: false,
      );
      addTearDown(controller.dispose);
      await controller.load();

      final outcome = await controller.join(2, 1);

      expect(outcome.isSuccess, isTrue);
      expect(
        controller.state.requireValue.payload?.challenge.hasJoined,
        isTrue,
      );
      expect(repository.detailLoadCalls, 1);
    },
  );
}
