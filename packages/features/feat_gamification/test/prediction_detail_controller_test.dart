import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/providers/prediction_detail_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePredictionDetailGateway implements PredictionDetailGateway {
  PredictionDetail? detail;
  PredictionDetail? detailAfterCancel;
  Object? loadError;
  Completer<PredictionDetail?>? loadCompleter;
  Completer<PredictionPlaceResult>? cancelCompleter;
  PredictionPlaceResult cancelResult = const PredictionPlaceResult(
    status: 'cancelled',
    message: 'Cancelled.',
  );
  int loadCalls = 0;
  int cancelCalls = 0;
  bool cancelled = false;

  @override
  Future<PredictionDetail?> load(String predictionId) async {
    loadCalls++;
    final pending = loadCompleter;
    if (pending != null) {
      loadCompleter = null;
      return pending.future;
    }
    if (loadError case final error?) throw error;
    if (cancelled && detailAfterCancel != null) return detailAfterCancel;
    return detail;
  }

  @override
  Future<PredictionPlaceResult> cancel(String predictionId) async {
    cancelCalls++;
    final pending = cancelCompleter;
    if (pending != null) return pending.future;
    cancelled = true;
    return cancelResult;
  }
}

PredictionDetail _detail({
  String id = 'prediction-1',
  PredictionStatus status = PredictionStatus.pending,
}) {
  return PredictionDetail(
    id: id,
    fixtureId: 'fixture-1',
    marketSlug: 'winner',
    marketName: 'Match winner',
    marketShortName: 'Winner',
    marketGroup: MarketGroup.matchResult,
    difficultyTier: DifficultyTier.mid,
    competitionName: 'Rwanda Premier League',
    homeTeam: 'Rayon Sports',
    homeTeamShort: 'RAY',
    awayTeam: 'APR FC',
    awayTeamShort: 'APR',
    selectedOutcome: 'Rayon Sports',
    status: status,
    fetPotential: 120,
    fetEarned: status == PredictionStatus.won ? 120 : 0,
    kickoffAt: DateTime.utc(2026, 7, 30, 18),
    placedAt: DateTime.utc(2026, 7, 28, 9),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('detail failures sanitize backend categories', () {
    expect(
      PredictionDetailFailure.fromError(
        StateError('RLS denied for supporter-991 private prediction row'),
      ).kind,
      PredictionDetailFailureKind.permissionDenied,
    );
    expect(
      PredictionDetailFailure.fromError(
        StateError('stale revision conflict for supporter-991'),
      ).kind,
      PredictionDetailFailureKind.conflict,
    );
    expect(
      PredictionDetailFailure.fromError(
        TimeoutException('private prediction token supporter-991'),
      ).kind,
      PredictionDetailFailureKind.securityTimeout,
    );
    expect(
      PredictionDetailFailure.fromError(
        StateError('private prediction token supporter-991'),
      ).toString(),
      'PredictionDetailFailure(unknown)',
    );
  });

  test('bounded detail load maps timeout to safe failure', () async {
    final gateway = _FakePredictionDetailGateway()
      ..loadCompleter = Completer<PredictionDetail?>();
    final controller = PredictionDetailController(
      gateway,
      'prediction-1',
      loadTimeout: const Duration(milliseconds: 1),
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    final failure = controller.state.error! as PredictionDetailFailure;
    expect(failure.kind, PredictionDetailFailureKind.securityTimeout);
    expect(failure.toString(), isNot(contains('supporter')));
    expect(gateway.loadCalls, 1);
  });

  test('offline detail load fails before gateway access', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _FakePredictionDetailGateway();
    final controller = PredictionDetailController(
      gateway,
      'prediction-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    final failure = controller.state.error! as PredictionDetailFailure;
    expect(failure.kind, PredictionDetailFailureKind.offline);
    expect(gateway.loadCalls, 0);
  });

  test('refresh retains confirmed detail after conflict', () async {
    final gateway = _FakePredictionDetailGateway()..detail = _detail();
    final controller = PredictionDetailController(
      gateway,
      'prediction-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);
    await controller.load();

    gateway.loadError = StateError('stale revision conflict for supporter-991');
    await controller.refresh();

    final retained = controller.state.value!;
    expect(retained.detail?.id, 'prediction-1');
    expect(retained.phase, PredictionDetailPhase.degraded);
    expect(retained.failure?.kind, PredictionDetailFailureKind.conflict);
  });

  test('parallel detail refreshes coalesce', () async {
    final gateway = _FakePredictionDetailGateway()..detail = _detail();
    final controller = PredictionDetailController(
      gateway,
      'prediction-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(gateway.loadCalls, 1);

    final pending = Completer<PredictionDetail?>();
    gateway.loadCompleter = pending;
    final first = controller.refresh();
    final second = controller.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(gateway.loadCalls, 2);
    pending.complete(_detail());
    await Future.wait<void>([first, second]);
    expect(gateway.loadCalls, 2);
  });

  test(
    'uncertain cancellation retains detail and blocks resubmission',
    () async {
      final gateway = _FakePredictionDetailGateway()
        ..detail = _detail()
        ..cancelCompleter = Completer<PredictionPlaceResult>();
      final controller = PredictionDetailController(
        gateway,
        'prediction-1',
        mutationTimeout: const Duration(milliseconds: 1),
        autoLoad: false,
      );
      addTearDown(controller.dispose);
      await controller.load();

      final outcome = await controller.cancel();
      final retained = controller.state.value!;
      expect(outcome.isSuccess, isFalse);
      expect(
        outcome.failure?.kind,
        PredictionDetailFailureKind.securityTimeout,
      );
      expect(retained.detail?.id, 'prediction-1');
      expect(retained.phase, PredictionDetailPhase.degraded);
      expect(retained.actionsBlocked, isTrue);
      expect(gateway.cancelCalls, 1);

      final repeated = await controller.cancel();
      expect(repeated.isSuccess, isFalse);
      expect(gateway.cancelCalls, 1);
    },
  );

  test(
    'successful cancellation refreshes and adopts confirmed status',
    () async {
      final gateway = _FakePredictionDetailGateway()
        ..detail = _detail()
        ..detailAfterCancel = _detail(status: PredictionStatus.cancelled);
      final controller = PredictionDetailController(
        gateway,
        'prediction-1',
        autoLoad: false,
      );
      addTearDown(controller.dispose);
      await controller.load();

      final outcome = await controller.cancel();

      expect(outcome.isSuccess, isTrue);
      expect(
        controller.state.value!.detail?.status,
        PredictionStatus.cancelled,
      );
      expect(gateway.cancelCalls, 1);
      expect(gateway.loadCalls, 2);
    },
  );
}
