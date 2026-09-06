import 'dart:async';
import 'package:feat_gamification/src/predict/predict_controller.dart';
import 'package:feat_gamification/src/predict/predict_models.dart';
import 'package:feat_gamification/src/predict/predict_repository.dart';
import 'package:flutter_test/flutter_test.dart';

PredictFixture fixture({PredictSelection? selection, DateTime? kickoff}) =>
    PredictFixture(
      id: 'fixture',
      poolId: 'pool',
      competitionId: 'league',
      competition: 'Rwanda Premier League',
      homeTeam: 'Home FC',
      awayTeam: 'Away FC',
      homeCrest: 'https://example.com/home.png',
      awayCrest: 'https://example.com/away.png',
      kickoffAt: kickoff ?? DateTime.utc(2030, 9, 17, 16, 30),
      locksAt: kickoff ?? DateTime.utc(2030, 9, 17, 16, 30),
      stakeFet: 100,
      selection: selection,
    );

class Gateway implements PredictGateway {
  PredictDashboard data = PredictDashboard(
    enabled: true,
    memberSession: true,
    balanceFet: 500,
    fixtures: [fixture()],
  );
  Object? failure;
  Completer<PredictConfirmation>? pending;
  int mutations = 0;
  @override
  Future<PredictDashboard> load() async {
    if (failure case final e?) throw e;
    return data;
  }

  @override
  Future<PredictConfirmation> place(
    String id,
    PredictSelection selection,
  ) async {
    mutations++;
    if (pending case final p?) return p.future;
    return PredictConfirmation(fixture(selection: selection), 400);
  }
}

void main() {
  test(
    'one pending mutation; timeout requires refresh before another choice',
    () async {
      final gateway = Gateway()..pending = Completer();
      final c = PredictController(
        gateway,
        autoLoad: false,
        timeout: const Duration(milliseconds: 10),
      );
      addTearDown(c.dispose);
      await c.refresh();
      final first = c.place(fixture(), PredictSelection.home);
      await c.place(fixture(), PredictSelection.away);
      expect(gateway.mutations, 1);
      await first;
      expect(c.state.failure, PredictFailure.uncertain);
      await c.place(fixture(), PredictSelection.home);
      expect(gateway.mutations, 1);
      gateway.data = PredictDashboard(
        enabled: true,
        memberSession: true,
        balanceFet: 400,
        fixtures: [fixture(selection: PredictSelection.home)],
      );
      await c.refresh();
      expect(
        c.state.dashboard!.fixtures.single.selection,
        PredictSelection.home,
      );
      expect(c.state.needsReconciliation, isFalse);
    },
  );
  test('guests and closed fixtures never submit', () async {
    final gateway = Gateway()
      ..data = PredictDashboard(enabled: true, fixtures: [fixture()]);
    final c = PredictController(gateway, autoLoad: false);
    addTearDown(c.dispose);
    await c.refresh();
    await c.place(fixture(), PredictSelection.draw);
    expect(c.state.failure, PredictFailure.signIn);
    expect(gateway.mutations, 0);
    gateway.data = PredictDashboard(
      enabled: true,
      memberSession: true,
      fixtures: [fixture(kickoff: DateTime.utc(2020))],
    );
    await c.refresh();
    await c.place(fixture(kickoff: DateTime.utc(2020)), PredictSelection.home);
    expect(c.state.failure, PredictFailure.closed);
    expect(gateway.mutations, 0);
  });
  test(
    'failed refresh preserves confirmed data and blocks actions; revoked session clears it',
    () async {
      final g = Gateway();
      final c = PredictController(g, autoLoad: false);
      addTearDown(c.dispose);
      await c.refresh();
      g.failure = PredictFailure.unavailable;
      await c.refresh();
      expect(c.state.dashboard!.balanceFet, 500);
      await c.place(fixture(), PredictSelection.draw);
      expect(g.mutations, 0);
      g.failure = PredictFailure.signIn;
      await c.refresh();
      expect(c.state.dashboard, isNull);
    },
  );
  test('confirmed entry survives a failed follow-up read', () async {
    final g = Gateway();
    final c = PredictController(g, autoLoad: false);
    addTearDown(c.dispose);
    await c.refresh();
    g.failure = PredictFailure.unavailable;
    await c.place(fixture(), PredictSelection.away);
    expect(c.state.dashboard!.fixtures.single.selection, PredictSelection.away);
    expect(c.state.dashboard!.balanceFet, 400);
    expect(c.state.needsReconciliation, isTrue);
  });
}
