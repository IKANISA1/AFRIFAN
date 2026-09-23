import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a confirmed dashboard snapshot', () async {
    final gateway = _QueueDashboardGateway(<Object>[_snapshot]);
    final container = ProviderContainer(
      overrides: <Override>[
        adminDashboardGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);

    final value = await container.read(adminDashboardProvider.future);

    expect(value.metrics.totalUsers, 42);
    expect(value.activity.single.title, 'Season launch');
    expect(value.phase, AdminDashboardPhase.ready);
  });

  test('classifies offline before requesting private data', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _QueueDashboardGateway(<Object>[_snapshot]);
    final container = ProviderContainer(
      overrides: <Override>[
        adminDashboardGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminDashboardProvider.future),
      throwsA(
        isA<AdminDashboardFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminDashboardFailureKind.offline,
        ),
      ),
    );
    expect(gateway.loadCount, 0);
  });

  test('bounds dashboard loads with a security timeout', () async {
    final gateway = _QueueDashboardGateway(<Object>[
      Completer<AdminDashboardSnapshot>().future,
    ]);
    final container = ProviderContainer(
      overrides: <Override>[
        adminDashboardGatewayProvider.overrideWithValue(gateway),
        adminDashboardLoadTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 1),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminDashboardProvider.future),
      throwsA(
        isA<AdminDashboardFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminDashboardFailureKind.securityTimeout,
        ),
      ),
    );
  });

  test(
    'retains confirmed data and locks actions after refresh conflict',
    () async {
      final gateway = _QueueDashboardGateway(<Object>[
        _snapshot,
        const AdminDashboardFailure(AdminDashboardFailureKind.conflict),
      ]);
      final container = ProviderContainer(
        overrides: <Override>[
          adminDashboardGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      await container.read(adminDashboardProvider.future);

      await container.read(adminDashboardProvider.notifier).refresh();
      final value = container.read(adminDashboardProvider).requireValue;

      expect(value.metrics.totalUsers, 42);
      expect(value.phase, AdminDashboardPhase.degraded);
      expect(value.failure?.kind, AdminDashboardFailureKind.conflict);
      expect(value.actionsEnabled, isFalse);
    },
  );

  test('permission denial clears previously confirmed private data', () async {
    final gateway = _QueueDashboardGateway(<Object>[
      _snapshot,
      const AdminDashboardFailure(AdminDashboardFailureKind.permissionDenied),
    ]);
    final container = ProviderContainer(
      overrides: <Override>[
        adminDashboardGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    await container.read(adminDashboardProvider.future);

    await container.read(adminDashboardProvider.notifier).refresh();
    final state = container.read(adminDashboardProvider);

    expect(state.hasValue, isTrue);
    expect(state.requireValue.metrics.totalUsers, 0);
    expect(state.requireValue.activity, isEmpty);
    expect(
      state.requireValue.failure?.kind,
      AdminDashboardFailureKind.permissionDenied,
    );
  });

  group('AdminDashboardFailure', () {
    test('sanitizes provider diagnostics into stable categories', () {
      expect(
        AdminDashboardFailure.fromError(
          StateError('row-level security account private-991'),
        ).kind,
        AdminDashboardFailureKind.permissionDenied,
      );
      expect(
        AdminDashboardFailure.fromError(
          StateError('stale revision private-991'),
        ).kind,
        AdminDashboardFailureKind.conflict,
      );
      expect(
        AdminDashboardFailure.fromError(
          StateError('SocketException host private-991'),
        ).kind,
        AdminDashboardFailureKind.offline,
      );
    });
  });
}

const _snapshot = AdminDashboardSnapshot(
  metrics: AdminDashboardMetrics(
    totalUsers: 42,
    activeGroups: 3,
    transactionsToday: 7,
    ticketsSold: 11,
  ),
  activity: <AdminDashboardActivity>[
    AdminDashboardActivity(title: 'Season launch', category: 'CMS'),
  ],
);

class _QueueDashboardGateway implements AdminDashboardGateway {
  _QueueDashboardGateway(this._outcomes);

  final List<Object> _outcomes;
  int loadCount = 0;

  @override
  Future<AdminDashboardSnapshot> load() async {
    final index = loadCount++;
    final outcome = _outcomes[index.clamp(0, _outcomes.length - 1)];
    if (outcome is Future<AdminDashboardSnapshot>) return outcome;
    if (outcome is AdminDashboardSnapshot) return outcome;
    throw outcome;
  }
}
