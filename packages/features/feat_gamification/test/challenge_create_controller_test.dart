import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/controllers/challenge_create_controller.dart';
import 'package:feat_gamification/src/models/challenge_models.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'challenge_test_helpers.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('create failures sanitize backend categories', () {
    expect(
      ChallengeCreateFailure.fromError(
        StateError('row-level security denied supporter-991'),
      ).kind,
      ChallengeCreateFailureKind.permissionDenied,
    );
    expect(
      ChallengeCreateFailure.fromError(
        StateError('stale revision for row 88'),
      ).kind,
      ChallengeCreateFailureKind.conflict,
    );
    expect(
      ChallengeCreateFailure.fromError(
        StateError('socket included secret metadata'),
      ).kind,
      ChallengeCreateFailureKind.unknown,
    );
  });

  test('bounded fixture load maps timeout to safe failure', () async {
    final fixtures = FakeChallengeFixturesGateway()
      ..loadCompleter = Completer();
    final controller = ChallengeCreateController(
      fixtures,
      FakeChallengeRepository(),
      loadTimeout: const Duration(milliseconds: 1),
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(
      (controller.state.error as ChallengeCreateFailure).kind,
      ChallengeCreateFailureKind.securityTimeout,
    );
  });

  test('offline fixture load fails before gateway access', () async {
    ConnectivityService.setOnlineForTest(false);
    final fixtures = FakeChallengeFixturesGateway();
    final controller = ChallengeCreateController(
      fixtures,
      FakeChallengeRepository(),
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(fixtures.loadCalls, 0);
    expect(
      (controller.state.error as ChallengeCreateFailure).kind,
      ChallengeCreateFailureKind.offline,
    );
  });

  test('refresh retains fixtures after conflict', () async {
    final fixture = buildFixture();
    final fixtures = FakeChallengeFixturesGateway(fixtures: [fixture]);
    final controller = ChallengeCreateController(
      fixtures,
      FakeChallengeRepository(),
      autoLoad: false,
    );
    addTearDown(controller.dispose);
    await controller.load();
    fixtures.loadError = StateError('stale revision for supporter-991');

    await controller.refresh();

    final retained = controller.state.requireValue;
    expect(retained.fixtures, [fixture]);
    expect(retained.phase, ChallengeCreatePhase.degraded);
    expect(retained.failure?.kind, ChallengeCreateFailureKind.conflict);
  });

  test('parallel fixture refreshes coalesce', () async {
    final fixture = buildFixture();
    final fixtures = FakeChallengeFixturesGateway(fixtures: [fixture]);
    final controller = ChallengeCreateController(
      fixtures,
      FakeChallengeRepository(),
      autoLoad: false,
    );
    addTearDown(controller.dispose);
    await controller.load();
    final typedPending = Completer<List<FixtureSummary>>();
    fixtures.loadCompleter = typedPending;

    final first = controller.refresh();
    final second = controller.refresh();
    typedPending.complete([fixture]);
    await Future.wait([first, second]);

    expect(fixtures.loadCalls, 2);
  });

  test(
    'uncertain create timeout retains fixtures and blocks resubmission',
    () async {
      final fixture = buildFixture();
      final fixtures = FakeChallengeFixturesGateway(fixtures: [fixture]);
      final repository = FakeChallengeRepository()
        ..createCompleter = Completer<ChallengeMutationResult>();
      final controller = ChallengeCreateController(
        fixtures,
        repository,
        mutationTimeout: const Duration(milliseconds: 1),
        autoLoad: false,
      );
      addTearDown(controller.dispose);
      await controller.load();

      final outcome = await controller.create(
        matchId: fixture.id,
        homeScore: 2,
        awayScore: 1,
        stakeFet: 1000,
      );
      final blocked = await controller.create(
        matchId: fixture.id,
        homeScore: 2,
        awayScore: 1,
        stakeFet: 1000,
      );

      expect(outcome.isSuccess, isFalse);
      expect(outcome.failure?.kind, ChallengeCreateFailureKind.securityTimeout);
      expect(controller.state.requireValue.fixtures, [fixture]);
      expect(
        controller.state.requireValue.phase,
        ChallengeCreatePhase.degraded,
      );
      expect(blocked.isSuccess, isFalse);
      expect(repository.createCalls, 1);
    },
  );

  test(
    'successful create returns confirmed challenge without another load',
    () async {
      final fixture = buildFixture();
      final challenge = buildChallenge(id: 'created-1', fixture: fixture);
      final fixtures = FakeChallengeFixturesGateway(fixtures: [fixture]);
      final repository = FakeChallengeRepository()
        ..createResult = ChallengeMutationResult(
          status: 'created',
          challenge: challenge,
        );
      final controller = ChallengeCreateController(
        fixtures,
        repository,
        autoLoad: false,
      );
      addTearDown(controller.dispose);
      await controller.load();

      final outcome = await controller.create(
        matchId: fixture.id,
        homeScore: 2,
        awayScore: 1,
        stakeFet: 1000,
      );

      expect(outcome.isSuccess, isTrue);
      expect(outcome.challenge?.id, 'created-1');
      expect(repository.createCalls, 1);
      expect(fixtures.loadCalls, 1);
    },
  );
}
