import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a bounded strict SMS operations workspace', () async {
    final gateway = _Gateway(<Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    final value = await container.read(adminSmsMonitorProvider.future);

    expect(value.metrics, hasLength(2));
    expect(value.metrics.first.label, 'Device Sync');
    expect(value.runs.single.scannedMessages, 24);
    expect(value.controlsEnabled, isTrue);
  });

  test(
    'classifies offline before requesting private operational data',
    () async {
      ConnectivityService.setOnlineForTest(false);
      final gateway = _Gateway(<Object>[_workspace]);
      final container = _container(gateway);
      addTearDown(container.dispose);

      await expectLater(
        container.read(adminSmsMonitorProvider.future),
        throwsA(
          isA<AdminSmsMonitorFailure>().having(
            (failure) => failure.kind,
            'kind',
            AdminSmsMonitorFailureKind.offline,
          ),
        ),
      );
      expect(gateway.loadCount, 0);
    },
  );

  test('bounds private reads with a security timeout', () async {
    final gateway = _Gateway(<Object>[
      Completer<AdminSmsMonitorSnapshot>().future,
    ]);
    final container = _container(
      gateway,
      timeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminSmsMonitorProvider.future),
      throwsA(
        isA<AdminSmsMonitorFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminSmsMonitorFailureKind.securityTimeout,
        ),
      ),
    );
  });

  test('permission denial clears retained operational information', () async {
    final gateway = _Gateway(<Object>[
      _workspace,
      const AdminSmsMonitorFailure(AdminSmsMonitorFailureKind.permissionDenied),
    ]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminSmsMonitorProvider.future);

    await container.read(adminSmsMonitorProvider.notifier).refresh();

    final value = container.read(adminSmsMonitorProvider).requireValue;
    expect(value.metrics, isEmpty);
    expect(value.runs, isEmpty);
    expect(value.failure?.kind, AdminSmsMonitorFailureKind.permissionDenied);
    expect(value.controlsEnabled, isFalse);
  });

  test('recoverable conflict retains confirmed information', () async {
    final gateway = _Gateway(<Object>[
      _workspace,
      const AdminSmsMonitorFailure(AdminSmsMonitorFailureKind.conflict),
    ]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminSmsMonitorProvider.future);

    await container.read(adminSmsMonitorProvider.notifier).refresh();

    final value = container.read(adminSmsMonitorProvider).requireValue;
    expect(value.metrics, hasLength(2));
    expect(value.runs, hasLength(1));
    expect(value.failure?.kind, AdminSmsMonitorFailureKind.conflict);
    expect(value.controlsEnabled, isFalse);
  });

  test('strict projection rejects oversized duplicate and malformed data', () {
    expect(
      () => AdminSmsMonitorSnapshot.fromRaw(<String, dynamic>{
        'metrics': List<Map<String, dynamic>>.generate(9, (_) => _metric()),
        'runs': const <Map<String, dynamic>>[],
      }),
      throwsFormatException,
    );
    expect(
      () => AdminSmsMonitorSnapshot.fromRaw(<String, dynamic>{
        'metrics': <Map<String, dynamic>>[_metric(), _metric()],
        'runs': const <Map<String, dynamic>>[],
      }),
      throwsFormatException,
    );
    expect(
      () => AdminSmsMonitorSnapshot.fromRaw(<String, dynamic>{
        'metrics': <Map<String, dynamic>>[
          <String, dynamic>{..._metric(), 'primary_value': 'private-count'},
        ],
        'runs': const <Map<String, dynamic>>[],
      }),
      throwsFormatException,
    );
  });

  test('sync run rejects invalid time ranges and identifiers', () {
    expect(
      () => AdminSmsMonitorSnapshot.fromRaw(<String, dynamic>{
        'metrics': <Map<String, dynamic>>[_metric()],
        'runs': <Map<String, dynamic>>[
          _run(
            startedAt: '2026-07-30T09:00:00Z',
            completedAt: '2026-07-30T08:59:00Z',
          ),
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => AdminSmsMonitorSnapshot.fromRaw(<String, dynamic>{
        'metrics': <Map<String, dynamic>>[_metric()],
        'runs': <Map<String, dynamic>>[_run(id: 'private-id')],
      }),
      throwsFormatException,
    );
  });

  test('private extras are ignored by bounded metric and run models', () {
    final snapshot = AdminSmsMonitorSnapshot.fromRaw(<String, dynamic>{
      'metrics': <Map<String, dynamic>>[
        <String, dynamic>{
          ..._metric(),
          'supporter_ids': <String>['private-user-id'],
        },
      ],
      'runs': <Map<String, dynamic>>[
        <String, dynamic>{
          ..._run(),
          'user_id': 'private-user-id',
          'error_message': 'private-provider-detail',
          'metadata': <String, dynamic>{'secret': 'private-value'},
        },
      ],
    });

    expect(snapshot.metrics.single.label, 'Device Sync');
    expect(snapshot.runs.single.uploadedMessages, 20);
    expect(snapshot.toString(), isNot(contains('private-user-id')));
    expect(snapshot.toString(), isNot(contains('private-provider-detail')));
  });
}

ProviderContainer _container(
  AdminSmsMonitorGateway gateway, {
  Duration timeout = const Duration(seconds: 12),
}) {
  return ProviderContainer(
    overrides: <Override>[
      adminSmsMonitorGatewayProvider.overrideWithValue(gateway),
      adminSmsMonitorLoadTimeoutProvider.overrideWithValue(timeout),
    ],
  );
}

final _workspace = AdminSmsMonitorSnapshot.fromRaw(<String, dynamic>{
  'metrics': <Map<String, dynamic>>[
    _metric(),
    _metric(
      key: 'parsing',
      label: 'Parsing',
      status: 'degraded',
      summary: 'Two messages are waiting for controlled review.',
    ),
  ],
  'runs': <Map<String, dynamic>>[_run()],
});

Map<String, dynamic> _metric({
  String key = 'device_sync',
  String label = 'Device Sync',
  String status = 'healthy',
  String summary = 'Four successful synchronizations were reported.',
}) {
  return <String, dynamic>{
    'metric_key': key,
    'label': label,
    'health_status': status,
    'summary': summary,
    'primary_label': '24h Success',
    'primary_value': 4,
    'secondary_label': '24h Fail',
    'secondary_value': 0,
    'tertiary_label': 'Duplicates',
    'tertiary_value': 2,
    'last_signal_at': '2026-07-30T08:00:00Z',
  };
}

Map<String, dynamic> _run({
  String id = '11111111-1111-4111-8111-111111111111',
  String startedAt = '2026-07-30T08:00:00Z',
  String? completedAt = '2026-07-30T08:01:00Z',
}) {
  return <String, dynamic>{
    'id': id,
    'status': 'succeeded',
    'trigger': 'manual',
    'scanned_messages': 24,
    'uploaded_messages': 20,
    'duplicate_messages': 4,
    'scan_started_at': startedAt,
    'scan_completed_at': completedAt,
  };
}

class _Gateway implements AdminSmsMonitorGateway {
  _Gateway(this.outcomes);

  final List<Object> outcomes;
  var loadCount = 0;

  @override
  Future<AdminSmsMonitorSnapshot> load() async {
    final outcome = outcomes[loadCount.clamp(0, outcomes.length - 1)];
    loadCount += 1;
    if (outcome is Future<AdminSmsMonitorSnapshot>) return outcome;
    if (outcome is AdminSmsMonitorSnapshot) return outcome;
    throw outcome;
  }
}
