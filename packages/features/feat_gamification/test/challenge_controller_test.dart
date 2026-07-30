import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/controllers/challenge_controller.dart';
import 'package:feat_gamification/src/models/challenge_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'challenge_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('bounded load maps an uncertain timeout to a safe failure', () async {
    final repository = FakeChallengeRepository()
      ..loadCompleter = Completer<List<Challenge>>();
    final controller = ChallengeFeedController(
      repository,
      loadTimeout: const Duration(milliseconds: 1),
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    final failure = controller.state.error;
    expect(failure, isA<ChallengeFeedFailure>());
    expect(
      (failure! as ChallengeFeedFailure).kind,
      ChallengeFeedFailureKind.securityTimeout,
    );
    expect(failure.toString(), isNot(contains('supporter')));
  });

  test('refresh retains settled challenge content after conflict', () async {
    final repository = FakeChallengeRepository()
      ..featuredChallenges = [
        buildChallenge(
          id: 'retained',
          fixture: buildFixture(id: 'retained-fixture'),
        ),
      ];
    final controller = ChallengeFeedController(repository, autoLoad: false);
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.state.asData?.value.featured, hasLength(1));

    repository.loadError = StateError(
      'stale revision conflict for supporter-991',
    );
    await controller.refresh();

    final retained = controller.state.asData!.value;
    expect(retained.featured.single.id, 'retained');
    expect(retained.status, ChallengeFeedStatus.degraded);
    expect(retained.message, contains('changed elsewhere'));
    expect(retained.message, isNot(contains('991')));
  });

  test('parallel refresh attempts coalesce to one four-read batch', () async {
    final repository = FakeChallengeRepository()
      ..featuredChallenges = [
        buildChallenge(
          id: 'settled',
          fixture: buildFixture(id: 'settled-fixture'),
        ),
      ];
    final controller = ChallengeFeedController(repository, autoLoad: false);
    addTearDown(controller.dispose);
    await controller.load();
    expect(repository.loadCalls, 4);

    final pending = Completer<List<Challenge>>();
    repository.loadCompleter = pending;
    final first = controller.refresh();
    final second = controller.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(repository.loadCalls, 8);
    pending.complete(const <Challenge>[]);
    await Future.wait<void>([first, second]);
    expect(repository.loadCalls, 8);
  });

  test('offline load fails closed without touching the repository', () async {
    ConnectivityService.setOnlineForTest(false);
    final repository = FakeChallengeRepository();
    final controller = ChallengeFeedController(repository, autoLoad: false);
    addTearDown(controller.dispose);

    await controller.load();

    final failure = controller.state.error! as ChallengeFeedFailure;
    expect(failure.kind, ChallengeFeedFailureKind.offline);
    expect(repository.loadCalls, 0);
  });
}
