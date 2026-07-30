import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a bounded strict notification workspace', () async {
    final gateway = _Gateway(loadOutcomes: <Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    final value = await container.read(adminNotificationsProvider.future);

    expect(value.groups.single.name, 'Blue Family');
    expect(value.history.single.title, 'Match day');
    expect(value.actionsEnabled, isTrue);
  });

  test('classifies offline before requesting private delivery data', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway(loadOutcomes: <Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminNotificationsProvider.future),
      throwsA(
        isA<AdminNotificationsFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminNotificationsFailureKind.offline,
        ),
      ),
    );
    expect(gateway.loadCount, 0);
  });

  test('bounds private reads with a security timeout', () async {
    final gateway = _Gateway(
      loadOutcomes: <Object>[Completer<AdminNotificationsSnapshot>().future],
    );
    final container = _container(
      gateway,
      loadTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminNotificationsProvider.future),
      throwsA(
        isA<AdminNotificationsFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminNotificationsFailureKind.securityTimeout,
        ),
      ),
    );
  });

  test('permission denial clears retained groups and history', () async {
    final gateway = _Gateway(
      loadOutcomes: <Object>[
        _workspace,
        const AdminNotificationsFailure(
          AdminNotificationsFailureKind.permissionDenied,
        ),
      ],
    );
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminNotificationsProvider.future);

    await container.read(adminNotificationsProvider.notifier).refresh();

    final value = container.read(adminNotificationsProvider).requireValue;
    expect(value.groups, isEmpty);
    expect(value.history, isEmpty);
    expect(value.failure?.kind, AdminNotificationsFailureKind.permissionDenied);
  });

  test('successful send reloads confirmed delivery history', () async {
    final gateway = _Gateway(
      loadOutcomes: <Object>[_workspace, _workspace],
      sendOutcomes: <Object>[_delivery],
    );
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminNotificationsProvider.future);

    final result = await container
        .read(adminNotificationsProvider.notifier)
        .send(_draft());

    expect(result?.status, 'sent');
    expect(gateway.sendCount, 1);
    expect(gateway.loadCount, 2);
  });

  test('mutation timeout retains data and blocks duplicate send', () async {
    final pending = Completer<AdminNotificationDelivery>();
    final gateway = _Gateway(
      loadOutcomes: <Object>[_workspace],
      sendOutcomes: <Object>[pending.future],
    );
    final container = _container(
      gateway,
      mutationTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);
    await container.read(adminNotificationsProvider.future);

    expect(
      await container.read(adminNotificationsProvider.notifier).send(_draft()),
      isNull,
    );

    final value = container.read(adminNotificationsProvider).requireValue;
    expect(value.history, hasLength(1));
    expect(value.mutationOutcomeUnconfirmed, isTrue);
    expect(value.actionsEnabled, isFalse);
    expect(
      await container.read(adminNotificationsProvider.notifier).send(_draft()),
      isNull,
    );
    expect(gateway.sendCount, 1);
  });

  test('strict projection rejects oversized, duplicate and malformed data', () {
    expect(
      () => AdminNotificationsSnapshot.fromRaw(<String, dynamic>{
        'groups': List<Map<String, dynamic>>.generate(
          51,
          (index) => <String, dynamic>{
            'id': 'group-$index',
            'name': 'Group $index',
          },
        ),
        'history': const <Map<String, dynamic>>[],
      }),
      throwsFormatException,
    );
    expect(
      () => AdminNotificationsSnapshot.fromRaw(<String, dynamic>{
        'groups': <Map<String, dynamic>>[_group, _group],
        'history': const <Map<String, dynamic>>[],
      }),
      throwsFormatException,
    );
    expect(
      () => AdminNotificationsSnapshot.fromRaw(<String, dynamic>{
        'groups': <Map<String, dynamic>>[_group],
        'history': <Map<String, dynamic>>[
          <String, dynamic>{..._history, 'sent_count': 'private-count'},
        ],
      }),
      throwsFormatException,
    );
  });

  test('draft rejects unknown group and unsafe image URL', () async {
    final gateway = _Gateway(loadOutcomes: <Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminNotificationsProvider.future);

    await expectLater(
      () => container
          .read(adminNotificationsProvider.notifier)
          .send(<String, dynamic>{
            ..._draft(),
            'audience': 'by_group',
            'group_id': 'unknown',
            'group_name': 'Unknown',
          }),
      throwsFormatException,
    );
    expect(
      () => AdminNotificationDraft.fromRaw(<String, dynamic>{
        ..._draft(),
        'image_url': 'file:///private/image.png',
      }),
      throwsFormatException,
    );
  });

  test('private extras are ignored by the bounded history model', () {
    final snapshot = AdminNotificationsSnapshot.fromRaw(<String, dynamic>{
      'groups': <Map<String, dynamic>>[_group],
      'history': <Map<String, dynamic>>[
        <String, dynamic>{
          ..._history,
          'created_by': 'private-admin-id',
          'last_error': 'private-provider-diagnostic',
        },
      ],
    });

    expect(snapshot.history.single.title, 'Match day');
    expect(snapshot.toString(), isNot(contains('private-admin-id')));
    expect(snapshot.toString(), isNot(contains('private-provider-diagnostic')));
  });
}

