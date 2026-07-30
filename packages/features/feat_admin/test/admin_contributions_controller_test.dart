import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads bounded privacy-minimized contribution data', () async {
    final gateway = _QueueGateway(<Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    final value = await container.read(adminContributionsProvider.future);

    expect(value.groups.single.name, 'Stadium Lights');
    expect(value.contributions.single.amount, 15000);
    expect(value.recordCountFor('group-1'), 1);
    expect(value.controlsEnabled, isTrue);
  });

  test('classifies offline before requesting private records', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _QueueGateway(<Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminContributionsProvider.future),
      throwsA(
        isA<AdminContributionsFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminContributionsFailureKind.offline,
        ),
      ),
    );
    expect(gateway.loadCount, 0);
  });

  test('bounds private reads with a security timeout', () async {
    final gateway = _QueueGateway(<Object>[
      Completer<AdminContributionsSnapshot>().future,
    ]);
    final container = _container(
      gateway,
      loadTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminContributionsProvider.future),
      throwsA(
        isA<AdminContributionsFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminContributionsFailureKind.securityTimeout,
        ),
      ),
    );
  });

  test('retains confirmed totals and locks controls after conflict', () async {
    final gateway = _QueueGateway(<Object>[
      _workspace,
      const AdminContributionsFailure(AdminContributionsFailureKind.conflict),
    ]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminContributionsProvider.future);

    await container.read(adminContributionsProvider.notifier).refresh();
    final value = container.read(adminContributionsProvider).requireValue;

    expect(value.groups, hasLength(1));
    expect(value.failure?.kind, AdminContributionsFailureKind.conflict);
    expect(value.controlsEnabled, isFalse);
  });

  test('permission denial clears groups and contribution records', () async {
    final gateway = _QueueGateway(<Object>[
      _workspace,
      const AdminContributionsFailure(
        AdminContributionsFailureKind.permissionDenied,
      ),
    ]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminContributionsProvider.future);

    await container.read(adminContributionsProvider.notifier).refresh();
    final value = container.read(adminContributionsProvider).requireValue;

    expect(value.groups, isEmpty);
    expect(value.contributions, isEmpty);
    expect(value.failure?.kind, AdminContributionsFailureKind.permissionDenied);
  });

  test('filters and sorts locally without another private read', () async {
    final gateway = _QueueGateway(<Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminContributionsProvider.future);

    container
        .read(adminContributionsProvider.notifier)
        .selectFilter(AdminContributionGroupFilter.community);
    container
        .read(adminContributionsProvider.notifier)
        .selectSort(AdminContributionSort.total);
    final value = container.read(adminContributionsProvider).requireValue;

    expect(value.visibleGroups, isEmpty);
    expect(value.sort, AdminContributionSort.total);
    expect(gateway.loadCount, 1);
  });

  test('strict projection rejects oversized and orphan records', () {
    expect(
      () => AdminContributionsSnapshot.fromRawCollections(
        List<Map<String, dynamic>>.generate(
          201,
          (index) => _groupRow(id: 'group-$index'),
        ),
        const <Object>[],
      ),
      throwsFormatException,
    );
    expect(
      () => AdminContributionsSnapshot.fromRawCollections(
        <Map<String, dynamic>>[_groupRow()],
        <Map<String, dynamic>>[_contributionRow(groupId: 'private-group')],
      ),
      throwsFormatException,
    );
  });

  test('ignores private extras and computes confirmed monthly totals', () {
    final snapshot = AdminContributionsSnapshot.fromRawCollections(
      <Map<String, dynamic>>[
        {..._groupRow(), 'creator_id': 'private-user-991'},
      ],
      <Map<String, dynamic>>[
        {
          ..._contributionRow(),
          'user_id': 'private-user-991',
          'momo_reference': 'private-payment-reference',
        },
      ],
    );

    expect(snapshot.groups.single.name, 'Stadium Lights');
    expect(snapshot.monthlyTotalAt(DateTime.utc(2026, 7, 30)), 15000);
    expect(snapshot.toString(), isNot(contains('private-user-991')));
  });
}

ProviderContainer _container(
  AdminContributionsGateway gateway, {
  Duration loadTimeout = const Duration(seconds: 12),
}) {
  return ProviderContainer(
    overrides: <Override>[
      adminContributionsGatewayProvider.overrideWithValue(gateway),
      adminContributionsLoadTimeoutProvider.overrideWithValue(loadTimeout),
    ],
  );
}

final _workspace = AdminContributionsSnapshot.fromRawCollections(
  <Map<String, dynamic>>[_groupRow()],
  <Map<String, dynamic>>[_contributionRow()],
);

Map<String, dynamic> _groupRow({String id = 'group-1'}) {
  return <String, dynamic>{
    'id': id,
    'name': 'Stadium Lights',
    'group_type': 'project',
    'current_total': 750000,
    'target_amount': 2000000,
    'member_count': 84,
    'is_closed': false,
    'created_at': '2026-07-18T08:00:00Z',
  };
}

Map<String, dynamic> _contributionRow({String groupId = 'group-1'}) {
  return <String, dynamic>{
    'id': 'contribution-1',
    'group_id': groupId,
    'amount': 15000,
    'status': 'confirmed',
    'created_at': '2026-07-29T10:15:00Z',
  };
}

class _QueueGateway implements AdminContributionsGateway {
  _QueueGateway(this.outcomes);

  final List<Object> outcomes;
  int loadCount = 0;

  @override
  Future<AdminContributionsSnapshot> load() async {
    final index = loadCount++;
    final outcome = outcomes[index.clamp(0, outcomes.length - 1)];
    if (outcome is Future<AdminContributionsSnapshot>) return outcome;
    if (outcome is AdminContributionsSnapshot) return outcome;
    throw outcome;
  }
}
