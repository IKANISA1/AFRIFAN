import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a confirmed challenge operations snapshot', () async {
    final gateway = _QueueGateway(loadOutcomes: <Object>[_items]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    final value = await container.read(adminChallengesProvider.future);

    expect(value.items.single.homeTeam, 'Rayon');
    expect(value.items.single.canRetrySettlement, isTrue);
    expect(value.phase, AdminChallengesPhase.ready);
  });

  test('classifies offline before requesting private challenge data', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _QueueGateway(loadOutcomes: <Object>[_items]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminChallengesProvider.future),
      throwsA(
        isA<AdminChallengesFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminChallengesFailureKind.offline,
        ),
      ),
    );
    expect(gateway.loadCount, 0);
  });

  test('bounds challenge loads with a security timeout', () async {
    final gateway = _QueueGateway(
      loadOutcomes: <Object>[Completer<List<AdminChallengeItem>>().future],
    );
    final container = _container(
      gateway,
      loadTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminChallengesProvider.future),
      throwsA(
        isA<AdminChallengesFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminChallengesFailureKind.securityTimeout,
        ),
      ),
    );
  });

  test(
    'retains confirmed items and locks actions after refresh conflict',
    () async {
      final gateway = _QueueGateway(
        loadOutcomes: <Object>[
          _items,
          const AdminChallengesFailure(AdminChallengesFailureKind.conflict),
        ],
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      await container.read(adminChallengesProvider.future);

      await container.read(adminChallengesProvider.notifier).refresh();
      final value = container.read(adminChallengesProvider).requireValue;

      expect(value.items, hasLength(1));
      expect(value.phase, AdminChallengesPhase.degraded);
      expect(value.failure?.kind, AdminChallengesFailureKind.conflict);
      expect(value.actionsEnabled, isFalse);
    },
  );

  test('permission denial clears previously confirmed private items', () async {
    final gateway = _QueueGateway(
      loadOutcomes: <Object>[
        _items,
        const AdminChallengesFailure(
          AdminChallengesFailureKind.permissionDenied,
        ),
      ],
    );
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminChallengesProvider.future);

    await container.read(adminChallengesProvider.notifier).refresh();
    final value = container.read(adminChallengesProvider).requireValue;

    expect(value.items, isEmpty);
    expect(value.failure?.kind, AdminChallengesFailureKind.permissionDenied);
  });

  test(
    'uncertain retry timeout retains data and blocks duplicate mutation',
    () async {
      final gateway = _QueueGateway(
        loadOutcomes: <Object>[_items],
        retryOutcomes: <Object>[Completer<AdminChallengeRetryResult>().future],
      );
      final container = _container(
        gateway,
        mutationTimeout: const Duration(milliseconds: 1),
      );
      addTearDown(container.dispose);
      await container.read(adminChallengesProvider.future);

      final result = await container
          .read(adminChallengesProvider.notifier)
          .retrySettlement(_challengeId);
      final value = container.read(adminChallengesProvider).requireValue;

      expect(result, isNull);
      expect(value.items, hasLength(1));
      expect(value.mutationOutcomeUnconfirmed, isTrue);
      expect(value.failure?.kind, AdminChallengesFailureKind.securityTimeout);
      expect(value.actionsEnabled, isFalse);
    },
  );

  test('strict projection rejects malformed or oversized private payloads', () {
    expect(
      () => AdminChallengeItem.fromJson(<String, dynamic>{
        ..._challengeJson,
        'creator_name': List<String>.filled(81, 'x').join(),
        'private_metadata': <String, dynamic>{'service_role': 'private-secret'},
      }),
      throwsFormatException,
    );
    final item = AdminChallengeItem.fromJson(<String, dynamic>{
      ..._challengeJson,
      'private_metadata': <String, dynamic>{'service_role': 'private-secret'},
    });
    expect(item.creatorName, 'Synthetic operator');
    expect(item.settlementState, 'Pending');
  });
}

ProviderContainer _container(
  AdminChallengesGateway gateway, {
  Duration loadTimeout = const Duration(seconds: 12),
  Duration mutationTimeout = const Duration(seconds: 12),
}) {
  return ProviderContainer(
    overrides: <Override>[
      adminChallengesGatewayProvider.overrideWithValue(gateway),
      adminChallengesLoadTimeoutProvider.overrideWithValue(loadTimeout),
      adminChallengesMutationTimeoutProvider.overrideWithValue(mutationTimeout),
    ],
  );
}

const _challengeId = '11111111-1111-4111-8111-111111111111';

final _items = <AdminChallengeItem>[
  AdminChallengeItem.fromJson(_challengeJson),
];

const _challengeJson = <String, dynamic>{
  'id': _challengeId,
  'status': 'locked',
  'creator_name': 'Synthetic operator',
  'total_pool_fet': 2400,
  'total_participants': 8,
  'void_reason': null,
  'fixture': <String, dynamic>{
    'competition_name': 'National League',
    'home_team_short_name': 'Rayon',
    'away_team_short_name': 'Police',
  },
  'settlement': null,
  'admin': <String, dynamic>{
    'settlement_state': 'pending',
    'settlement_mode': null,
    'metadata': <String, dynamic>{'private_actor': 'ignored'},
  },
  'permissions': <String, dynamic>{'can_retry_settlement': true},
};

class _QueueGateway implements AdminChallengesGateway {
  _QueueGateway({
    required this.loadOutcomes,
    this.retryOutcomes = const <Object>[
      AdminChallengeRetryResult(status: 'settled'),
    ],
  });

  final List<Object> loadOutcomes;
  final List<Object> retryOutcomes;
  int loadCount = 0;
  int retryCount = 0;

  @override
  Future<List<AdminChallengeItem>> load(AdminChallengeFilter filter) async {
    final index = loadCount++;
    final outcome = loadOutcomes[index.clamp(0, loadOutcomes.length - 1)];
    if (outcome is Future<List<AdminChallengeItem>>) return outcome;
    if (outcome is List<AdminChallengeItem>) return outcome;
    throw outcome;
  }

  @override
  Future<AdminChallengeRetryResult> retrySettlement(String challengeId) async {
    final index = retryCount++;
    final outcome = retryOutcomes[index.clamp(0, retryOutcomes.length - 1)];
    if (outcome is Future<AdminChallengeRetryResult>) return outcome;
    if (outcome is AdminChallengeRetryResult) return outcome;
    throw outcome;
  }
}
