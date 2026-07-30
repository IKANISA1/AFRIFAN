import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_contributions/src/controllers/statement_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _groupId = 'initiative-statement-1';

StatementSnapshot _snapshot() {
  return StatementSnapshot(
    groupName: 'Away Day Travel Initiative',
    entries: <StatementEntry>[
      StatementEntry(
        publicAlias: '#BLUEARMY',
        amount: 10000,
        status: StatementEntryStatus.processing,
        createdAt: DateTime.utc(2026, 7, 17),
      ),
      StatementEntry(
        publicAlias: '#FAN2048',
        amount: 25000,
        status: StatementEntryStatus.confirmed,
        createdAt: DateTime.utc(2026, 7, 18),
      ),
    ],
  );
}

class _FakeGateway implements StatementGateway {
  _FakeGateway(this.handler);

  Future<StatementSnapshot?> Function(
    String groupId,
    DateTime? from,
    DateTime? to,
  )
  handler;

  int calls = 0;
  String? receivedGroupId;
  DateTime? receivedFrom;
  DateTime? receivedTo;

  @override
  Future<StatementSnapshot?> load(
    String groupId, {
    DateTime? from,
    DateTime? to,
  }) {
    calls++;
    receivedGroupId = groupId;
    receivedFrom = from;
    receivedTo = to;
    return handler(groupId, from, to);
  }
}

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('maps raw failures and CSV exposes public fields only', () {
    expect(
      StatementFailure.fromError(
        Exception('row-level security user-99 payment-ref-secret'),
      ).kind,
      StatementFailureKind.permissionDenied,
    );
    expect(safePublicStatementAlias(' FAN 20/48!private '), '#FAN2048private');
    expect(statementStatusFrom('reversed'), StatementEntryStatus.failed);

    final csv = buildStatementCsv(
      StatementState(snapshot: _snapshot(), sort: StatementSort.amount),
    );
    expect(csv, startsWith('Alias,Amount,Status,Date'));
    expect(csv.indexOf('#FAN2048'), lessThan(csv.indexOf('#BLUEARMY')));
    expect(csv, isNot(contains('Reference')));
    expect(csv, isNot(contains('user_id')));
    expect(csv, isNot(contains('momo')));
    expect(csv, isNot(contains('phone')));
  });

  test('loads the exact route id and selected date range', () async {
    final gateway = _FakeGateway((_, _, _) async => _snapshot());
    final controller = StatementController(
      gateway,
      groupId: _groupId,
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    final from = DateTime(2026, 7, 1);
    final to = DateTime(2026, 7, 20);
    await controller.setRange(from: from, to: to);

    expect(gateway.receivedGroupId, _groupId);
    expect(gateway.receivedFrom, from);
    expect(gateway.receivedTo, to);
    expect(controller.state.requireValue.snapshot.groupName, contains('Away'));
  });

  test('fails offline before calling the gateway', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _FakeGateway((_, _, _) async => _snapshot());
    final controller = StatementController(
      gateway,
      groupId: _groupId,
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(gateway.calls, 0);
    expect(
      (controller.state as AsyncError<StatementState>).error,
      const StatementFailure(StatementFailureKind.offline),
    );
  });

  test('maps a bounded read timeout to security timeout', () async {
    final gateway = _FakeGateway(
      (_, _, _) => Completer<StatementSnapshot?>().future,
    );
    final controller = StatementController(
      gateway,
      groupId: _groupId,
      loadTimeout: const Duration(milliseconds: 5),
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(
      (controller.state as AsyncError<StatementState>).error,
      const StatementFailure(StatementFailureKind.securityTimeout),
    );
  });

  test('treats a missing initiative as not found', () async {
    final gateway = _FakeGateway((_, _, _) async => null);
    final controller = StatementController(
      gateway,
      groupId: _groupId,
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(
      (controller.state as AsyncError<StatementState>).error,
      const StatementFailure(StatementFailureKind.notFound),
    );
  });

  test('retains confirmed statement when refresh conflicts', () async {
    var call = 0;
    final gateway = _FakeGateway((_, _, _) async {
      call++;
      if (call == 1) return _snapshot();
      throw Exception('stale statement revision');
    });
    final controller = StatementController(
      gateway,
      groupId: _groupId,
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    controller.setSort(StatementSort.alias);
    await controller.refresh();

    final retained = controller.state.requireValue;
    expect(retained.snapshot.entries, hasLength(2));
    expect(retained.sort, StatementSort.alias);
    expect(retained.phase, StatementPhase.degraded);
    expect(retained.failure?.kind, StatementFailureKind.conflict);
  });

  test('coalesces concurrent refreshes and exposes syncing state', () async {
    final gateway = _FakeGateway((_, _, _) async => _snapshot());
    final controller = StatementController(
      gateway,
      groupId: _groupId,
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    final completer = Completer<StatementSnapshot?>();
    gateway.handler = (_, _, _) => completer.future;
    final first = controller.refresh();
    final second = controller.refresh();
    expect(identical(first, second), isTrue);
    expect(controller.state.requireValue.phase, StatementPhase.syncing);
    expect(gateway.calls, 2);
    completer.complete(_snapshot());
    await first;
    expect(controller.state.requireValue.phase, StatementPhase.ready);
  });
}
