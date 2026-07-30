import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a bounded strict settlement workspace', () async {
    final gateway = _Gateway(loadOutcomes: <Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    final value = await container.read(adminSettlementProvider.future);

    expect(value.fixtures, hasLength(2));
    expect(value.fixtures.first.homeTeam.name, 'Rayon Sports');
    expect(value.fixtures.last.homeScore, 2);
    expect(value.actionsEnabled, isTrue);
  });

  test('classifies offline before requesting private fixture data', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway(loadOutcomes: <Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminSettlementProvider.future),
      throwsA(
        isA<AdminSettlementFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminSettlementFailureKind.offline,
        ),
      ),
    );
    expect(gateway.loadCount, 0);
  });

  test('bounds private reads with a security timeout', () async {
    final gateway = _Gateway(
      loadOutcomes: <Object>[Completer<AdminSettlementSnapshot>().future],
    );
    final container = _container(
      gateway,
      loadTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminSettlementProvider.future),
      throwsA(
        isA<AdminSettlementFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminSettlementFailureKind.securityTimeout,
        ),
      ),
    );
  });

  test('permission denial clears retained fixture information', () async {
    final gateway = _Gateway(
      loadOutcomes: <Object>[
        _workspace,
        const AdminSettlementFailure(
          AdminSettlementFailureKind.permissionDenied,
        ),
      ],
    );
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminSettlementProvider.future);

    await container.read(adminSettlementProvider.notifier).refresh();

    final value = container.read(adminSettlementProvider).requireValue;
    expect(value.fixtures, isEmpty);
    expect(value.failure?.kind, AdminSettlementFailureKind.permissionDenied);
    expect(value.actionsEnabled, isFalse);
  });

  test(
    'recoverable conflict retains confirmed fixtures and pauses actions',
    () async {
      final gateway = _Gateway(
        loadOutcomes: <Object>[
          _workspace,
          const AdminSettlementFailure(AdminSettlementFailureKind.conflict),
        ],
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      await container.read(adminSettlementProvider.future);

      await container.read(adminSettlementProvider.notifier).refresh();

      final value = container.read(adminSettlementProvider).requireValue;
      expect(value.fixtures, hasLength(2));
      expect(value.failure?.kind, AdminSettlementFailureKind.conflict);
      expect(value.actionsEnabled, isFalse);
    },
  );

  test('successful settlement reloads confirmed fixture information', () async {
    final confirmed = AdminSettlementSnapshot.fromRaw(<Object>[
      _fixture(
        id: _scheduledFixtureId,
        status: 'finished',
        homeScore: 3,
        awayScore: 1,
      ),
    ]);
    final gateway = _Gateway(
      loadOutcomes: <Object>[_workspace, confirmed],
      settleOutcomes: <Object>[_receipt],
    );
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminSettlementProvider.future);

    final receipt = await container
        .read(adminSettlementProvider.notifier)
        .settle(_draft());

    expect(receipt?.score, '3-1');
    expect(gateway.settleCount, 1);
    expect(gateway.loadCount, 2);
    expect(
      container
          .read(adminSettlementProvider)
          .requireValue
          .fixtures
          .single
          .status,
      'finished',
    );
  });

  test(
    'mutation timeout retains data and blocks duplicate settlement',
    () async {
      final pending = Completer<AdminSettlementReceipt>();
      final gateway = _Gateway(
        loadOutcomes: <Object>[_workspace],
        settleOutcomes: <Object>[pending.future],
      );
      final container = _container(
        gateway,
        mutationTimeout: const Duration(milliseconds: 1),
      );
      addTearDown(container.dispose);
      await container.read(adminSettlementProvider.future);

      expect(
        await container.read(adminSettlementProvider.notifier).settle(_draft()),
        isNull,
      );

      final value = container.read(adminSettlementProvider).requireValue;
      expect(value.fixtures, hasLength(2));
      expect(value.mutationOutcomeUnconfirmed, isTrue);
      expect(value.actionsEnabled, isFalse);
      expect(
        await container.read(adminSettlementProvider.notifier).settle(_draft()),
        isNull,
      );
      expect(gateway.settleCount, 1);
    },
  );

  test('strict projection rejects oversized duplicate and malformed data', () {
    expect(
      () => AdminSettlementSnapshot.fromRaw(
        List<Map<String, dynamic>>.generate(
          101,
          (index) => _fixture(
            id: '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          ),
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => AdminSettlementSnapshot.fromRaw(<Object>[
        _fixture(),
        _fixture(status: 'live'),
      ]),
      throwsFormatException,
    );
    expect(
      () => AdminSettlementSnapshot.fromRaw(<Object>[
        <String, dynamic>{..._fixture(), 'home_score': 1},
      ]),
      throwsFormatException,
    );
  });

  test('draft enforces score pairing and half-time limits', () {
    expect(
      () => AdminSettlementDraft.fromRaw(<String, dynamic>{
        'fixture_id': _scheduledFixtureId,
        'home_score': 3,
        'away_score': 1,
        'half_time_home_score': 1,
      }),
      throwsFormatException,
    );
    expect(
      () => AdminSettlementDraft.fromRaw(<String, dynamic>{
        ..._draft(),
        'half_time_home_score': 4,
        'half_time_away_score': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => AdminSettlementDraft.fromRaw(<String, dynamic>{
        ..._draft(),
        'home_score': 100,
      }),
      throwsFormatException,
    );
  });

  test(
    'cannot settle a finished fixture or accept a mismatched receipt',
    () async {
      final gateway = _Gateway(
        loadOutcomes: <Object>[_workspace],
        settleOutcomes: <Object>[
          const AdminSettlementReceipt(
            fixtureId: _finishedFixtureId,
            score: '3-1',
            marketsSettled: 12,
            totalWon: 7,
            totalLost: 5,
          ),
        ],
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      await container.read(adminSettlementProvider.future);

      await expectLater(
        () => container
            .read(adminSettlementProvider.notifier)
            .settle(_draft(fixtureId: _finishedFixtureId)),
        throwsFormatException,
      );
      expect(
        await container.read(adminSettlementProvider.notifier).settle(_draft()),
        isNull,
      );
      expect(gateway.settleCount, 1);
      expect(
        container.read(adminSettlementProvider).requireValue.failure?.kind,
        AdminSettlementFailureKind.unknown,
      );
    },
  );

  test('private extras are ignored by bounded fixture and receipt models', () {
    final snapshot = AdminSettlementSnapshot.fromRaw(<Object>[
      <String, dynamic>{
        ..._fixture(),
        'created_by': 'private-admin-id',
        'provider_debug': <String, dynamic>{'secret': 'private-value'},
      },
    ]);
    final receipt = AdminSettlementReceipt.fromRaw(<String, dynamic>{
      ..._receiptRaw,
      'actor_id': 'private-admin-id',
      'provider_detail': 'private-value',
    });

    expect(snapshot.fixtures.single.awayTeam.name, 'APR FC');
    expect(receipt.marketsSettled, 12);
    expect(snapshot.toString(), isNot(contains('private-admin-id')));
    expect(receipt.toString(), isNot(contains('private-value')));
  });
}

ProviderContainer _container(
  AdminSettlementGateway gateway, {
  Duration loadTimeout = const Duration(seconds: 12),
  Duration mutationTimeout = const Duration(seconds: 12),
}) {
  return ProviderContainer(
    overrides: <Override>[
      adminSettlementGatewayProvider.overrideWithValue(gateway),
      adminSettlementLoadTimeoutProvider.overrideWithValue(loadTimeout),
      adminSettlementMutationTimeoutProvider.overrideWithValue(mutationTimeout),
    ],
  );
}

const _scheduledFixtureId = '11111111-1111-4111-8111-111111111111';
const _finishedFixtureId = '55555555-5555-4555-8555-555555555555';

final _workspace = AdminSettlementSnapshot.fromRaw(<Object>[
  _fixture(),
  _fixture(
    id: _finishedFixtureId,
    status: 'finished',
    homeScore: 2,
    awayScore: 1,
  ),
]);

Map<String, dynamic> _fixture({
  String id = _scheduledFixtureId,
  String status = 'scheduled',
  int? homeScore,
  int? awayScore,
}) {
  return <String, dynamic>{
    'id': id,
    'status': status,
    'kickoff_at': '2026-08-12T16:00:00Z',
    'stage_name': 'Regular season',
    'group_name': null,
    'venue_city': 'Kigali',
    'home_score': homeScore,
    'away_score': awayScore,
    'home_team': const <String, dynamic>{
      'id': '22222222-2222-4222-8222-222222222222',
      'name': 'Rayon Sports',
      'short_name': 'RAY',
    },
    'away_team': const <String, dynamic>{
      'id': '33333333-3333-4333-8333-333333333333',
      'name': 'APR FC',
      'short_name': 'APR',
    },
    'competition': const <String, dynamic>{
      'id': '44444444-4444-4444-8444-444444444444',
      'name': 'Rwanda Premier League',
      'short_name': 'RPL',
    },
  };
}

Map<String, dynamic> _draft({String fixtureId = _scheduledFixtureId}) {
  return <String, dynamic>{
    'fixture_id': fixtureId,
    'home_score': 3,
    'away_score': 1,
    'half_time_home_score': 1,
    'half_time_away_score': 0,
  };
}

const _receiptRaw = <String, dynamic>{
  'status': 'success',
  'fixture_id': _scheduledFixtureId,
  'score': '3-1',
  'markets_settled': 12,
  'total_won': 7,
  'total_lost': 5,
};

final _receipt = AdminSettlementReceipt.fromRaw(_receiptRaw);

class _Gateway implements AdminSettlementGateway {
  _Gateway({List<Object>? loadOutcomes, List<Object>? settleOutcomes})
    : loadOutcomes = loadOutcomes ?? <Object>[_workspace],
      settleOutcomes = settleOutcomes ?? <Object>[_receipt];

  final List<Object> loadOutcomes;
  final List<Object> settleOutcomes;
  int loadCount = 0;
  int settleCount = 0;

  @override
  Future<AdminSettlementSnapshot> load() async {
    final index = loadCount++;
    final outcome = loadOutcomes[index.clamp(0, loadOutcomes.length - 1)];
    if (outcome is Future<AdminSettlementSnapshot>) return outcome;
    if (outcome is AdminSettlementSnapshot) return outcome;
    throw outcome;
  }

  @override
  Future<AdminSettlementReceipt> settle(AdminSettlementDraft draft) async {
    final index = settleCount++;
    final outcome = settleOutcomes[index.clamp(0, settleOutcomes.length - 1)];
    if (outcome is Future<AdminSettlementReceipt>) return outcome;
    if (outcome is AdminSettlementReceipt) return outcome;
    throw outcome;
  }
}
