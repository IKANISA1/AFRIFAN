import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/controllers/share_card_controller.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test(
    'loads confirmed prediction history and selects the first item',
    () async {
      final gateway = _Gateway();
      final controller = ShareCardController(gateway, autoLoad: false);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.value!.history, _history);
      expect(controller.state.value!.selectedId, 'prediction-1');
      expect(controller.state.value!.phase, ShareCardPhase.ready);
      expect(gateway.loadCalls, 1);
    },
  );

  test('fails offline before prediction-history gateway access', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway();
    final controller = ShareCardController(gateway, autoLoad: false);
    addTearDown(controller.dispose);

    await controller.load();

    expect(gateway.loadCalls, 0);
    expect(
      (controller.state.error as ShareCardFailure).kind,
      ShareCardFailureKind.offline,
    );
  });

  test('maps authorization failures without raw details', () async {
    final gateway = _Gateway()
      ..loadError = StateError('row-level security denied member-secret-8');
    final controller = ShareCardController(gateway, autoLoad: false);
    addTearDown(controller.dispose);

    await controller.load();

    final failure = controller.state.error as ShareCardFailure;
    expect(failure.kind, ShareCardFailureKind.permissionDenied);
    expect(failure.toString(), isNot(contains('member-secret-8')));
  });

  test('coalesces overlapping history refreshes', () async {
    final pending = Completer<List<UserPrediction>>();
    final gateway = _Gateway()..loadCompleter = pending;
    final controller = ShareCardController(gateway, autoLoad: false);
    addTearDown(controller.dispose);

    final first = controller.load();
    final second = controller.refresh();
    pending.complete(_history);
    await Future.wait([first, second]);

    expect(gateway.loadCalls, 1);
  });

  test('retains a valid selection across authoritative refresh', () async {
    final gateway = _Gateway();
    final controller = ShareCardController(gateway, autoLoad: false);
    addTearDown(controller.dispose);
    await controller.load();
    controller.select('prediction-2');

    await controller.refresh();

    expect(controller.state.value!.selectedId, 'prediction-2');
    expect(gateway.loadCalls, 2);
  });

  test('shares exactly the selected confirmed prediction', () async {
    final gateway = _Gateway();
    final controller = ShareCardController(gateway, autoLoad: false);
    addTearDown(controller.dispose);
    await controller.load();
    controller.select('prediction-2');

    final outcome = await controller.share();

    expect(outcome.isSuccess, isTrue);
    expect(gateway.sharedIds, ['prediction-2']);
    expect(controller.state.value!.mutation, ShareCardMutation.idle);
    expect(controller.state.value!.failure, isNull);
  });

  test(
    'uncertain platform timeout blocks repetition until acknowledged',
    () async {
      final gateway = _Gateway()..shareCompleter = Completer<void>();
      final controller = ShareCardController(
        gateway,
        actionTimeout: const Duration(milliseconds: 1),
        autoLoad: false,
      );
      addTearDown(controller.dispose);
      await controller.load();

      final first = await controller.share();
      final repeated = await controller.share();

      expect(first.failure?.kind, ShareCardFailureKind.securityTimeout);
      expect(repeated.failure?.kind, ShareCardFailureKind.conflict);
      expect(controller.state.value!.uncertainMutation, isTrue);
      expect(gateway.sharedIds, ['prediction-1']);

      controller.acknowledgeActionFailure();
      expect(controller.state.value!.actionsBlocked, isFalse);
    },
  );
}

const _history = <UserPrediction>[
  UserPrediction(
    id: 'prediction-1',
    fixtureId: 'fixture-1',
    marketSlug: '1x2',
    marketName: 'Match Result',
    marketGroup: MarketGroup.matchResult,
    homeTeam: 'Rayon Sports',
    homeTeamShort: 'RAY',
    awayTeam: 'APR FC',
    awayTeamShort: 'APR',
    kickoffAt: null,
    fixtureStatus: 'finished',
    competitionName: 'Rwanda Premier League',
    selectedOutcome: 'Rayon Sports',
    status: PredictionStatus.won,
    fetPotential: 100,
    fetEarned: 100,
    placedAt: null,
  ),
  UserPrediction(
    id: 'prediction-2',
    fixtureId: 'fixture-2',
    marketSlug: 'goals',
    marketName: 'Total Goals',
    marketGroup: MarketGroup.goals,
    homeTeam: 'Police FC',
    homeTeamShort: 'POL',
    awayTeam: 'Rayon Sports',
    awayTeamShort: 'RAY',
    kickoffAt: null,
    fixtureStatus: 'scheduled',
    competitionName: 'Rwanda Premier League',
    selectedOutcome: 'Over 2.5',
    status: PredictionStatus.pending,
    fetPotential: 140,
    fetEarned: 0,
    placedAt: null,
  ),
];

class _Gateway implements ShareCardGateway {
  List<UserPrediction> history = _history;
  Object? loadError;
  Completer<List<UserPrediction>>? loadCompleter;
  Completer<void>? shareCompleter;
  int loadCalls = 0;
  final List<String> sharedIds = <String>[];
  final List<String> copiedIds = <String>[];

  @override
  Future<List<UserPrediction>> loadHistory({required int limit}) async {
    loadCalls += 1;
    if (loadError != null) throw loadError!;
    if (loadCompleter != null) return loadCompleter!.future;
    return history;
  }

  @override
  Future<void> share(UserPrediction prediction) async {
    sharedIds.add(prediction.id);
    if (shareCompleter != null) return shareCompleter!.future;
  }

  @override
  Future<void> copy(UserPrediction prediction) async {
    copiedIds.add(prediction.id);
  }
}
