import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_contributions/src/controllers/group_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGroupDetailGateway implements GroupDetailGateway {
  Future<GroupDetailSnapshot?> Function(String groupId)? onLoad;
  int loadCount = 0;
  final List<String> requestedIds = <String>[];

  @override
  Future<GroupDetailSnapshot?> load(String groupId) {
    loadCount++;
    requestedIds.add(groupId);
    final callback = onLoad;
    if (callback == null) {
      return Future<GroupDetailSnapshot?>.value(_snapshot());
    }
    return callback(groupId);
  }
}

ContributionGroup _group() {
  return ContributionGroup(
    id: 'initiative-1',
    creatorId: 'club-admin',
    name: 'Away Day Travel Fund',
    description: 'Help supporters travel safely to the next away fixture.',
    groupType: ContributionGroupType.project,
    targetAmount: 1000000,
    currentTotal: 640000,
    paymentRecipient: '123456',
    memberCount: 86,
    createdAt: DateTime.utc(2026, 7, 1),
  );
}

GroupDetailSnapshot _snapshot({int currentTotal = 640000}) {
  final source = _group();
  return GroupDetailSnapshot(
    group: ContributionGroup(
      id: source.id,
      creatorId: source.creatorId,
      name: source.name,
      description: source.description,
      groupType: source.groupType,
      targetAmount: source.targetAmount,
      currentTotal: currentTotal,
      paymentRecipient: source.paymentRecipient,
      memberCount: source.memberCount,
      createdAt: source.createdAt,
    ),
    ledger: <GroupLedgerEntry>[
      GroupLedgerEntry(
        publicAlias: '#FAN2048',
        amount: 25000,
        status: GroupLedgerStatus.confirmed,
        createdAt: DateTime.utc(2026, 7, 18),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('failure mapping never returns raw backend diagnostics', () {
    final failure = GroupDetailFailure.fromError(
      StateError(
        'row-level security rejected supporter-991 at contribution_groups',
      ),
    );

    expect(failure.kind, GroupDetailFailureKind.permissionDenied);
    expect(failure.toString(), 'GroupDetailFailure(permissionDenied)');
    expect(failure.toString(), isNot(contains('supporter-991')));
    expect(failure.toString(), isNot(contains('contribution_groups')));
  });

  test('loads the exact route id and adopts the confirmed snapshot', () async {
    final gateway = _FakeGroupDetailGateway();
    final controller = GroupDetailController(
      gateway,
      groupId: 'initiative-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(gateway.requestedIds, <String>['initiative-1']);
    expect(controller.state.hasValue, isTrue);
    expect(controller.state.value!.snapshot.group.currentTotal, 640000);
    expect(controller.state.value!.phase, GroupDetailPhase.ready);
  });

  test('offline startup fails before gateway access', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _FakeGroupDetailGateway();
    final controller = GroupDetailController(
      gateway,
      groupId: 'initiative-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(gateway.loadCount, 0);
    expect(controller.state.error, isA<GroupDetailFailure>());
    expect(
      (controller.state.error as GroupDetailFailure).kind,
      GroupDetailFailureKind.offline,
    );
  });

  test('bounds an unresolved read with a security-timeout failure', () async {
    final gateway = _FakeGroupDetailGateway()
      ..onLoad = (_) => Completer<GroupDetailSnapshot?>().future;
    final controller = GroupDetailController(
      gateway,
      groupId: 'initiative-1',
      loadTimeout: const Duration(milliseconds: 5),
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.state.error, isA<GroupDetailFailure>());
    expect(
      (controller.state.error as GroupDetailFailure).kind,
      GroupDetailFailureKind.securityTimeout,
    );
  });

  test('maps a missing initiative to the explicit not-found state', () async {
    final gateway = _FakeGroupDetailGateway()..onLoad = (_) async => null;
    final controller = GroupDetailController(
      gateway,
      groupId: 'initiative-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.state.error, isA<GroupDetailFailure>());
    expect(
      (controller.state.error as GroupDetailFailure).kind,
      GroupDetailFailureKind.notFound,
    );
  });

  test('retains the last confirmed snapshot after a conflict', () async {
    var calls = 0;
    final gateway = _FakeGroupDetailGateway()
      ..onLoad = (_) async {
        calls++;
        if (calls == 1) return _snapshot();
        throw StateError('record changed after it was loaded');
      };
    final controller = GroupDetailController(
      gateway,
      groupId: 'initiative-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    await controller.refresh();

    final retained = controller.state.value!;
    expect(retained.snapshot.group.currentTotal, 640000);
    expect(retained.phase, GroupDetailPhase.degraded);
    expect(retained.failure?.kind, GroupDetailFailureKind.conflict);
    expect(retained.actionsBlocked, isTrue);
  });

  test(
    'coalesces refreshes and exposes confirmed content as syncing',
    () async {
      final refreshCompleter = Completer<GroupDetailSnapshot?>();
      var calls = 0;
      final gateway = _FakeGroupDetailGateway()
        ..onLoad = (_) {
          calls++;
          if (calls == 1) {
            return Future<GroupDetailSnapshot?>.value(_snapshot());
          }
          return refreshCompleter.future;
        };
      final controller = GroupDetailController(
        gateway,
        groupId: 'initiative-1',
        autoLoad: false,
      );
      addTearDown(controller.dispose);
      await controller.refresh();

      final firstRefresh = controller.refresh();
      final secondRefresh = controller.refresh();
      expect(identical(firstRefresh, secondRefresh), isTrue);
      expect(controller.state.value!.phase, GroupDetailPhase.syncing);
      expect(controller.state.value!.snapshot.group.currentTotal, 640000);
      expect(gateway.loadCount, 2);

      refreshCompleter.complete(_snapshot(currentTotal: 700000));
      await Future.wait(<Future<void>>[firstRefresh, secondRefresh]);

      expect(controller.state.value!.phase, GroupDetailPhase.ready);
      expect(controller.state.value!.snapshot.group.currentTotal, 700000);
      expect(gateway.loadCount, 2);
    },
  );
}
