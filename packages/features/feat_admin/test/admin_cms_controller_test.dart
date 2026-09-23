import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a confirmed bounded CMS workspace', () async {
    final gateway = _QueueCmsGateway(<Object>[_snapshot]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    final value = await container.read(adminCmsProvider.future);

    expect(value.articles.single['title'], 'Season launch');
    expect(value.quickActions.single['route'], '/tickets');
    expect(value.phase, AdminCmsPhase.ready);
    expect(value.actionsEnabled, isTrue);
  });

  test('classifies offline before requesting private CMS data', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _QueueCmsGateway(<Object>[_snapshot]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminCmsProvider.future),
      throwsA(
        isA<AdminCmsFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminCmsFailureKind.offline,
        ),
      ),
    );
    expect(gateway.loadCount, 0);
  });

  test('bounds CMS loads with a security timeout', () async {
    final gateway = _QueueCmsGateway(<Object>[
      Completer<AdminCmsSnapshot>().future,
    ]);
    final container = _container(
      gateway,
      loadTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminCmsProvider.future),
      throwsA(
        isA<AdminCmsFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminCmsFailureKind.securityTimeout,
        ),
      ),
    );
  });

  test(
    'retains confirmed workspace and locks actions after conflict',
    () async {
      final gateway = _QueueCmsGateway(<Object>[
        _snapshot,
        const AdminCmsFailure(AdminCmsFailureKind.conflict),
      ]);
      final container = _container(gateway);
      addTearDown(container.dispose);
      await container.read(adminCmsProvider.future);

      await container.read(adminCmsProvider.notifier).refresh();
      final value = container.read(adminCmsProvider).requireValue;

      expect(value.articles, hasLength(1));
      expect(value.phase, AdminCmsPhase.degraded);
      expect(value.failure?.kind, AdminCmsFailureKind.conflict);
      expect(value.actionsEnabled, isFalse);
    },
  );

  test(
    'permission denial clears all previously confirmed private data',
    () async {
      final gateway = _QueueCmsGateway(<Object>[
        _snapshot,
        const AdminCmsFailure(AdminCmsFailureKind.permissionDenied),
      ]);
      final container = _container(gateway);
      addTearDown(container.dispose);
      await container.read(adminCmsProvider.future);

      await container.read(adminCmsProvider.notifier).refresh();
      final value = container.read(adminCmsProvider).requireValue;

      expect(value.articles, isEmpty);
      expect(value.quickActions, isEmpty);
      expect(value.auditLogs, isEmpty);
      expect(value.failure?.kind, AdminCmsFailureKind.permissionDenied);
    },
  );

  test(
    'offline mutation retains confirmed data and never invokes operation',
    () async {
      final gateway = _QueueCmsGateway(<Object>[_snapshot]);
      final container = _container(gateway);
      addTearDown(container.dispose);
      await container.read(adminCmsProvider.future);
      ConnectivityService.setOnlineForTest(false);
      var invoked = false;

      final result = await container
          .read(adminCmsProvider.notifier)
          .runMutation((repository) async {
            invoked = true;
          });
      final value = container.read(adminCmsProvider).requireValue;

      expect(result, isFalse);
      expect(invoked, isFalse);
      expect(value.articles, hasLength(1));
      expect(value.failure?.kind, AdminCmsFailureKind.offline);
      expect(value.actionsEnabled, isFalse);
    },
  );

  test(
    'strict projection omits private extras and rejects oversized records',
    () {
      final workspace = AdminCmsSnapshot.fromRawCollections(<Object?>[
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'article-1',
            'title': 'Public title',
            'private_actor': 'private-secret',
          },
        ],
        const <Object>[],
        const <Object>[],
        const <Object>[],
        const <Object>[],
        const <Object>[],
        const <Object>[],
        const <Object>[],
        const <Object>[],
      ]);
      expect(workspace.articles.single['private_actor'], isNull);

      expect(
        () => AdminCmsSnapshot.fromRawCollections(<Object?>[
          List<Map<String, dynamic>>.generate(
            51,
            (index) => <String, dynamic>{
              'id': 'article-$index',
              'title': 'Article $index',
            },
          ),
          const <Object>[],
          const <Object>[],
          const <Object>[],
          const <Object>[],
          const <Object>[],
          const <Object>[],
          const <Object>[],
          const <Object>[],
        ]),
        throwsFormatException,
      );
    },
  );

  test('sensitive diagnostics map to stable categories', () {
    expect(
      AdminCmsFailure.fromError(
        StateError('row-level security private-user-991'),
      ).kind,
      AdminCmsFailureKind.permissionDenied,
    );
    expect(
      AdminCmsFailure.fromError(
        StateError('stale revision private-content-991'),
      ).kind,
      AdminCmsFailureKind.conflict,
    );
  });
}

ProviderContainer _container(
  AdminCmsGateway gateway, {
  Duration loadTimeout = const Duration(seconds: 12),
}) {
  return ProviderContainer(
    overrides: <Override>[
      adminCmsGatewayProvider.overrideWithValue(gateway),
      adminCmsLoadTimeoutProvider.overrideWithValue(loadTimeout),
    ],
  );
}

final _snapshot = AdminCmsSnapshot.fromRawCollections(<Object?>[
  <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'article-1',
      'title': 'Season launch',
      'category': 'Club',
      'is_published': true,
      'published_at': '2026-07-30T08:00:00Z',
    },
  ],
  <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'action-1',
      'action_key': 'tickets',
      'title': 'Tickets',
      'route': '/tickets',
      'icon_key': 'ticket',
      'is_active': true,
    },
  ],
  const <Object>[],
  const <Object>[],
  const <Object>[],
  const <Object>[],
  const <Object>[],
  const <Object>[],
  const <Object>[],
]);

class _QueueCmsGateway implements AdminCmsGateway {
  _QueueCmsGateway(this.outcomes);

  final List<Object> outcomes;
  int loadCount = 0;

  @override
  Future<AdminCmsSnapshot> load() async {
    final index = loadCount++;
    final outcome = outcomes[index.clamp(0, outcomes.length - 1)];
    if (outcome is Future<AdminCmsSnapshot>) return outcome;
    if (outcome is AdminCmsSnapshot) return outcome;
    throw outcome;
  }
}
