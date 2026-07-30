import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a bounded strict feature registry', () async {
    final gateway = _Gateway(allOutcomes: <Object>[_registry]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    final value = await container.read(adminFeaturesProvider.future);

    expect(value.features, hasLength(2));
    expect(value.enabledCount, 1);
    expect(
      value.features.map((feature) => feature.featureKey),
      containsAll(<String>['predictions', 'tickets']),
    );
    expect(value.actionsEnabled, isTrue);
  });

  test('classifies offline before requesting private feature data', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway(allOutcomes: <Object>[_registry]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminFeaturesProvider.future),
      throwsA(
        isA<AdminFeaturesFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminFeaturesFailureKind.offline,
        ),
      ),
    );
    expect(gateway.allLoadCount, 0);
  });

  test('bounds registry reads with a security timeout', () async {
    final gateway = _Gateway(
      allOutcomes: <Object>[Completer<AdminFeaturesSnapshot>().future],
    );
    final container = _container(
      gateway,
      loadTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminFeaturesProvider.future),
      throwsA(
        isA<AdminFeaturesFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminFeaturesFailureKind.securityTimeout,
        ),
      ),
    );
  });

  test('filters locally without another private read', () async {
    final gateway = _Gateway(allOutcomes: <Object>[_registry]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminFeaturesProvider.future);

    container
        .read(adminFeaturesProvider.notifier)
        .selectFilter(AdminFeatureStatusFilter.disabled);

    final value = container.read(adminFeaturesProvider).requireValue;
    expect(value.visibleFeatures.single.featureKey, 'tickets');
    expect(gateway.allLoadCount, 1);
  });

  test('permission denial clears retained feature configuration', () async {
    final gateway = _Gateway(
      allOutcomes: <Object>[
        _registry,
        const AdminFeaturesFailure(AdminFeaturesFailureKind.permissionDenied),
      ],
    );
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminFeaturesProvider.future);

    await container.read(adminFeaturesProvider.notifier).refresh();

    final value = container.read(adminFeaturesProvider).requireValue;
    expect(value.features, isEmpty);
    expect(value.failure?.kind, AdminFeaturesFailureKind.permissionDenied);
  });

  test('mutation timeout retains data and blocks duplicate mutation', () async {
    final pending = Completer<void>();
    final gateway = _Gateway(
      allOutcomes: <Object>[_registry],
      mutationOutcomes: <Object>[pending.future],
    );
    final container = _container(
      gateway,
      mutationTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);
    await container.read(adminFeaturesProvider.future);

    final changed = await container
        .read(adminFeaturesProvider.notifier)
        .setGlobalEnabled('feature-1', false);

    final value = container.read(adminFeaturesProvider).requireValue;
    expect(changed, isFalse);
    expect(value.features, hasLength(2));
    expect(value.mutationOutcomeUnconfirmed, isTrue);
    expect(value.actionsEnabled, isFalse);
    expect(
      await container
          .read(adminFeaturesProvider.notifier)
          .setGlobalEnabled('feature-1', false),
      isFalse,
    );
    expect(gateway.mutationCount, 1);
  });

  test('detail reloads confirmed state after a serialized mutation', () async {
    final gateway = _Gateway(
      oneOutcomes: <Object>[
        _detail,
        AdminFeatureDetailSnapshot(
          feature: AdminFeaturesSnapshot.fromRaw(<Map<String, dynamic>>[
            _featureRow(isEnabled: false),
          ]).features.single,
        ),
      ],
    );
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminFeatureDetailProvider('predictions').future);

    final changed = await container
        .read(adminFeatureDetailProvider('predictions').notifier)
        .setGlobalEnabled(false);

    expect(changed, isTrue);
    expect(
      container
          .read(adminFeatureDetailProvider('predictions'))
          .requireValue
          .feature
          ?.isEnabled,
      isFalse,
    );
    expect(gateway.mutationCount, 1);
    expect(gateway.oneLoadCount, 2);
  });

  test(
    'detail conflict retains confirmed settings and pauses controls',
    () async {
      final gateway = _Gateway(
        oneOutcomes: <Object>[
          _detail,
          const AdminFeaturesFailure(AdminFeaturesFailureKind.conflict),
        ],
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      await container.read(adminFeatureDetailProvider('predictions').future);

      await container
          .read(adminFeatureDetailProvider('predictions').notifier)
          .refresh();

      final value = container
          .read(adminFeatureDetailProvider('predictions'))
          .requireValue;
      expect(value.feature?.featureKey, 'predictions');
      expect(value.failure?.kind, AdminFeaturesFailureKind.conflict);
      expect(value.actionsEnabled, isFalse);
    },
  );

  test('strict projection rejects oversized, duplicate and malformed data', () {
    expect(
      () => AdminFeaturesSnapshot.fromRaw(
        List<Map<String, dynamic>>.generate(
          101,
          (index) =>
              _featureRow(id: 'feature-$index', featureKey: 'feature-$index'),
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => AdminFeaturesSnapshot.fromRaw(<Map<String, dynamic>>[
        _featureRow(),
        _featureRow(id: 'feature-2'),
      ]),
      throwsFormatException,
    );
    expect(
      () => AdminFeaturesSnapshot.fromRaw(<Map<String, dynamic>>[
        _featureRow(
          channels: <Map<String, dynamic>>[_channelRow(), _channelRow()],
        ),
      ]),
      throwsFormatException,
    );
  });

  test('private extras are ignored by the bounded feature model', () {
    final snapshot = AdminFeaturesSnapshot.fromRaw(<Map<String, dynamic>>[
      <String, dynamic>{
        ..._featureRow(),
        'created_by': 'private-admin-id',
        'metadata': <String, dynamic>{'secret': 'private-value'},
      },
    ]);

    expect(snapshot.features.single.displayName, 'Predictions');
    expect(snapshot.toString(), isNot(contains('private-admin-id')));
    expect(snapshot.toString(), isNot(contains('private-value')));
  });
}

ProviderContainer _container(
  AdminFeaturesGateway gateway, {
  Duration loadTimeout = const Duration(seconds: 12),
  Duration mutationTimeout = const Duration(seconds: 12),
}) {
  return ProviderContainer(
    overrides: <Override>[
      adminFeaturesGatewayProvider.overrideWithValue(gateway),
      adminFeaturesLoadTimeoutProvider.overrideWithValue(loadTimeout),
      adminFeaturesMutationTimeoutProvider.overrideWithValue(mutationTimeout),
    ],
  );
}

final _registry = AdminFeaturesSnapshot.fromRaw(<Map<String, dynamic>>[
  _featureRow(),
  _featureRow(
    id: 'feature-2',
    featureKey: 'tickets',
    displayName: 'Tickets',
    category: 'Commerce',
    isEnabled: false,
    visibility: 'maintenance',
  ),
]);

final _detail = AdminFeatureDetailSnapshot(
  feature: _registry.features.firstWhere(
    (feature) => feature.featureKey == 'predictions',
  ),
);

Map<String, dynamic> _featureRow({
  String id = 'feature-1',
  String featureKey = 'predictions',
  String displayName = 'Predictions',
  String category = 'Engagement',
  bool isEnabled = true,
  String visibility = 'visible',
  List<Map<String, dynamic>>? channels,
}) {
  return <String, dynamic>{
    'id': id,
    'feature_key': featureKey,
    'display_name': displayName,
    'description': 'Supporter match prediction controls.',
    'category': category,
    'is_enabled': isEnabled,
    'visibility_state': visibility,
    'channels': channels ?? <Map<String, dynamic>>[_channelRow()],
    'rules': <Map<String, dynamic>>[
      <String, dynamic>{
        'auth_required': true,
        'schedule_start_at': '2026-08-01T08:00:00Z',
        'schedule_end_at': '2026-08-31T20:00:00Z',
      },
    ],
  };
}

Map<String, dynamic> _channelRow() {
  return <String, dynamic>{
    'channel': 'mobile',
    'is_enabled': true,
    'is_visible': true,
    'show_in_navigation': true,
    'show_on_home': false,
    'sort_order': 2,
  };
}

class _Gateway implements AdminFeaturesGateway {
  _Gateway({
    List<Object>? allOutcomes,
    List<Object>? oneOutcomes,
    List<Object>? mutationOutcomes,
  }) : allOutcomes = allOutcomes ?? <Object>[_registry],
       oneOutcomes = oneOutcomes ?? <Object>[_detail],
       mutationOutcomes = mutationOutcomes ?? <Object>[true];

  final List<Object> allOutcomes;
  final List<Object> oneOutcomes;
  final List<Object> mutationOutcomes;
  int allLoadCount = 0;
  int oneLoadCount = 0;
  int mutationCount = 0;

  @override
  Future<AdminFeaturesSnapshot> loadAll() async {
    final index = allLoadCount++;
    final outcome = allOutcomes[index.clamp(0, allOutcomes.length - 1)];
    if (outcome is Future<AdminFeaturesSnapshot>) return outcome;
    if (outcome is AdminFeaturesSnapshot) return outcome;
    throw outcome;
  }

  @override
  Future<AdminFeatureDetailSnapshot> loadOne(String featureKey) async {
    final index = oneLoadCount++;
    final outcome = oneOutcomes[index.clamp(0, oneOutcomes.length - 1)];
    if (outcome is Future<AdminFeatureDetailSnapshot>) return outcome;
    if (outcome is AdminFeatureDetailSnapshot) return outcome;
    throw outcome;
  }

  Future<void> _mutate() async {
    final index = mutationCount++;
    final outcome =
        mutationOutcomes[index.clamp(0, mutationOutcomes.length - 1)];
    if (outcome is Future<void>) return outcome;
    if (outcome == true) return;
    throw outcome;
  }

  @override
  Future<void> setGlobalEnabled(String featureId, bool enabled) => _mutate();

  @override
  Future<void> setVisibility(String featureId, String visibility) => _mutate();

  @override
  Future<void> updateChannel(
    String featureId,
    String channel,
    Map<String, dynamic> updates,
  ) => _mutate();

  @override
  Future<void> updateRules(String featureId, Map<String, dynamic> updates) =>
      _mutate();
}
