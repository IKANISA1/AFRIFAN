import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a bounded strict match workspace', () async {
    final gateway = _Gateway(loadOutcomes: <Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    final value = await container.read(adminMatchesProvider.future);

    expect(value.matches, hasLength(2));
    expect(value.partnerId, 'partner-1');
    expect(value.visibleMatches, hasLength(2));
    expect(value.actionsEnabled, isTrue);
  });

  test('classifies offline before requesting private fixture data', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway(loadOutcomes: <Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminMatchesProvider.future),
      throwsA(
        isA<AdminMatchesFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminMatchesFailureKind.offline,
        ),
      ),
    );
    expect(gateway.loadCount, 0);
  });

  test('bounds fixture reads with a security timeout', () async {
    final gateway = _Gateway(
      loadOutcomes: <Object>[Completer<AdminMatchesSnapshot>().future],
    );
    final container = _container(
      gateway,
      loadTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminMatchesProvider.future),
      throwsA(
        isA<AdminMatchesFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminMatchesFailureKind.securityTimeout,
        ),
      ),
    );
  });

  test('filters locally without another private read', () async {
    final gateway = _Gateway(loadOutcomes: <Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminMatchesProvider.future);

    container
        .read(adminMatchesProvider.notifier)
        .selectFilter(AdminMatchFilter.live);

    final value = container.read(adminMatchesProvider).requireValue;
    expect(value.visibleMatches.single.id, 'match-2');
    expect(gateway.loadCount, 1);
  });

  test('permission denial clears retained fixture information', () async {
    final gateway = _Gateway(
      loadOutcomes: <Object>[
        _workspace,
        const AdminMatchesFailure(AdminMatchesFailureKind.permissionDenied),
      ],
    );
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminMatchesProvider.future);

    await container.read(adminMatchesProvider.notifier).refresh();

    final value = container.read(adminMatchesProvider).requireValue;
    expect(value.matches, isEmpty);
    expect(value.failure?.kind, AdminMatchesFailureKind.permissionDenied);
  });

  test('successful mutation reloads confirmed fixture information', () async {
    final updated = AdminMatchesSnapshot.fromRaw(<Map<String, dynamic>>[
      _matchRow(awayTeam: 'Kiyovu', isOnSale: true),
    ]);
    final gateway = _Gateway(
      loadOutcomes: <Object>[_workspace, updated],
      saveOutcomes: <Object>[true],
    );
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminMatchesProvider.future);

    final changed = await container
        .read(adminMatchesProvider.notifier)
        .save(_draft(), matchId: 'match-1');

    expect(changed, isTrue);
    expect(
      container.read(adminMatchesProvider).requireValue.matches.single.awayTeam,
      'Kiyovu',
    );
    expect(gateway.saveCount, 1);
    expect(gateway.loadCount, 2);
  });

  test('mutation timeout retains data and blocks duplicate mutation', () async {
    final pending = Completer<void>();
    final gateway = _Gateway(
      loadOutcomes: <Object>[_workspace],
      saveOutcomes: <Object>[pending.future],
    );
    final container = _container(
      gateway,
      mutationTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);
    await container.read(adminMatchesProvider.future);

    final changed = await container
        .read(adminMatchesProvider.notifier)
        .save(_draft(), matchId: 'match-1');

    final value = container.read(adminMatchesProvider).requireValue;
    expect(changed, isFalse);
    expect(value.matches, hasLength(2));
    expect(value.mutationOutcomeUnconfirmed, isTrue);
    expect(value.actionsEnabled, isFalse);
    expect(
      await container
          .read(adminMatchesProvider.notifier)
          .save(_draft(), matchId: 'match-1'),
      isFalse,
    );
    expect(gateway.saveCount, 1);
  });

  test('strict projection rejects oversized, duplicate and malformed data', () {
    expect(
      () => AdminMatchesSnapshot.fromRaw(
        List<Map<String, dynamic>>.generate(
          201,
          (index) => _matchRow(id: 'match-$index'),
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => AdminMatchesSnapshot.fromRaw(<Map<String, dynamic>>[
        _matchRow(),
        _matchRow(awayTeam: 'Kiyovu'),
      ]),
      throwsFormatException,
    );
    expect(
      () => AdminMatchesSnapshot.fromRaw(<Map<String, dynamic>>[
        <String, dynamic>{..._matchRow(), 'capacity': 'private-capacity'},
      ]),
      throwsFormatException,
    );
  });

  test('nullable live minute is normalized without weakening other fields', () {
    final snapshot = AdminMatchesSnapshot.fromRaw(<Map<String, dynamic>>[
      _matchRow(liveMinute: null),
    ]);

    expect(snapshot.matches.single.liveMinute, 0);
    expect(
      () => AdminMatchesSnapshot.fromRaw(<Map<String, dynamic>>[
        <String, dynamic>{..._matchRow(), 'partner_id': null},
      ]),
      throwsFormatException,
    );
  });

  test('private extras are ignored by the bounded match model', () {
    final snapshot = AdminMatchesSnapshot.fromRaw(<Map<String, dynamic>>[
      <String, dynamic>{
        ..._matchRow(),
        'created_by': 'private-admin-id',
        'live_stats': <String, dynamic>{'secret': 'private-value'},
      },
    ]);

    expect(snapshot.matches.single.awayTeam, 'APR FC');
    expect(snapshot.toString(), isNot(contains('private-admin-id')));
    expect(snapshot.toString(), isNot(contains('private-value')));
  });
}

ProviderContainer _container(
  AdminMatchesGateway gateway, {
  Duration loadTimeout = const Duration(seconds: 12),
  Duration mutationTimeout = const Duration(seconds: 12),
}) {
  return ProviderContainer(
    overrides: <Override>[
      adminMatchesGatewayProvider.overrideWithValue(gateway),
      adminMatchesLoadTimeoutProvider.overrideWithValue(loadTimeout),
      adminMatchesMutationTimeoutProvider.overrideWithValue(mutationTimeout),
    ],
  );
}

final _workspace = AdminMatchesSnapshot.fromRaw(<Map<String, dynamic>>[
  _matchRow(),
  _matchRow(
    id: 'match-2',
    awayTeam: 'Police FC',
    status: 'live',
    liveMinute: 67,
    homeScore: 2,
    awayScore: 1,
  ),
]);

Map<String, dynamic> _matchRow({
  String id = 'match-1',
  String awayTeam = 'APR FC',
  bool isOnSale = false,
  String status = 'scheduled',
  int? liveMinute = 0,
  int homeScore = 0,
  int awayScore = 0,
}) {
  return <String, dynamic>{
    'id': id,
    'partner_id': 'partner-1',
    'home_team': 'Rayon Sports',
    'away_team': awayTeam,
    'competition': 'National League',
    'venue': 'Kigali Pelé Stadium',
    'match_date': '2026-08-12',
    'kickoff_time': '18:00:00',
    'is_on_sale': isOnSale,
    'ticket_general_price': 3000,
    'ticket_vip_price': 30000,
    'capacity': 18000,
    'sold_count': 7200,
    'match_status': status,
    'home_score': homeScore,
    'away_score': awayScore,
    'live_minute': liveMinute,
    'match_summary': 'Confirmed fixture information.',
  };
}

Map<String, dynamic> _draft() {
  return <String, dynamic>{
    'partner_id': 'partner-1',
    'home_team': 'Rayon Sports',
    'away_team': 'Kiyovu',
    'competition': 'National League',
    'venue': 'Kigali Pelé Stadium',
    'match_date': '2026-08-14',
    'kickoff_time': '18:00:00',
    'is_on_sale': true,
    'ticket_general_price': 3000,
    'ticket_vip_price': 30000,
    'capacity': 18000,
    'match_status': 'scheduled',
    'home_score': 0,
    'away_score': 0,
    'live_minute': 0,
    'match_summary': '',
  };
}

class _Gateway implements AdminMatchesGateway {
  _Gateway({List<Object>? loadOutcomes, List<Object>? saveOutcomes})
    : loadOutcomes = loadOutcomes ?? <Object>[_workspace],
      saveOutcomes = saveOutcomes ?? <Object>[true];

  final List<Object> loadOutcomes;
  final List<Object> saveOutcomes;
  int loadCount = 0;
  int saveCount = 0;

  @override
  Future<AdminMatchesSnapshot> load() async {
    final index = loadCount++;
    final outcome = loadOutcomes[index.clamp(0, loadOutcomes.length - 1)];
    if (outcome is Future<AdminMatchesSnapshot>) return outcome;
    if (outcome is AdminMatchesSnapshot) return outcome;
    throw outcome;
  }

  @override
  Future<void> save(AdminMatchDraft draft, {String? matchId}) async {
    final index = saveCount++;
    final outcome = saveOutcomes[index.clamp(0, saveOutcomes.length - 1)];
    if (outcome is Future<void>) return outcome;
    if (outcome == true) return;
    throw outcome;
  }
}
