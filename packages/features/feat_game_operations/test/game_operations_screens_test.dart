import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import 'game_operations_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  final crossClientFixture = _loadCrossClientFixture();

  testWidgets('French TV inventory reflows at 200 percent text', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway();
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/my-tvs',
      locale: const Locale('fr'),
      textScale: 2,
      size: const Size(320, 760),
    );

    expect(find.text('Mes téléviseurs'), findsOneWidget);
    expect(find.text('Living room TV'), findsOneWidget);
    expect(find.text('PAIR A TV'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner inventory shows governed display operations data', (
    tester,
  ) async {
    await _pump(
      tester,
      gateway: FakeGameOperationsGateway(),
      initialLocation: '/my-tvs',
    );

    expect(find.text('Living room TV'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Last seen'), findsOneWidget);
    expect(find.text('App version'), findsOneWidget);
    expect(find.text('2.0.0'), findsOneWidget);
    expect(find.text('Capabilities'), findsOneWidget);
    expect(find.textContaining('Remote Focus: Enabled'), findsOneWidget);
    expect(find.text('Saturday club quiz · Scheduled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'owner inventory retains safe state and disables pairing offline',
    (tester) async {
      final gateway = FakeGameOperationsGateway();
      await _pump(tester, gateway: gateway, initialLocation: '/my-tvs');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyTvsScreen)),
      );
      gateway.displayFailure = const GameOperationsFailure(
        GameOperationsFailureKind.unavailable,
      );

      await container.read(displayInventoryControllerProvider.notifier).load();
      await tester.pumpAndSettle();

      expect(find.text('Living room TV'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('my-tvs-retained-warning')),
        findsOneWidget,
      );
      final pair = tester.widget<AfriButton>(
        find.byKey(const ValueKey<String>('my-tvs-pair')),
      );
      expect(pair.enabled, isFalse);
    },
  );

  testWidgets('owner inventory renders empty and denied states safely', (
    tester,
  ) async {
    final emptyGateway = FakeGameOperationsGateway()
      ..displayInventory = OwnedDisplayInventory(
        clubId: '24',
        serverTime: DateTime.utc(2026, 7, 30, 10),
        displays: const <OwnedDisplay>[],
      );
    await _pump(tester, gateway: emptyGateway, initialLocation: '/my-tvs');
    expect(find.text('No paired TVs'), findsOneWidget);

    final deniedGateway = FakeGameOperationsGateway()
      ..displayFailure = const GameOperationsFailure(
        GameOperationsFailureKind.permissionDenied,
      );
    await _pump(tester, gateway: deniedGateway, initialLocation: '/my-tvs');
    expect(find.text('Game operations access denied'), findsOneWidget);
    final pair = tester.widget<AfriButton>(
      find.byKey(const ValueKey<String>('my-tvs-pair')),
    );
    expect(pair.enabled, isFalse);
  });

  testWidgets('owner inventory operational data matches governed golden', (
    tester,
  ) async {
    await _pump(
      tester,
      gateway: FakeGameOperationsGateway(),
      initialLocation: '/my-tvs',
    );
    await tester.ensureVisible(find.text('Saturday club quiz · Scheduled'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/game_operations_owner_inventory_dark_390x844.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kinyarwanda managed inventory uses the RW catalog', (
    tester,
  ) async {
    await _pump(
      tester,
      gateway: FakeGameOperationsGateway(),
      initialLocation: '/game-operations/sessions',
      locale: const Locale('rw'),
    );

    expect(find.text('Imikino ncunga'), findsOneWidget);
    expect(find.text('Saturday club quiz'), findsOneWidget);
    expect(find.text('TEGURA UMUKINO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pairing deep link pre-fills challenge and claims once', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway();
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/my-tvs/pair?challenge=a1b2c3d4',
    );

    final challenge = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('pair-tv-challenge')),
        matching: find.byType(TextField),
      ),
    );
    expect(challenge.controller?.text, 'A1B2C3D4');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey<String>('pair-tv-name')),
        matching: find.byType(TextField),
      ),
      'Kitchen TV',
    );
    await tester.pump();
    final pairingContainer = ProviderScope.containerOf(
      tester.element(find.byType(PairTvScreen)),
    );
    expect(
      pairingContainer.read(displayInventoryControllerProvider).status,
      GameOperationsLoadStatus.ready,
    );
    expect(
      pairingContainer
          .read(displayInventoryControllerProvider)
          .canStartPairingOperation,
      isTrue,
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('pair-tv-name')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      'Kitchen TV',
    );
    expect(
      tester
          .widget<AfriButton>(
            find.byKey(const ValueKey<String>('pair-tv-submit')),
          )
          .enabled,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey<String>('pair-tv-submit')));
    await tester.pumpAndSettle();

    expect(gateway.claims, 1);
    expect(find.text('My TVs'), findsOneWidget);
  });

  testWidgets('new pairing uses named authorized scope without raw venue ID', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway();
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/my-tvs/pair?challenge=a1b2c3d4',
    );

    expect(find.text('Authorized location'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('99000000-0000-4000-8000-000000000081'), findsNothing);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Club House').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey<String>('pair-tv-name')),
        matching: find.byType(TextField),
      ),
      'Club bar TV',
    );
    await tester.pump();
    expect(
      tester
          .widget<AfriButton>(
            find.byKey(const ValueKey<String>('pair-tv-submit')),
          )
          .enabled,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey<String>('pair-tv-submit')));
    await tester.pumpAndSettle();

    expect(gateway.claims, 1);
    expect(find.text('My TVs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner rename and move require confirmation and named scope', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway();
    await _pump(tester, gateway: gateway, initialLocation: '/my-tvs/display-1');

    expect(find.text('Club House'), findsNothing);
    expect(find.text('99000000-0000-4000-8000-000000000081'), findsNothing);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey<String>('tv-detail-name')),
        matching: find.byType(TextField),
      ),
      'Main lounge TV',
    );
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Club House').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('tv-detail-save')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('tv-detail-save')));
    await tester.pumpAndSettle();

    expect(gateway.updates, 0);
    expect(
      find.byKey(const ValueKey<String>('tv-detail-save-confirm')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('tv-detail-save-confirm')),
    );
    await tester.pumpAndSettle();

    expect(gateway.updates, 1);
    expect(gateway.updatedDisplayNames.single, 'Main lounge TV');
    expect(gateway.updatedScopeTypes.single, 'venue');
    expect(
      gateway.updatedVenueIds.single,
      '99000000-0000-4000-8000-000000000081',
    );
  });

  testWidgets('owner recovery rotates through confirmed TV bootstrap code', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway();
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/my-tvs/pair?recoverDisplayId=display-1',
    );

    expect(find.text('Recover a TV'), findsOneWidget);
    expect(find.text('RECOVER TV'), findsOneWidget);
    expect(find.text('Living room TV'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pair-tv-name')), findsNothing);
    expect(find.byKey(const ValueKey<String>('pair-tv-scope')), findsNothing);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey<String>('pair-tv-challenge')),
        matching: find.byType(TextField),
      ),
      'd4c3b2a1',
    );
    await tester.pump();
    expect(
      tester
          .widget<AfriButton>(
            find.byKey(const ValueKey<String>('pair-tv-submit')),
          )
          .enabled,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey<String>('pair-tv-submit')));
    await tester.pumpAndSettle();

    expect(gateway.recoveries, 0);
    expect(
      find.byKey(const ValueKey<String>('recover-tv-confirm')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('recover-tv-confirm')));
    await tester.pumpAndSettle();

    expect(gateway.recoveries, 1);
    expect(gateway.recoveryChallenges.single, 'D4C3B2A1');
    expect(find.text('My TVs'), findsOneWidget);
  });

  testWidgets('owner revocation requires confirmation and executes once', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway();
    await _pump(tester, gateway: gateway, initialLocation: '/my-tvs/display-1');

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('tv-detail-revoke')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('tv-detail-revoke')));
    await tester.pumpAndSettle();
    expect(gateway.revocations, 0);
    expect(
      find.byKey(const ValueKey<String>('tv-detail-revoke-confirm')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('tv-detail-revoke-confirm')),
    );
    await tester.pumpAndSettle();

    expect(gateway.revocations, 1);
    expect(find.text('My TVs'), findsOneWidget);
  });

  testWidgets('owner management matches governed dark 390 by 844 golden', (
    tester,
  ) async {
    await _pump(
      tester,
      gateway: FakeGameOperationsGateway(),
      initialLocation: '/my-tvs/display-1',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('tv-detail-revoke')),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/game_operations_owner_management_dark_390x844.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live control submits only a visible allowed transition', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway();
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/game-operations/sessions/session-1',
    );

    expect(find.text('OPEN LOBBY'), findsOneWidget);
    expect(find.text('Reveal answer'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('control-next-activated_lobby')),
    );
    await tester.pumpAndSettle();

    expect(gateway.transitions, 1);
    expect(find.text('Lobby open'), findsOneWidget);
  });

  testWidgets('live control separates one next action from exceptions', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway()
      ..managedGame = testQuestionOpenManagedGame;
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/game-operations/sessions/session-1',
    );

    expect(
      find.byKey(const ValueKey<String>('control-next-reveal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('control-exception-skip_question')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('control-exception-paused')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('control-exception-end_early')),
      findsOneWidget,
    );
    expect(gateway.transitions, 0);
  });

  testWidgets('guarded live controls match governed dark 390 by 844 golden', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway()
      ..managedGame = testQuestionOpenManagedGame;
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/game-operations/sessions/session-1',
    );

    final endEarly = find.byKey(
      const ValueKey<String>('control-exception-end_early'),
    );
    await tester.ensureVisible(endEarly);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/game_operations_guarded_live_controls_dark_390x844.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live refresh retains context but disables organizer actions', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway();
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/game-operations/sessions/session-1',
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LiveGameControlScreen)),
    );

    gateway.managedGameFetchCompleter = Completer<ManagedGameSession>();
    final refresh = container
        .read(liveGameControlControllerProvider('session-1').notifier)
        .load();
    await tester.pump();

    expect(find.text('Saturday club quiz'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('control-syncing-warning')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AfriButton>(
            find.byKey(const ValueKey<String>('control-next-activated_lobby')),
          )
          .enabled,
      isFalse,
    );

    gateway.managedGameFetchCompleter!.complete(testManagedGame);
    await refresh;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AfriButton>(
            find.byKey(const ValueKey<String>('control-next-activated_lobby')),
          )
          .enabled,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'live offline refresh keeps safe context locked until explicit recovery',
    (tester) async {
      final gateway = FakeGameOperationsGateway();
      await _pump(
        tester,
        gateway: gateway,
        initialLocation: '/game-operations/sessions/session-1',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LiveGameControlScreen)),
      );
      gateway.managedFailure = const GameOperationsFailure(
        GameOperationsFailureKind.offline,
      );

      await container
          .read(liveGameControlControllerProvider('session-1').notifier)
          .load();
      await tester.pumpAndSettle();

      expect(find.text('Saturday club quiz'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('control-failure-warning')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AfriButton>(
              find.byKey(
                const ValueKey<String>('control-next-activated_lobby'),
              ),
            )
            .enabled,
        isFalse,
      );

      gateway.managedFailure = null;
      await tester.tap(
        find.byKey(const ValueKey<String>('control-refresh-after-failure')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AfriButton>(
              find.byKey(
                const ValueKey<String>('control-next-activated_lobby'),
              ),
            )
            .enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('live permission denial removes retained session content', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway();
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/game-operations/sessions/session-1',
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LiveGameControlScreen)),
    );
    gateway.managedFailure = const GameOperationsFailure(
      GameOperationsFailureKind.permissionDenied,
    );

    await container
        .read(liveGameControlControllerProvider('session-1').notifier)
        .load();
    await tester.pumpAndSettle();

    expect(find.text('Game operations access denied'), findsOneWidget);
    expect(find.text('Saturday club quiz'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('control-next-activated_lobby')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live control reflows at 200 percent text on a compact phone', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway()
      ..managedGame = testQuestionOpenManagedGame;
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/game-operations/sessions/session-1',
      textScale: 2,
      size: const Size(320, 760),
    );

    expect(find.text('Saturday club quiz'), findsOneWidget);
    expect(find.text('Current question'), findsOneWidget);
    expect(find.text('Who scored the opening goal?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live skip requires a bounded reason and uses skip RPC', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway()
      ..managedGame = testQuestionOpenManagedGame;
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/game-operations/sessions/session-1',
    );

    final skip = find.byKey(
      const ValueKey<String>('control-exception-skip_question'),
    );
    await tester.ensureVisible(skip);
    await tester.tap(skip);
    await tester.pumpAndSettle();

    final reason = find.descendant(
      of: find.byKey(const ValueKey<String>('control-exception-reason')),
      matching: find.byType(TextField),
    );
    await tester.enterText(reason, 'Question withdrawn by the organizer');
    await tester.tap(
      find.byKey(const ValueKey<String>('control-exception-confirm')),
    );
    await tester.pumpAndSettle();

    expect(gateway.skips, 1);
    expect(gateway.transitions, 0);
    expect(gateway.skippedToQuestionIds.single, 'session-question-2');
  });

  testWidgets('paused live control exposes resume only as an exception', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway()
      ..managedGame = ManagedGameSession(
        clubId: testQuestionOpenManagedGame.clubId,
        id: testQuestionOpenManagedGame.id,
        title: testQuestionOpenManagedGame.title,
        packTitle: testQuestionOpenManagedGame.packTitle,
        phase: 'paused',
        sessionVersion: 9,
        questionVersion: testQuestionOpenManagedGame.questionVersion,
        eventSequence: 11,
        serverTime: testQuestionOpenManagedGame.serverTime,
        scheduledStartAt: testQuestionOpenManagedGame.scheduledStartAt,
        eligibilityScope: testQuestionOpenManagedGame.eligibilityScope,
        allowedActions: const <String>[
          'question_open',
          'completed',
          'cancelled',
        ],
        participantCount: testQuestionOpenManagedGame.participantCount,
        assignedDisplays: testQuestionOpenManagedGame.assignedDisplays,
        questionControls: testQuestionOpenManagedGame.questionControls,
        currentQuestion: testQuestionOpenManagedGame.currentQuestion,
      );
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/game-operations/sessions/session-1',
    );

    expect(
      find.byKey(const ValueKey<String>('control-next-question_open')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('control-exception-resume')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('control-exception-end_early')),
      findsOneWidget,
    );
  });

  testWidgets('organizer access denial renders a fail-closed state', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway()
      ..managedFailure = const GameOperationsFailure(
        GameOperationsFailureKind.permissionDenied,
      );
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/game-operations/sessions',
    );

    expect(find.text('Game operations access denied'), findsOneWidget);
    expect(find.text('PLAN A GAME'), findsNothing);
  });

  testWidgets(
    'organizer plans invitation-only game with an approved pack and Fan ID',
    (tester) async {
      final gateway = FakeGameOperationsGateway();
      await _pump(
        tester,
        gateway: gateway,
        initialLocation: '/game-operations/sessions/new',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('planner-eligibility')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invited supporters only').last);
      await tester.pumpAndSettle();

      final invitee = find.byKey(
        const ValueKey<String>('planner-invitee-supporter-1'),
      );
      await tester.ensureVisible(invitee);
      await tester.tap(invitee);
      await tester.pumpAndSettle();

      final create = find.byKey(const ValueKey<String>('planner-create'));
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();

      expect(gateway.creations, 1);
      expect(gateway.createInviteeUserIds.single, const <String>[
        'supporter-1',
      ]);
      expect(find.text('Live game control'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'organizer creates and assigns a claimed home TV in one planner journey',
    (tester) async {
      final gateway = FakeGameOperationsGateway();
      await _pump(
        tester,
        gateway: gateway,
        initialLocation: '/game-operations/sessions/new',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('planner-eligibility')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Owners of assigned home TVs').last);
      await tester.pumpAndSettle();

      final display = find.byKey(
        const ValueKey<String>('planner-display-display-1'),
      );
      await tester.ensureVisible(display);
      await tester.tap(display);
      await tester.pumpAndSettle();

      final create = find.byKey(const ValueKey<String>('planner-create'));
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();

      expect(gateway.creations, 1);
      expect(gateway.createDisplayIds.single, const <String>['display-1']);
      expect(find.text('Live game control'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'organizer invitation planner selected state matches governed golden',
    (tester) async {
      await _pump(
        tester,
        gateway: FakeGameOperationsGateway(),
        initialLocation: '/game-operations/sessions/new',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('planner-eligibility')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invited supporters only').last);
      await tester.pumpAndSettle();

      final invitee = find.byKey(
        const ValueKey<String>('planner-invitee-supporter-1'),
      );
      await tester.ensureVisible(invitee);
      await tester.tap(invitee);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('planner-create')),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/game_operations_planner_invitation_selected_dark_390x844.png',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'planner retains options but disables every action while refreshing',
    (tester) async {
      final gateway = FakeGameOperationsGateway();
      await _pump(
        tester,
        gateway: gateway,
        initialLocation: '/game-operations/sessions/new',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SessionPlannerScreen)),
      );

      gateway.plannerFetchCompleter = Completer<GamePlannerOptions>();
      final refresh = container
          .read(sessionPlannerControllerProvider.notifier)
          .load();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('planner-syncing-warning')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AfriDropdownField<String>>(
              find.byKey(const ValueKey<String>('planner-pack')),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<AfriButton>(
              find.byKey(const ValueKey<String>('planner-schedule')),
            )
            .enabled,
        isFalse,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('planner-create')),
      );
      expect(
        tester
            .widget<AfriButton>(
              find.byKey(const ValueKey<String>('planner-create')),
            )
            .enabled,
        isFalse,
      );

      gateway.plannerFetchCompleter!.complete(testPlannerOptions);
      await refresh;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AfriDropdownField<String>>(
              find.byKey(const ValueKey<String>('planner-pack')),
            )
            .enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'planner conflict keeps safe context locked until explicit refresh',
    (tester) async {
      final gateway = FakeGameOperationsGateway()
        ..nextMutationError = const GameOperationsFailure(
          GameOperationsFailureKind.conflict,
        );
      await _pump(
        tester,
        gateway: gateway,
        initialLocation: '/game-operations/sessions/new',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SessionPlannerScreen)),
      );
      final controller = container.read(
        sessionPlannerControllerProvider.notifier,
      );

      expect(
        await controller.create(
          packId: 'pack-1',
          scheduledStartAt: DateTime.utc(2026, 8, 1, 20, 12),
          eligibilityScope: 'club_membership',
          displayIds: const <String>[],
          inviteeUserIds: const <String>[],
        ),
        isFalse,
      );
      await tester.pumpAndSettle();

      expect(find.text('Approved club quiz'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('planner-refresh-after-timeout')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AfriButton>(
              find.byKey(const ValueKey<String>('planner-create')),
            )
            .enabled,
        isFalse,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('planner-refresh-after-timeout')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AfriButton>(
              find.byKey(const ValueKey<String>('planner-create')),
            )
            .enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('planner access denial removes retained organizer data', (
    tester,
  ) async {
    final gateway = FakeGameOperationsGateway();
    await _pump(
      tester,
      gateway: gateway,
      initialLocation: '/game-operations/sessions/new',
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SessionPlannerScreen)),
    );
    gateway.managedFailure = const GameOperationsFailure(
      GameOperationsFailureKind.permissionDenied,
    );

    await container.read(sessionPlannerControllerProvider.notifier).load();
    await tester.pumpAndSettle();

    expect(find.text('Game operations access denied'), findsOneWidget);
    expect(find.text('Approved club quiz'), findsNothing);
    expect(find.byKey(const ValueKey<String>('planner-create')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timed-out TV mutation disables repetition until explicit refresh',
    (tester) async {
      final gateway = FakeGameOperationsGateway()
        ..nextMutationError = const GameOperationsFailure(
          GameOperationsFailureKind.timeout,
        );
      await _pump(
        tester,
        gateway: gateway,
        initialLocation: '/my-tvs/pair?challenge=a1b2c3d4',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('pair-tv-name')),
          matching: find.byType(TextField),
        ),
        'Kitchen TV',
      );
      await tester.pump();
      expect(
        tester
            .widget<AfriButton>(
              find.byKey(const ValueKey<String>('pair-tv-submit')),
            )
            .enabled,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey<String>('pair-tv-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Game operation not confirmed'), findsNothing);
      expect(
        find.text(
          'The operation took too long to confirm. Refresh the authoritative '
          'state before trying it again.',
        ),
        findsOneWidget,
      );
      final submit = tester.widget<AfriButton>(
        find.byKey(const ValueKey<String>('pair-tv-submit')),
      );
      expect(submit.enabled, isFalse);
      expect(gateway.claims, 1);

      await tester.tap(
        find.byKey(const ValueKey<String>('pair-tv-refresh-after-failure')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AfriButton>(
              find.byKey(const ValueKey<String>('pair-tv-submit')),
            )
            .enabled,
        isTrue,
      );
    },
  );

  for (final state in crossClientFixture.states) {
    testWidgets(
      'GAME-QA-02 organizer renders ${state.id} authoritative state',
      (tester) async {
        final session = _crossClientManagedGame(crossClientFixture, state);
        final gateway = FakeGameOperationsGateway()..managedGame = session;

        await _pump(
          tester,
          gateway: gateway,
          initialLocation:
              '/game-operations/sessions/${crossClientFixture.sessionId}',
        );

        expect(find.text(state.organizerRenderText), findsOneWidget);
        expect(session.sessionVersion, state.sessionVersion);
        expect(session.questionVersion, state.questionVersion);
        expect(session.eventSequence, state.eventSequence);
        if (state.questionPrompt != null) {
          expect(find.text(state.questionPrompt!), findsOneWidget);
        }
        expect(find.textContaining('Correct answer'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

ManagedGameSession _crossClientManagedGame(
  _CrossClientFixture fixture,
  _CrossClientState state,
) {
  return ManagedGameSession(
    clubId: '24',
    id: fixture.sessionId,
    title: fixture.sessionTitle,
    packTitle: 'Approved matchday pack',
    phase: state.phase,
    sessionVersion: state.sessionVersion,
    questionVersion: state.questionVersion,
    eventSequence: state.eventSequence,
    serverTime: DateTime.utc(2026, 8, 1, 14, 0, state.eventSequence),
    phaseDeadline: state.phase == 'question_open'
        ? DateTime.utc(2026, 8, 1, 14, 0, 30)
        : null,
    scheduledStartAt: DateTime.utc(2026, 8, 1, 14),
    eligibilityScope: 'club_membership',
    allowedActions: const <String>[],
    participantCount: 18,
    assignedDisplays: const <ManagedDisplaySummary>[
      ManagedDisplaySummary(
        id: 'display-1',
        name: 'Main stand screen',
        scopeType: 'venue',
        pairingStatus: 'paired',
        health: 'online',
      ),
    ],
    currentQuestion: state.questionPrompt == null
        ? null
        : ManagedQuestionControl(
            id: 'question-${state.questionOrdinal}',
            ordinal: state.questionOrdinal!,
            state: state.phase,
            prompt: state.questionPrompt!,
            options: const <Map<String, dynamic>>[
              <String, dynamic>{'key': 'a', 'label': 'Player A'},
              <String, dynamic>{'key': 'b', 'label': '1968'},
            ],
          ),
  );
}

_CrossClientFixture _loadCrossClientFixture() {
  final json =
      jsonDecode(_findCrossClientFixture().readAsStringSync())
          as Map<String, dynamic>;
  return _CrossClientFixture(
    sessionId: json['session_id']! as String,
    sessionTitle: json['session_title']! as String,
    states: (json['states']! as List<dynamic>)
        .map(
          (value) => _CrossClientState.fromJson(value as Map<String, dynamic>),
        )
        .toList(growable: false),
  );
}

File _findCrossClientFixture() {
  var directory = Directory.current.absolute;
  while (true) {
    final candidate = File(
      '${directory.path}/docs/architecture/'
      'live-games-v2-cross-client-fixtures.json',
    );
    if (candidate.existsSync()) return candidate;
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Unable to locate the GAME-QA-02 fixture.');
    }
    directory = parent;
  }
}

class _CrossClientFixture {
  const _CrossClientFixture({
    required this.sessionId,
    required this.sessionTitle,
    required this.states,
  });

  final String sessionId;
  final String sessionTitle;
  final List<_CrossClientState> states;
}

class _CrossClientState {
  const _CrossClientState({
    required this.id,
    required this.phase,
    required this.sessionVersion,
    required this.questionVersion,
    required this.eventSequence,
    required this.questionOrdinal,
    required this.questionPrompt,
    required this.organizerRenderText,
  });

  factory _CrossClientState.fromJson(Map<String, dynamic> json) {
    return _CrossClientState(
      id: json['id']! as String,
      phase: json['phase']! as String,
      sessionVersion: json['session_version']! as int,
      questionVersion: json['question_version']! as int,
      eventSequence: json['event_sequence']! as int,
      questionOrdinal: json['question_ordinal'] as int?,
      questionPrompt: json['question_prompt'] as String?,
      organizerRenderText: json['organizer_render_text']! as String,
    );
  }

  final String id;
  final String phase;
  final int sessionVersion;
  final int questionVersion;
  final int eventSequence;
  final int? questionOrdinal;
  final String? questionPrompt;
  final String organizerRenderText;
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeGameOperationsGateway gateway,
  required String initialLocation,
  Locale locale = const Locale('en'),
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/my-tvs',
        builder: (_, _) => const MyTvsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'pair',
            builder: (_, state) => PairTvScreen(
              initialChallenge: state.uri.queryParameters['challenge'],
              recoverDisplayId: state.uri.queryParameters['recoverDisplayId'],
            ),
          ),
          GoRoute(
            path: ':displayId',
            builder: (_, state) => TvDetailScreen(
              displayId: state.pathParameters['displayId'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/game-operations/sessions',
        builder: (_, _) => const ManagedGamesScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'new',
            builder: (_, _) =>
                SessionPlannerScreen(now: () => DateTime(2026, 8, 1, 19, 12)),
          ),
          GoRoute(
            path: ':sessionId',
            builder: (_, state) => LiveGameControlScreen(
              sessionId: state.pathParameters['sessionId'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/game-operations',
        builder: (_, _) => const GameOperationsHubScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        gameOperationsGatewayProvider.overrideWithValue(gateway),
      ],
      child: ClubConfigScope(
        config: ClubConfig.fallback(),
        child: MaterialApp.router(
          builder: (context, child) => AfriLocalizationsScope(
            locale: locale,
            child: child ?? const SizedBox.shrink(),
          ),
          theme: ClubTheme.from(ClubConfig.fallback()),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
