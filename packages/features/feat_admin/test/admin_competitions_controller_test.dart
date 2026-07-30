import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a confirmed bounded competition workspace', () async {
    final gateway = _QueueGateway(<Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    final value = await container.read(adminCompetitionsProvider.future);

    expect(value.competitions.single.name, 'National League');
    expect(value.seasons.single.label, '2025/2026');
    expect(value.actionsEnabled, isTrue);
  });

  test('classifies offline before requesting private records', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _QueueGateway(<Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminCompetitionsProvider.future),
      throwsA(
        isA<AdminCompetitionsFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminCompetitionsFailureKind.offline,
        ),
      ),
    );
    expect(gateway.loadCount, 0);
  });

  test('bounds loads with a security timeout', () async {
    final gateway = _QueueGateway(<Object>[
      Completer<AdminCompetitionsSnapshot>().future,
    ]);
    final container = _container(
      gateway,
      loadTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(adminCompetitionsProvider.future),
      throwsA(
        isA<AdminCompetitionsFailure>().having(
          (failure) => failure.kind,
          'kind',
          AdminCompetitionsFailureKind.securityTimeout,
        ),
      ),
    );
  });

  test('retains confirmed records and locks actions after conflict', () async {
    final gateway = _QueueGateway(<Object>[
      _workspace,
      const AdminCompetitionsFailure(AdminCompetitionsFailureKind.conflict),
    ]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminCompetitionsProvider.future);

    await container.read(adminCompetitionsProvider.notifier).refresh();
    final value = container.read(adminCompetitionsProvider).requireValue;

    expect(value.competitions, hasLength(1));
    expect(value.failure?.kind, AdminCompetitionsFailureKind.conflict);
    expect(value.actionsEnabled, isFalse);
  });

  test('permission denial clears competitions and seasons', () async {
    final gateway = _QueueGateway(<Object>[
      _workspace,
      const AdminCompetitionsFailure(
        AdminCompetitionsFailureKind.permissionDenied,
      ),
    ]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminCompetitionsProvider.future);

    await container.read(adminCompetitionsProvider.notifier).refresh();
    final value = container.read(adminCompetitionsProvider).requireValue;

    expect(value.competitions, isEmpty);
    expect(value.seasons, isEmpty);
    expect(value.failure?.kind, AdminCompetitionsFailureKind.permissionDenied);
  });

  test(
    'filters confirmed records locally without another private read',
    () async {
      final gateway = _QueueGateway(<Object>[_workspace]);
      final container = _container(gateway);
      addTearDown(container.dispose);
      await container.read(adminCompetitionsProvider.future);

      container
          .read(adminCompetitionsProvider.notifier)
          .selectRegion(AdminCompetitionRegionFilter.europe);
      final value = container.read(adminCompetitionsProvider).requireValue;

      expect(value.visibleCompetitions, isEmpty);
      expect(value.regionFilter, AdminCompetitionRegionFilter.europe);
      expect(gateway.loadCount, 1);
    },
  );

  test('offline mutation retains data and never invokes gateway', () async {
    final gateway = _QueueGateway(<Object>[_workspace]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    await container.read(adminCompetitionsProvider.future);
    ConnectivityService.setOnlineForTest(false);

    final saved = await container
        .read(adminCompetitionsProvider.notifier)
        .setCompetitionActive('competition-1', false);
    final value = container.read(adminCompetitionsProvider).requireValue;

    expect(saved, isFalse);
    expect(gateway.mutationCount, 0);
    expect(value.competitions, hasLength(1));
    expect(value.failure?.kind, AdminCompetitionsFailureKind.offline);
  });

  test('timed-out mutation blocks duplicate updates until refresh', () async {
    final gateway = _QueueGateway(<Object>[
      _workspace,
    ], mutationOutcome: Completer<void>().future);
    final container = _container(
      gateway,
      mutationTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(container.dispose);
    await container.read(adminCompetitionsProvider.future);

    final first = await container
        .read(adminCompetitionsProvider.notifier)
        .setCompetitionActive('competition-1', false);
    final second = await container
        .read(adminCompetitionsProvider.notifier)
        .setCompetitionActive('competition-1', false);
    final value = container.read(adminCompetitionsProvider).requireValue;

    expect(first, isFalse);
    expect(second, isFalse);
    expect(gateway.mutationCount, 1);
    expect(value.mutationOutcomeUnconfirmed, isTrue);
    expect(value.actionsEnabled, isFalse);
  });

  test('strict projection rejects oversized and orphaned season records', () {
    expect(
      () => AdminCompetitionsSnapshot.fromRawCollections(
        List<Map<String, dynamic>>.generate(
          201,
          (index) => _competitionRow(id: 'competition-$index'),
        ),
        const <Object>[],
      ),
      throwsFormatException,
    );
    expect(
      () => AdminCompetitionsSnapshot.fromRawCollections(
        <Map<String, dynamic>>[_competitionRow()],
        <Map<String, dynamic>>[
          _seasonRow(competitionId: 'private-competition'),
        ],
      ),
      throwsFormatException,
    );
    expect(
      AdminCompetitionItem.fromJson({
        ..._competitionRow(),
        'private_actor': 'private-user-991',
      }).name,
      'National League',
    );
  });
}

ProviderContainer _container(
  AdminCompetitionsGateway gateway, {
  Duration loadTimeout = const Duration(seconds: 12),
  Duration mutationTimeout = const Duration(seconds: 12),
}) {
  return ProviderContainer(
    overrides: <Override>[
      adminCompetitionsGatewayProvider.overrideWithValue(gateway),
      adminCompetitionsLoadTimeoutProvider.overrideWithValue(loadTimeout),
      adminCompetitionsMutationTimeoutProvider.overrideWithValue(
        mutationTimeout,
      ),
    ],
  );
}

final _workspace = AdminCompetitionsSnapshot.fromRawCollections(
  <Map<String, dynamic>>[_competitionRow()],
  <Map<String, dynamic>>[_seasonRow()],
);

Map<String, dynamic> _competitionRow({String id = 'competition-1'}) {
  return <String, dynamic>{
    'id': id,
    'slug': 'national-league',
    'name': 'National League',
    'short_name': 'NL',
    'competition_kind': 'league',
    'region': 'africa',
    'country_code': 'RW',
    'country_name': 'Rwanda',
    'organizer': 'League Authority',
    'gender': 'men',
    'format_notes': 'Home and away schedule',
    'is_active': true,
  };
}

Map<String, dynamic> _seasonRow({String competitionId = 'competition-1'}) {
  return <String, dynamic>{
    'id': 'season-1',
    'competition_id': competitionId,
    'slug': 'national-league-2025-2026',
    'label': '2025/2026',
    'year_start': 2025,
    'year_end': 2026,
    'status': 'active',
    'is_active': true,
  };
}

class _QueueGateway implements AdminCompetitionsGateway {
  _QueueGateway(this.outcomes, {this.mutationOutcome});

  final List<Object> outcomes;
  final Object? mutationOutcome;
  int loadCount = 0;
  int mutationCount = 0;

  @override
  Future<AdminCompetitionsSnapshot> load() async {
    final index = loadCount++;
    final outcome = outcomes[index.clamp(0, outcomes.length - 1)];
    if (outcome is Future<AdminCompetitionsSnapshot>) return outcome;
    if (outcome is AdminCompetitionsSnapshot) return outcome;
    throw outcome;
  }

  Future<void> _mutate() async {
    mutationCount += 1;
    final outcome = mutationOutcome;
    if (outcome is Future<void>) return outcome;
    if (outcome is Object) throw outcome;
  }

  @override
  Future<void> createSeason(Map<String, dynamic> payload) => _mutate();

  @override
  Future<void> saveCompetition(
    Map<String, dynamic> payload, {
    String? competitionId,
  }) => _mutate();

  @override
  Future<void> setCompetitionActive(String competitionId, bool isActive) =>
      _mutate();

  @override
  Future<void> setSeasonActive(String seasonId, bool isActive) => _mutate();
}