ProviderContainer _container(
  AdminNotificationsGateway gateway, {
  Duration loadTimeout = const Duration(seconds: 12),
  Duration mutationTimeout = const Duration(seconds: 12),
}) {
  return ProviderContainer(
    overrides: <Override>[
      adminNotificationsGatewayProvider.overrideWithValue(gateway),
      adminNotificationsLoadTimeoutProvider.overrideWithValue(loadTimeout),
      adminNotificationsMutationTimeoutProvider.overrideWithValue(
        mutationTimeout,
      ),
    ],
  );
}

const _group = <String, dynamic>{'id': 'group-1', 'name': 'Blue Family'};
const _history = <String, dynamic>{
  'id': 'notification-1',
  'title': 'Match day',
  'body': 'Gates open at 16:00.',
  'audience_type': 'all_fans',
  'audience_tier': null,
  'audience_group_name': null,
  'delivery_mode': 'send_now',
  'status': 'sent',
  'scheduled_at': null,
  'sent_at': '2026-07-30T08:00:00Z',
  'requested_recipient_count': 1200,
  'sent_count': 1180,
  'failed_count': 20,
  'created_at': '2026-07-30T07:58:00Z',
};

final _workspace = AdminNotificationsSnapshot.fromRaw(<String, dynamic>{
  'groups': <Map<String, dynamic>>[_group],
  'history': <Map<String, dynamic>>[_history],
});
const _delivery = AdminNotificationDelivery(
  status: 'sent',
  requestedCount: 1200,
  sentCount: 1180,
  failedCount: 20,
);

Map<String, dynamic> _draft() => <String, dynamic>{
  'audience': 'all_fans',
  'title': 'Match day',
  'body': 'Gates open at 16:00.',
  'delivery_mode': 'send_now',
};

class _Gateway implements AdminNotificationsGateway {
  _Gateway({List<Object>? loadOutcomes, List<Object>? sendOutcomes})
    : loadOutcomes = loadOutcomes ?? <Object>[_workspace],
      sendOutcomes = sendOutcomes ?? <Object>[_delivery];

  final List<Object> loadOutcomes;
  final List<Object> sendOutcomes;
  int loadCount = 0;
  int sendCount = 0;

  @override
  Future<AdminNotificationsSnapshot> load() async {
    final index = loadCount++;
    final outcome = loadOutcomes[index.clamp(0, loadOutcomes.length - 1)];
    if (outcome is Future<AdminNotificationsSnapshot>) return outcome;
    if (outcome is AdminNotificationsSnapshot) return outcome;
    throw outcome;
  }

  @override
  Future<AdminNotificationDelivery> send(AdminNotificationDraft draft) async {
    final index = sendCount++;
    final outcome = sendOutcomes[index.clamp(0, sendOutcomes.length - 1)];
    if (outcome is Future<AdminNotificationDelivery>) return outcome;
    if (outcome is AdminNotificationDelivery) return outcome;
    throw outcome;
  }
}
