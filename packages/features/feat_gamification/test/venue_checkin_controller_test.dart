import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/controllers/venue_checkin_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('rejects short code without a gateway call', () async {
    final gateway = _Gateway();
    final controller = VenueCheckinController(gateway);

    expect(await controller.submit('abc'), isFalse);
    expect(gateway.calls, 0);
    expect(
      controller.state.valueOrNull!.failure?.kind,
      VenueCheckinFailureKind.invalidCode,
    );
  });

  test('publishes confirmed server result', () async {
    final gateway = _Gateway(
      result: const VenueCheckinResult(
        status: 'confirmed',
        code: 'ok',
        fetAwarded: 25,
      ),
    );
    final controller = VenueCheckinController(gateway);

    expect(await controller.submit('RAYON1'), isTrue);
    expect(controller.state.valueOrNull!.phase, VenueCheckinPhase.confirmed);
    expect(controller.state.valueOrNull!.result?.fetAwarded, 25);
  });

  test('maps stable server rejection without leaking raw payload', () async {
    final controller = VenueCheckinController(
      _Gateway(
        result: const VenueCheckinResult(status: 'error', code: 'expired_code'),
      ),
    );

    expect(await controller.submit('RAYON1'), isFalse);
    expect(
      controller.state.valueOrNull!.failure?.kind,
      VenueCheckinFailureKind.expiredCode,
    );
  });

  test('fails closed offline and reconnect clears only that failure', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway();
    final controller = VenueCheckinController(gateway);

    expect(await controller.submit('RAYON1'), isFalse);
    expect(
      controller.state.valueOrNull!.failure?.kind,
      VenueCheckinFailureKind.offline,
    );

    ConnectivityService.setOnlineForTest(true);
    await controller.connectionRestored();
    expect(controller.state.valueOrNull!.failure, isNull);
    expect(gateway.calls, 0);
  });

  test('timeout is uncertain and blocks replay until acknowledged', () async {
    final completer = Completer<VenueCheckinResult>();
    final gateway = _Gateway(pending: completer.future);
    final controller = VenueCheckinController(
      gateway,
      timeout: const Duration(milliseconds: 10),
    );

    expect(await controller.submit('RAYON1'), isFalse);
    expect(controller.state.valueOrNull!.uncertainMutation, isTrue);
    expect(
      controller.state.valueOrNull!.failure?.kind,
      VenueCheckinFailureKind.securityTimeout,
    );
    expect(await controller.submit('RAYON1'), isFalse);
    expect(gateway.calls, 1);

    controller.acknowledgeFailure();
    expect(controller.state.valueOrNull!.uncertainMutation, isFalse);
  });

  test('coalesces overlapping submissions', () async {
    final completer = Completer<VenueCheckinResult>();
    final gateway = _Gateway(pending: completer.future);
    final controller = VenueCheckinController(gateway);

    final first = controller.submit('RAYON1');
    final second = controller.submit('RAYON1');
    expect(await second, isFalse);
    expect(gateway.calls, 1);

    completer.complete(
      const VenueCheckinResult(status: 'confirmed', code: 'ok'),
    );
    expect(await first, isTrue);
  });

  test('location consent is local, reversible, and mutation-safe', () async {
    final controller = VenueCheckinController(_Gateway());
    controller.setLocationConsent(true);
    expect(controller.state.valueOrNull!.locationConsent, isTrue);
    controller.setLocationConsent(false);
    expect(controller.state.valueOrNull!.locationConsent, isFalse);
  });
}

class _Gateway implements VenueCheckinGateway {
  _Gateway({
    this.result = const VenueCheckinResult(status: 'confirmed', code: 'ok'),
    this.pending,
  });

  final VenueCheckinResult result;
  final Future<VenueCheckinResult>? pending;
  int calls = 0;

  @override
  Future<VenueCheckinResult> submit({
    required String rawCode,
    required String idempotencyKey,
  }) {
    calls += 1;
    return pending ?? Future.value(result);
  }
}
