import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/models/partner_pool_models.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/providers/match_detail_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements MatchDetailGateway {
  FixtureSummary? fixture = _fixture();
  PredictionMatchCenter? matchCenter;
  List<PartnerPredictionPool> pools = <PartnerPredictionPool>[_pool()];
  Object? loadError;
  PartnerPoolMutationResult joinResult = const PartnerPoolMutationResult(
    status: 'success',
  );
  Completer<PartnerPoolMutationResult>? joinCompleter;
  int loadFixtureCalls = 0;
  int joinCalls = 0;

  @override
  Future<PartnerPoolMutationResult> joinPool({
    required String poolId,
    required PartnerPoolOutcome selectedOutcome,
    required String idempotencyKey,
  }) {
    joinCalls++;
    return joinCompleter?.future ?? Future.value(joinResult);
  }

  @override
  Future<FixtureSummary?> loadFixture(String fixtureId) async {
    loadFixtureCalls++;
    if (loadError case final error?) throw error;
    return fixture;
  }

  @override
  Future<PredictionMatchCenter?> loadMatchCenter(String fixtureId) async {
    if (loadError case final error?) throw error;
    return matchCenter;
  }

  @override
  Future<List<PartnerPredictionPool>> loadPools() async {
    if (loadError case final error?) throw error;
    return pools;
  }
}

FixtureSummary _fixture() {
  return FixtureSummary(
    id: 'fixture-1',
    competitionSlug: 'rpl',
    competitionName: 'Rwanda Premier League',
    seasonLabel: '2026/27',
    matchday: 2,
    homeTeamSlug: 'rayon-sports',
    homeTeamName: 'Rayon Sports Football Club',
    homeTeamShort: 'RAY',
    awayTeamSlug: 'apr',
    awayTeamName: 'APR Football Club',
    awayTeamShort: 'APR',
    kickoffAt: DateTime.utc(2026, 8, 2, 15),
    venueName: 'Amahoro Stadium',
    status: 'scheduled',
  );
}

PartnerPredictionPool _pool({
  String status = 'open',
  PartnerPoolEntry? viewerEntry,
}) {
  return PartnerPredictionPool(
    id: 'pool-1',
    clubId: 24,
    partnerId: 'partner-1',
    partnerName: 'Visit Rwanda',
    partnerSlug: 'visit-rwanda',
    fixtureId: 'fixture-1',
    title: 'Derby WDW Pool',
    partnerStakeFet: 5000,
    fanEntryFet: 100,
    eligibilityMode: 'open_to_all',
    status: status,
    lockAt: DateTime.utc(2026, 8, 2, 15),
    totalEntries: 12,
    totalFanEntryFet: 1200,
    viewerEntry: viewerEntry,
  );
}

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test(
    'loads fixture and filters partner pools to the route fixture',
    () async {
      final gateway = _Gateway()
        ..pools = <PartnerPredictionPool>[
          _pool(),
          const PartnerPredictionPool(
            id: 'pool-other',
            clubId: 24,
            partnerId: 'partner-2',
            partnerName: 'Other',
            partnerSlug: 'other',
            fixtureId: 'fixture-other',
            title: 'Other pool',
            partnerStakeFet: 1000,
            fanEntryFet: 50,
            eligibilityMode: 'open_to_all',
            status: 'open',
            lockAt: null,
            totalEntries: 0,
            totalFanEntryFet: 0,
          ),
        ];
      final controller = MatchDetailController(
        gateway,
        'fixture-1',
        autoLoad: false,
      );

      await controller.load();

      expect(controller.state.value!.fixture?.id, 'fixture-1');
      expect(controller.state.value!.partnerPools, hasLength(1));
      expect(controller.state.value!.partnerPools.single.id, 'pool-1');
    },
  );

  test('fails before repository access when offline', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway();
    final controller = MatchDetailController(
      gateway,
      'fixture-1',
      autoLoad: false,
    );

    await controller.load();

    expect(gateway.loadFixtureCalls, 0);
    expect(
      controller.state.error,
      const TypeMatcher<MatchDetailFailure>().having(
        (failure) => failure.kind,
        'kind',
        MatchDetailFailureKind.offline,
      ),
    );
  });

  test('retains confirmed match when refresh fails', () async {
    final gateway = _Gateway();
    final controller = MatchDetailController(
      gateway,
      'fixture-1',
      autoLoad: false,
    );
    await controller.load();
    gateway.loadError = StateError('conflict stale revision');

    await controller.refresh();

    final state = controller.state.value!;
    expect(state.fixture?.id, 'fixture-1');
    expect(state.phase, MatchDetailPhase.degraded);
    expect(state.failure?.kind, MatchDetailFailureKind.conflict);
    expect(state.actionsBlocked, isTrue);
  });

  test('coalesces concurrent refresh requests', () async {
    final gateway = _Gateway();
    final controller = MatchDetailController(
      gateway,
      'fixture-1',
      autoLoad: false,
    );

    final first = controller.refresh();
    final second = controller.refresh();
    await Future.wait(<Future<void>>[first, second]);

    expect(gateway.loadFixtureCalls, 1);
  });

  test('blocks pool join while offline and retains match', () async {
    final gateway = _Gateway();
    final controller = MatchDetailController(
      gateway,
      'fixture-1',
      autoLoad: false,
    );
    await controller.load();
    ConnectivityService.setOnlineForTest(false);

    final result = await controller.joinPool(
      pool: _pool(),
      selectedOutcome: PartnerPoolOutcome.homeWin,
    );

    expect(result.isSuccess, isFalse);
    expect(result.failure?.kind, MatchDetailFailureKind.offline);
    expect(gateway.joinCalls, 0);
    expect(controller.state.value!.fixture?.id, 'fixture-1');
  });

  test('blocks repeat join after an uncertain timeout until refresh', () async {
    final gateway = _Gateway()
      ..joinCompleter = Completer<PartnerPoolMutationResult>();
    final controller = MatchDetailController(
      gateway,
      'fixture-1',
      autoLoad: false,
      mutationTimeout: const Duration(milliseconds: 1),
    );
    await controller.load();

    final first = await controller.joinPool(
      pool: _pool(),
      selectedOutcome: PartnerPoolOutcome.draw,
    );
    final second = await controller.joinPool(
      pool: _pool(),
      selectedOutcome: PartnerPoolOutcome.draw,
    );

    expect(first.failure?.kind, MatchDetailFailureKind.securityTimeout);
    expect(second.failure?.kind, MatchDetailFailureKind.conflict);
    expect(gateway.joinCalls, 1);
    expect(controller.state.value!.actionsBlocked, isTrue);
  });

  test('successful join reloads confirmed server state', () async {
    final gateway = _Gateway();
    final controller = MatchDetailController(
      gateway,
      'fixture-1',
      autoLoad: false,
    );
    await controller.load();
    gateway.pools = <PartnerPredictionPool>[
      _pool(
        viewerEntry: PartnerPoolEntry(
          id: 'entry-1',
          selectedOutcome: PartnerPoolOutcome.awayWin,
          eligibilityStatus: 'eligible',
          status: 'active',
          payoutFet: 0,
          refundedFet: 0,
          joinedAt: DateTime.utc(2026, 7, 28, 11),
        ),
      ),
    ];

    final result = await controller.joinPool(
      pool: _pool(),
      selectedOutcome: PartnerPoolOutcome.awayWin,
    );

    expect(result.isSuccess, isTrue);
    expect(gateway.joinCalls, 1);
    expect(controller.state.value!.partnerPools.single.hasJoined, isTrue);
    expect(controller.state.value!.phase, MatchDetailPhase.ready);
  });
}
