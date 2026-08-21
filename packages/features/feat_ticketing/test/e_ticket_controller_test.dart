import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_ticketing/src/providers/e_ticket_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a confirmed e-ticket', () async {
    final gateway = _Gateway()..ticket = _ticket();
    final controller = ETicketController(gateway, 'ticket-1', autoLoad: false);

    await controller.load();

    expect(controller.state.value!.ticket?.id, 'ticket-1');
    expect(controller.state.value!.phase, ETicketPhase.ready);
  });

  test('represents a missing e-ticket as empty data', () async {
    final controller = ETicketController(
      _Gateway(),
      'missing',
      autoLoad: false,
    );

    await controller.load();

    expect(controller.state.value, isNotNull);
    expect(controller.state.value!.ticket, isNull);
  });

  test('fails before gateway access while offline', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway()..ticket = _ticket();
    final controller = ETicketController(gateway, 'ticket-1', autoLoad: false);

    await controller.load();

    expect(gateway.calls, 0);
    expect(
      (controller.state.error as ETicketFailure).kind,
      ETicketFailureKind.offline,
    );
  });

  test('maps a bounded load timeout to security timeout', () async {
    final gateway = _Gateway()..pending = Completer<ClubTicket?>();
    final controller = ETicketController(
      gateway,
      'ticket-1',
      autoLoad: false,
      loadTimeout: const Duration(milliseconds: 1),
    );

    await controller.load();

    expect(
      (controller.state.error as ETicketFailure).kind,
      ETicketFailureKind.securityTimeout,
    );
  });

  test('retains the confirmed e-ticket when refresh conflicts', () async {
    final gateway = _Gateway()..ticket = _ticket();
    final controller = ETicketController(gateway, 'ticket-1', autoLoad: false);
    await controller.load();
    gateway.error = StateError('revision conflict for private-ticket-row');

    await controller.refresh();

    expect(controller.state.value!.ticket?.id, 'ticket-1');
    expect(controller.state.value!.phase, ETicketPhase.degraded);
    expect(controller.state.value!.failure?.kind, ETicketFailureKind.conflict);
  });

  test('coalesces overlapping refresh requests', () async {
    final gateway = _Gateway()..ticket = _ticket();
    final controller = ETicketController(gateway, 'ticket-1', autoLoad: false);
    await controller.load();
    gateway.pending = Completer<ClubTicket?>();

    final first = controller.refresh();
    final second = controller.refresh();
    gateway.pending!.complete(_ticket());
    await Future.wait([first, second]);

    expect(gateway.calls, 2);
  });

  test('permission failures map to a stable typed category', () async {
    final gateway = _Gateway()
      ..error = StateError('RLS denied private-ticket-row-4482');
    final controller = ETicketController(gateway, 'ticket-1', autoLoad: false);

    await controller.load();

    expect(
      (controller.state.error as ETicketFailure).kind,
      ETicketFailureKind.permissionDenied,
    );
    expect(controller.state.error.toString(), isNot(contains('4482')));
  });
}

class _Gateway implements ETicketGateway {
  ClubTicket? ticket;
  Object? error;
  Completer<ClubTicket?>? pending;
  int calls = 0;

  @override
  Future<ClubTicket?> load(String ticketId) async {
    calls += 1;
    if (error case final failure?) throw failure;
    if (pending case final completer?) return completer.future;
    return ticket;
  }
}

ClubTicket _ticket() => ClubTicket.fromJson({
  'id': 'ticket-1',
  'match_id': 'match-1',
  'user_id': 'user-1',
  'seat_type': 'vip',
  'amount_paid': 15000,
  'qr_code': 'AFRICLUB-TICKET-1',
  'momo_reference': 'not-rendered',
  'status': 'active',
  'purchased_at': '2026-07-28T09:00:00Z',
  'match': {
    'id': 'match-1',
    'home_team': 'Rayon Sports',
    'away_team': 'APR FC',
    'competition': 'Rwanda Premier League',
    'venue': 'Amahoro Stadium',
    'match_date': '2026-08-02T15:00:00Z',
    'kickoff_time': '17:00',
    'is_on_sale': true,
    'ticket_general_price': 5000,
    'ticket_vip_price': 15000,
    'sale_starts_at': '2026-07-20T09:00:00Z',
    'capacity': 45000,
  },
});
