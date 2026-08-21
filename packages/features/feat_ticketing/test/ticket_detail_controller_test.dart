import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_ticketing/src/providers/ticket_detail_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a confirmed fixture', () async {
    final gateway = _Gateway()..match = _match();
    final controller = TicketDetailController(
      gateway,
      'match-1',
      autoLoad: false,
    );

    await controller.load();

    expect(controller.state.value!.match?.id, 'match-1');
    expect(controller.state.value!.phase, TicketDetailPhase.ready);
  });

  test('represents a missing fixture as empty data', () async {
    final controller = TicketDetailController(
      _Gateway(),
      'missing',
      autoLoad: false,
    );

    await controller.load();

    expect(controller.state.value, isNotNull);
    expect(controller.state.value!.match, isNull);
  });

  test('fails before gateway access while offline', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway()..match = _match();
    final controller = TicketDetailController(
      gateway,
      'match-1',
      autoLoad: false,
    );

    await controller.load();

    expect(gateway.calls, 0);
    expect(
      (controller.state.error as TicketDetailFailure).kind,
      TicketDetailFailureKind.offline,
    );
  });

  test('maps a bounded load timeout to security timeout', () async {
    final gateway = _Gateway()..pending = Completer<ClubMatch?>();
    final controller = TicketDetailController(
      gateway,
      'match-1',
      autoLoad: false,
      loadTimeout: const Duration(milliseconds: 1),
    );

    await controller.load();

    expect(
      (controller.state.error as TicketDetailFailure).kind,
      TicketDetailFailureKind.securityTimeout,
    );
  });

  test('retains the confirmed fixture when refresh conflicts', () async {
    final gateway = _Gateway()..match = _match();
    final controller = TicketDetailController(
      gateway,
      'match-1',
      autoLoad: false,
    );
    await controller.load();
    gateway.error = StateError('revision conflict for private-fixture-row');

    await controller.refresh();

    expect(controller.state.value!.match?.id, 'match-1');
    expect(controller.state.value!.phase, TicketDetailPhase.degraded);
    expect(
      controller.state.value!.failure?.kind,
      TicketDetailFailureKind.conflict,
    );
  });

  test('coalesces overlapping refresh requests', () async {
    final gateway = _Gateway()..match = _match();
    final controller = TicketDetailController(
      gateway,
      'match-1',
      autoLoad: false,
    );
    await controller.load();
    gateway.pending = Completer<ClubMatch?>();

    final first = controller.refresh();
    final second = controller.refresh();
    gateway.pending!.complete(_match());
    await Future.wait([first, second]);

    expect(gateway.calls, 2);
  });

  test('permission failures map to a stable typed category', () async {
    final gateway = _Gateway()
      ..error = StateError('RLS denied private-fixture-row-4482');
    final controller = TicketDetailController(
      gateway,
      'match-1',
      autoLoad: false,
    );

    await controller.load();

    expect(
      (controller.state.error as TicketDetailFailure).kind,
      TicketDetailFailureKind.permissionDenied,
    );
    expect(controller.state.error.toString(), isNot(contains('4482')));
  });
}

class _Gateway implements TicketDetailGateway {
  ClubMatch? match;
  Object? error;
  Completer<ClubMatch?>? pending;
  int calls = 0;

  @override
  Future<ClubMatch?> load(String matchId) async {
    calls += 1;
    if (error case final failure?) throw failure;
    if (pending case final completer?) return completer.future;
    return match;
  }
}

ClubMatch _match() => ClubMatch(
  id: 'match-1',
  homeTeam: 'Rayon Sports',
  awayTeam: 'APR FC',
  competition: 'Rwanda Premier League',
  venue: 'Amahoro Stadium',
  matchDate: DateTime.utc(2026, 8, 2, 15),
  kickoffTime: '17:00',
  isOnSale: true,
  ticketGeneralPrice: 5000,
  ticketVipPrice: 15000,
  saleStartsAt: DateTime.utc(2026, 7, 20, 9),
  capacity: 45000,
);
