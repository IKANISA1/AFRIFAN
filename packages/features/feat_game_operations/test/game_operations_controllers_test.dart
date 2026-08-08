import 'dart:async';

import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_operations_test_support.dart';

void main() {
  test(
    'display inventory loads and owner mutations refresh authority',
    () async {
      final gateway = FakeGameOperationsGateway();
      final controller = DisplayInventoryController(gateway);
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.state.status, GameOperationsLoadStatus.ready);
      expect(controller.state.inventory?.displays, hasLength(1));

      expect(
        await controller.claim(
          challenge: 'A1B2C3D4',
          displayName: 'Kitchen',
          scopeType: 'home',
        ),
        isTrue,
      );
      expect(gateway.claims, 1);
      expect(gateway.displayFetches, 2);
    },
  );

  test('display recovery retries one bootstrap challenge intent', () async {
    final gateway = FakeGameOperationsGateway()..mutationFailuresRemaining = 1;
    final controller = DisplayInventoryController(gateway);
    addTearDown(controller.dispose);
    await controller.load();

    expect(
      await controller.recover(displayId: 'display-1', challenge: 'a1b2c3d4'),
      isFalse,
    );
    expect(
      await controller.recover(displayId: 'display-1', challenge: 'A1B2C3D4'),
      isTrue,
    );

    expect(gateway.recoveryChallenges, const <String>['A1B2C3D4', 'A1B2C3D4']);
    expect(gateway.recoveryIdempotencyKeys, hasLength(2));
    expect(
      gateway.recoveryIdempotencyKeys[1],
      gateway.recoveryIdempotencyKeys[0],
    );
  });

  test('timed-out display recovery locks every owner mutation', () async {
    final gateway = FakeGameOperationsGateway()
      ..nextMutationError = const GameOperationsFailure(
        GameOperationsFailureKind.timeout,
      );
    final controller = DisplayInventoryController(gateway);
    addTearDown(controller.dispose);
    await controller.load();

    expect(
      await controller.recover(displayId: 'display-1', challenge: 'A1B2C3D4'),
      isFalse,
    );
    expect(controller.state.requiresAuthoritativeRefresh, isTrue);
    expect(await controller.revoke('display-1'), isFalse);
    expect(gateway.revocations, 0);
  });

  test('display update retries reuse one operation idempotency key', () async {
    final gateway = FakeGameOperationsGateway()..mutationFailuresRemaining = 1;
    final controller = DisplayInventoryController(gateway);
    addTearDown(controller.dispose);
    await controller.load();

    expect(
      await controller.update(
        displayId: 'display-1',
        displayName: 'Living room',
        scopeType: 'home',
      ),
      isFalse,
    );
    expect(
      await controller.update(
        displayId: 'display-1',
        displayName: 'Living room',
        scopeType: 'home',
      ),
      isTrue,
    );

    expect(gateway.updateIdempotencyKeys, hasLength(2));
    expect(gateway.updateIdempotencyKeys[1], gateway.updateIdempotencyKeys[0]);

    expect(
      await controller.update(
        displayId: 'display-1',
        displayName: 'Living room',
        scopeType: 'home',
      ),
      isTrue,
    );
    expect(
      gateway.updateIdempotencyKeys[2],
      isNot(gateway.updateIdempotencyKeys[1]),
      reason: 'A confirmed operation must release its retry key.',
    );
  });

  test(
    'timed-out display mutation requires authoritative refresh before retry',
    () async {
      final gateway = FakeGameOperationsGateway()
        ..nextMutationError = const GameOperationsFailure(
          GameOperationsFailureKind.timeout,
        );
      final controller = DisplayInventoryController(gateway);
      addTearDown(controller.dispose);
      await controller.load();

      expect(
        await controller.update(
          displayId: 'display-1',
          displayName: 'Living room',
          scopeType: 'home',
        ),
        isFalse,
      );
      expect(controller.state.requiresAuthoritativeRefresh, isTrue);
      expect(gateway.updates, 1);

      expect(
        await controller.update(
          displayId: 'display-1',
          displayName: 'Living room',
          scopeType: 'home',
        ),
        isFalse,
      );
      expect(
        gateway.updates,
        1,
        reason: 'An uncertain operation must not be repeated before refresh.',
      );

      await controller.load();
      expect(controller.state.requiresAuthoritativeRefresh, isFalse);
      expect(
        await controller.update(
          displayId: 'display-1',
          displayName: 'Living room',
          scopeType: 'home',
        ),
        isTrue,
      );
      expect(gateway.updateIdempotencyKeys, hasLength(2));
      expect(
        gateway.updateIdempotencyKeys[1],
        gateway.updateIdempotencyKeys[0],
      );
    },
  );

  test(
    'unexpected gateway error cannot leave display mutation stuck',
    () async {
      final gateway = FakeGameOperationsGateway()
        ..nextMutationError = StateError('transport closed');
      final controller = DisplayInventoryController(gateway);
      addTearDown(controller.dispose);
      await controller.load();

      expect(await controller.revoke('display-1'), isFalse);
      expect(controller.state.mutating, isFalse);
      expect(
        controller.state.failure?.kind,
        GameOperationsFailureKind.unavailable,
      );
    },
  );

  test('managed inventory preserves permission failure kind', () async {
    final gateway = FakeGameOperationsGateway()
      ..managedFailure = const GameOperationsFailure(
        GameOperationsFailureKind.permissionDenied,
      );
    final controller = ManagedGamesController(gateway);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.status, GameOperationsLoadStatus.failure);
    expect(
      controller.state.failure?.kind,
      GameOperationsFailureKind.permissionDenied,
    );
  });

  test(
    'managed permission denial clears retained organizer inventory',
    () async {
      final gateway = FakeGameOperationsGateway();
      final controller = ManagedGamesController(gateway);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.inventory, isNotNull);
      expect(controller.state.canPlanSession, isTrue);

      gateway.managedFailure = const GameOperationsFailure(
        GameOperationsFailureKind.permissionDenied,
      );
      await controller.load();

      expect(controller.state.status, GameOperationsLoadStatus.failure);
      expect(controller.state.inventory, isNull);
      expect(controller.state.canUseInventory, isFalse);
      expect(controller.state.canPlanSession, isFalse);
    },
  );

  test(
    'retained organizer loading and failure state block stale actions',
    () async {
      final gateway = FakeGameOperationsGateway();
      final controller = ManagedGamesController(gateway);
      addTearDown(controller.dispose);
      await controller.load();

      final pending = Completer<ManagedGamesInventory>();
      gateway.managedFetchCompleter = pending;
      final refresh = controller.load();
      expect(controller.state.status, GameOperationsLoadStatus.loading);
      expect(controller.state.inventory, isNotNull);
      expect(controller.state.canUseInventory, isFalse);
      expect(controller.state.canPlanSession, isFalse);

      pending.completeError(
        const GameOperationsFailure(GameOperationsFailureKind.offline),
      );
      await refresh;
      expect(controller.state.status, GameOperationsLoadStatus.failure);
      expect(controller.state.inventory, isNotNull);
      expect(controller.state.canUseInventory, isFalse);
      expect(controller.state.canPlanSession, isFalse);
    },
  );

  test(
    'display inventory preserves typed offline state and refresh lock',
    () async {
      final gateway = FakeGameOperationsGateway()
        ..displayFailure = const GameOperationsFailure(
          GameOperationsFailureKind.offline,
        );
      final controller = DisplayInventoryController(gateway);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, GameOperationsLoadStatus.failure);
      expect(controller.state.failure?.kind, GameOperationsFailureKind.offline);
      expect(controller.state.requiresAuthoritativeRefresh, isTrue);
    },
  );

  test(
    'display permission denial clears retained protected inventory',
    () async {
      final gateway = FakeGameOperationsGateway();
      final controller = DisplayInventoryController(gateway);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.inventory, isNotNull);

      gateway.displayFailure = const GameOperationsFailure(
        GameOperationsFailureKind.permissionDenied,
      );
      await controller.load();

      expect(controller.state.status, GameOperationsLoadStatus.failure);
      expect(
        controller.state.failure?.kind,
        GameOperationsFailureKind.permissionDenied,
      );
      expect(controller.state.inventory, isNull);
      expect(controller.state.canManageDisplay, isFalse);
    },
  );

  test('retained loading state blocks every owner display mutation', () async {
    final gateway = FakeGameOperationsGateway();
    final controller = DisplayInventoryController(gateway);
    addTearDown(controller.dispose);
    await controller.load();

    gateway.displayFetchCompleter = Completer<OwnedDisplayInventory>();
    final refresh = controller.load();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.status, GameOperationsLoadStatus.loading);
    expect(controller.state.inventory, isNotNull);
    expect(controller.state.canManageDisplay, isFalse);
    expect(
      await controller.update(
        displayId: 'display-1',
        displayName: 'Main TV',
        scopeType: 'home',
      ),
      isFalse,
    );
    expect(await controller.revoke('display-1'), isFalse);
    expect(gateway.updates, 0);
    expect(gateway.revocations, 0);

    gateway.displayFetchCompleter!.complete(testDisplayInventory);
    await refresh;
  });

  test('planner creates against governed pack and schedule', () async {
    final gateway = FakeGameOperationsGateway();
    final controller = SessionPlannerController(gateway);
    addTearDown(controller.dispose);
    await controller.load();

    final created = await controller.create(
      packId: 'pack-1',
      scheduledStartAt: DateTime.utc(2026, 7, 31, 18),
      eligibilityScope: 'club_membership',
      displayIds: const <String>[],
      inviteeUserIds: const <String>[],
    );

    expect(created, isTrue);
    expect(gateway.creations, 1);
    expect(controller.state.createdSession?.id, 'session-1');
  });

  test(
    'planner binds invitation-only access to selected supporter identities',
    () async {
      final gateway = FakeGameOperationsGateway();
      final controller = SessionPlannerController(gateway);
      addTearDown(controller.dispose);
      await controller.load();

      final created = await controller.create(
        packId: 'pack-1',
        scheduledStartAt: DateTime.utc(2026, 7, 31, 18),
        eligibilityScope: 'invitation_only',
        displayIds: const <String>[],
        inviteeUserIds: const <String>[
          'supporter-2',
          'supporter-1',
          'supporter-2',
        ],
      );

      expect(created, isTrue);
      expect(gateway.createInviteeUserIds.single, const <String>[
        'supporter-1',
        'supporter-2',
      ]);
    },
  );

  test('planner retry preserves the original operation intent', () async {
    final gateway = FakeGameOperationsGateway()..mutationFailuresRemaining = 1;
    final controller = SessionPlannerController(gateway);
    addTearDown(controller.dispose);
    await controller.load();
    final start = DateTime.utc(2026, 7, 31, 18);

    expect(
      await controller.create(
        packId: 'pack-1',
        scheduledStartAt: start,
        eligibilityScope: 'club_membership',
        displayIds: const <String>['display-1'],
        inviteeUserIds: const <String>[],
      ),
      isFalse,
    );
    expect(
      await controller.create(
        packId: 'pack-1',
        scheduledStartAt: start,
        eligibilityScope: 'club_membership',
        displayIds: const <String>['display-1'],
        inviteeUserIds: const <String>[],
      ),
      isTrue,
    );

    expect(gateway.createIdempotencyKeys, hasLength(2));
    expect(gateway.createIdempotencyKeys[1], gateway.createIdempotencyKeys[0]);
  });

  test('planner timeout blocks another submission until refresh', () async {
    final gateway = FakeGameOperationsGateway()
      ..nextMutationError = const GameOperationsFailure(
        GameOperationsFailureKind.timeout,
      );
    final controller = SessionPlannerController(gateway);
    addTearDown(controller.dispose);
    await controller.load();
    final start = DateTime.utc(2026, 7, 31, 18);

    expect(
      await controller.create(
        packId: 'pack-1',
        scheduledStartAt: start,
        eligibilityScope: 'club_membership',
        displayIds: const <String>[],
        inviteeUserIds: const <String>[],
      ),
      isFalse,
    );
    expect(controller.state.requiresAuthoritativeRefresh, isTrue);
    expect(gateway.creations, 1);

    expect(
      await controller.create(
        packId: 'pack-1',
        scheduledStartAt: start,
        eligibilityScope: 'club_membership',
        displayIds: const <String>[],
        inviteeUserIds: const <String>[],
      ),
      isFalse,
    );
    expect(gateway.creations, 1);

    await controller.load();
    expect(
      await controller.create(
        packId: 'pack-1',
        scheduledStartAt: start,
        eligibilityScope: 'club_membership',
        displayIds: const <String>[],
        inviteeUserIds: const <String>[],
      ),
      isTrue,
    );
    expect(gateway.createIdempotencyKeys[1], gateway.createIdempotencyKeys[0]);
  });

  test('planner retained loading state blocks edits and submission', () async {
    final gateway = FakeGameOperationsGateway();
    final controller = SessionPlannerController(gateway);
    addTearDown(controller.dispose);
    await controller.load();

    gateway.plannerFetchCompleter = Completer<GamePlannerOptions>();
    final refresh = controller.load();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.status, GameOperationsLoadStatus.loading);
    expect(controller.state.options, same(testPlannerOptions));
    expect(controller.state.canEditPlan, isFalse);
    expect(
      await controller.create(
        packId: 'pack-1',
        scheduledStartAt: DateTime.utc(2026, 7, 31, 18),
        eligibilityScope: 'club_membership',
        displayIds: const <String>[],
        inviteeUserIds: const <String>[],
      ),
      isFalse,
    );
    expect(gateway.creations, 0);

    gateway.plannerFetchCompleter!.complete(testPlannerOptions);
    await refresh;
    expect(controller.state.canEditPlan, isTrue);
  });

  test('planner permission denial clears retained organizer options', () async {
    final gateway = FakeGameOperationsGateway();
    final controller = SessionPlannerController(gateway);
    addTearDown(controller.dispose);
    await controller.load();

    gateway.managedFailure = const GameOperationsFailure(
      GameOperationsFailureKind.permissionDenied,
    );
    await controller.load();

    expect(controller.state.status, GameOperationsLoadStatus.failure);
    expect(controller.state.options, isNull);
    expect(controller.state.canEditPlan, isFalse);
    expect(controller.state.canSubmit, isFalse);
  });

  test(
    'planner conflict retains intent but requires authoritative refresh',
    () async {
      final gateway = FakeGameOperationsGateway()
        ..nextMutationError = const GameOperationsFailure(
          GameOperationsFailureKind.conflict,
        );
      final controller = SessionPlannerController(gateway);
      addTearDown(controller.dispose);
      await controller.load();
      final start = DateTime.utc(2026, 7, 31, 18);

      expect(
        await controller.create(
          packId: 'pack-1',
          scheduledStartAt: start,
          eligibilityScope: 'club_membership',
          displayIds: const <String>['display-1'],
          inviteeUserIds: const <String>[],
        ),
        isFalse,
      );
      expect(controller.state.options, same(testPlannerOptions));
      expect(controller.state.canEditPlan, isFalse);
      expect(controller.state.canSubmit, isFalse);
      expect(gateway.creations, 1);

      await controller.load();
      expect(controller.state.canEditPlan, isTrue);
      expect(
        await controller.create(
          packId: 'pack-1',
          scheduledStartAt: start,
          eligibilityScope: 'club_membership',
          displayIds: const <String>['display-1'],
          inviteeUserIds: const <String>[],
        ),
        isTrue,
      );
      expect(
        gateway.createIdempotencyKeys[1],
        gateway.createIdempotencyKeys[0],
      );
    },
  );

  test('live control allows only server-authorized transitions', () async {
    final gateway = FakeGameOperationsGateway();
    final controller = LiveGameControlController(gateway, 'session-1');
    addTearDown(controller.dispose);
    await controller.load();

    expect(await controller.transition('reveal'), isFalse);
    expect(gateway.transitions, 0);
    expect(
      controller.state.failure?.kind,
      GameOperationsFailureKind.invalidInput,
    );

    expect(await controller.transition('activated_lobby'), isTrue);
    expect(gateway.transitions, 1);
    expect(controller.state.session?.phase, 'activated_lobby');
  });

  test('live retry preserves idempotency key and phase deadline', () async {
    final gateway = FakeGameOperationsGateway()
      ..managedGame = ManagedGameSession(
        clubId: testManagedGame.clubId,
        id: testManagedGame.id,
        title: testManagedGame.title,
        packTitle: testManagedGame.packTitle,
        phase: 'question_ready',
        sessionVersion: 7,
        questionVersion: 2,
        eventSequence: 9,
        serverTime: testManagedGame.serverTime,
        scheduledStartAt: testManagedGame.scheduledStartAt,
        eligibilityScope: testManagedGame.eligibilityScope,
        allowedActions: const <String>['question_open'],
        participantCount: testManagedGame.participantCount,
        assignedDisplays: testManagedGame.assignedDisplays,
        currentQuestion: const ManagedQuestionControl(
          id: 'session-question-1',
          ordinal: 1,
          state: 'ready',
          prompt: 'Sample prompt',
          options: <Map<String, dynamic>>[],
        ),
      )
      ..mutationFailuresRemaining = 1;
    final controller = LiveGameControlController(gateway, 'session-1');
    addTearDown(controller.dispose);
    await controller.load();

    expect(await controller.transition('question_open'), isFalse);
    expect(await controller.transition('question_open'), isTrue);

    expect(gateway.transitionIdempotencyKeys, hasLength(2));
    expect(
      gateway.transitionIdempotencyKeys[1],
      gateway.transitionIdempotencyKeys[0],
    );
    expect(gateway.transitionDeadlines[0], isNotNull);
    expect(gateway.transitionDeadlines[1], gateway.transitionDeadlines[0]);
  });

  test('live timeout blocks transitions until authoritative refresh', () async {
    final gateway = FakeGameOperationsGateway()
      ..nextMutationError = const GameOperationsFailure(
        GameOperationsFailureKind.timeout,
      );
    final controller = LiveGameControlController(gateway, 'session-1');
    addTearDown(controller.dispose);
    await controller.load();

    expect(await controller.transition('activated_lobby'), isFalse);
    expect(controller.state.requiresAuthoritativeRefresh, isTrue);
    expect(gateway.transitions, 1);

    expect(await controller.transition('activated_lobby'), isFalse);
    expect(gateway.transitions, 1);

    await controller.load();
    expect(await controller.transition('activated_lobby'), isTrue);
    expect(
      gateway.transitionIdempotencyKeys[1],
      gateway.transitionIdempotencyKeys[0],
    );
  });

  test('live retained loading state locks every organizer action', () async {
    final gateway = FakeGameOperationsGateway();
    final controller = LiveGameControlController(gateway, 'session-1');
    addTearDown(controller.dispose);
    await controller.load();

    gateway.managedGameFetchCompleter = Completer<ManagedGameSession>();
    final refresh = controller.load();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.status, GameOperationsLoadStatus.loading);
    expect(controller.state.session, same(testManagedGame));
    expect(controller.state.canOperate, isFalse);
    expect(await controller.transition('activated_lobby'), isFalse);
    expect(gateway.transitions, 0);

    gateway.managedGameFetchCompleter!.complete(testManagedGame);
    await refresh;
    expect(controller.state.canOperate, isTrue);
  });

  test(
    'live failed refresh retains context but requires fresh authority',
    () async {
      final gateway = FakeGameOperationsGateway();
      final controller = LiveGameControlController(gateway, 'session-1');
      addTearDown(controller.dispose);
      await controller.load();

      gateway.managedFailure = const GameOperationsFailure(
        GameOperationsFailureKind.offline,
      );
      await controller.load();

      expect(controller.state.session, same(testManagedGame));
      expect(controller.state.requiresAuthoritativeRefresh, isTrue);
      expect(controller.state.canOperate, isFalse);
      expect(await controller.transition('activated_lobby'), isFalse);
      expect(gateway.transitions, 0);

      gateway.managedFailure = null;
      await controller.load();
      expect(controller.state.canOperate, isTrue);
    },
  );

  test('live permission denial clears the retained private session', () async {
    final gateway = FakeGameOperationsGateway();
    final controller = LiveGameControlController(gateway, 'session-1');
    addTearDown(controller.dispose);
    await controller.load();

    gateway.managedFailure = const GameOperationsFailure(
      GameOperationsFailureKind.permissionDenied,
    );
    await controller.load();

    expect(controller.state.status, GameOperationsLoadStatus.failure);
    expect(controller.state.session, isNull);
    expect(controller.state.canOperate, isFalse);
  });

  test(
    'live skip uses the reasoned exception gateway, never transition',
    () async {
      final gateway = FakeGameOperationsGateway()
        ..managedGame = testQuestionOpenManagedGame;
      final controller = LiveGameControlController(gateway, 'session-1');
      addTearDown(controller.dispose);
      await controller.load();

      expect(await controller.transition('skip_question'), isFalse);
      expect(gateway.transitions, 0);
      expect(
        await controller.skipQuestion(
          nextSessionQuestionId: 'session-question-2',
          reason: 'Question withdrawn by the organizer',
        ),
        isTrue,
      );

      expect(gateway.skips, 1);
      expect(gateway.transitions, 0);
      expect(gateway.skippedToQuestionIds.single, 'session-question-2');
      expect(gateway.skipReasons.single, 'Question withdrawn by the organizer');
      expect(controller.state.session?.currentQuestion?.ordinal, 2);
    },
  );

  test(
    'live early-end retry preserves its reason and idempotency key',
    () async {
      final gateway = FakeGameOperationsGateway()
        ..managedGame = testQuestionOpenManagedGame
        ..mutationFailuresRemaining = 1;
      final controller = LiveGameControlController(gateway, 'session-1');
      addTearDown(controller.dispose);
      await controller.load();

      expect(
        await controller.endEarly(reason: 'Severe weather at the venue'),
        isFalse,
      );
      expect(
        await controller.endEarly(reason: 'Severe weather at the venue'),
        isTrue,
      );

      expect(gateway.earlyEnds, 2);
      expect(gateway.earlyEndReasons, <String>[
        'Severe weather at the venue',
        'Severe weather at the venue',
      ]);
      expect(
        gateway.earlyEndIdempotencyKeys[1],
        gateway.earlyEndIdempotencyKeys[0],
      );
      expect(gateway.transitions, 0);
    },
  );

  test(
    'live conflict blocks every action until authoritative refresh',
    () async {
      final gateway = FakeGameOperationsGateway()
        ..managedGame = testQuestionOpenManagedGame
        ..nextMutationError = const GameOperationsFailure(
          GameOperationsFailureKind.conflict,
        );
      final controller = LiveGameControlController(gateway, 'session-1');
      addTearDown(controller.dispose);
      await controller.load();

      expect(await controller.transition('reveal'), isFalse);
      expect(controller.state.requiresAuthoritativeRefresh, isTrue);
      expect(
        await controller.skipQuestion(
          nextSessionQuestionId: 'session-question-2',
          reason: 'Question withdrawn by the organizer',
        ),
        isFalse,
      );
      expect(gateway.skips, 0);

      await controller.load();
      expect(
        await controller.skipQuestion(
          nextSessionQuestionId: 'session-question-2',
          reason: 'Question withdrawn by the organizer',
        ),
        isTrue,
      );
      expect(gateway.skips, 1);
    },
  );

  test(
    'live exception rejects missing next question and unsafe reasons',
    () async {
      final gateway = FakeGameOperationsGateway()
        ..managedGame = testQuestionOpenManagedGame;
      final controller = LiveGameControlController(gateway, 'session-1');
      addTearDown(controller.dispose);
      await controller.load();

      expect(
        await controller.skipQuestion(
          nextSessionQuestionId: 'session-question-1',
          reason: 'No',
        ),
        isFalse,
      );
      expect(await controller.endEarly(reason: '  '), isFalse);
      expect(gateway.skips, 0);
      expect(gateway.earlyEnds, 0);
    },
  );
}
