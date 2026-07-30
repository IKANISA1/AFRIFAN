import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';
import 'repositories/admin_repository.dart';

enum AdminSettlementPhase { ready, degraded }

enum AdminSettlementFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class AdminSettlementFailure implements Exception {
  const AdminSettlementFailure(this.kind);

  final AdminSettlementFailureKind kind;

  static AdminSettlementFailure fromError(Object error) {
    if (error is AdminSettlementFailure) return error;
    if (error is TimeoutException) {
      return const AdminSettlementFailure(
        AdminSettlementFailureKind.securityTimeout,
      );
    }
    final value = error.toString().toLowerCase();
    if (value.contains('socketexception') ||
        value.contains('failed host lookup') ||
        value.contains('network is unreachable') ||
        value.contains('connection refused') ||
        value.contains('offline')) {
      return const AdminSettlementFailure(AdminSettlementFailureKind.offline);
    }
    if (value.contains('permission') ||
        value.contains('forbidden') ||
        value.contains('unauthorized') ||
        value.contains('admin access required') ||
        value.contains('row-level security') ||
        value.contains('rls') ||
        value.contains('42501')) {
      return const AdminSettlementFailure(
        AdminSettlementFailureKind.permissionDenied,
      );
    }
    if (value.contains('conflict') ||
        value.contains('already settled') ||
        value.contains('not confirmed') ||
        value.contains('409')) {
      return const AdminSettlementFailure(AdminSettlementFailureKind.conflict);
    }
    return const AdminSettlementFailure(AdminSettlementFailureKind.unknown);
  }

  @override
  String toString() => 'AdminSettlementFailure(${kind.name})';
}

class AdminSettlementTeam {
  const AdminSettlementTeam({
    required this.id,
    required this.name,
    required this.shortName,
  });

  factory AdminSettlementTeam.fromRaw(Object? raw) {
    final map = _strictMap(raw, 'settlement team');
    return AdminSettlementTeam(
      id: _requiredUuid(map['id'], field: 'team.id'),
      name: _requiredString(map['name'], field: 'team.name', max: 120),
      shortName:
          _optionalString(
            map['short_name'],
            field: 'team.short_name',
            max: 24,
          ) ??
          _requiredString(map['name'], field: 'team.name', max: 120),
    );
  }

  final String id;
  final String name;
  final String shortName;
}

class AdminSettlementCompetition {
  const AdminSettlementCompetition({
    required this.id,
    required this.name,
    required this.shortName,
  });

  factory AdminSettlementCompetition.fromRaw(Object? raw) {
    final map = _strictMap(raw, 'settlement competition');
    return AdminSettlementCompetition(
      id: _requiredUuid(map['id'], field: 'competition.id'),
      name: _requiredString(map['name'], field: 'competition.name', max: 120),
      shortName:
          _optionalString(
            map['short_name'],
            field: 'competition.short_name',
            max: 32,
          ) ??
          _requiredString(map['name'], field: 'competition.name', max: 120),
    );
  }

  final String id;
  final String name;
  final String shortName;
}

class AdminSettlementFixture {
  const AdminSettlementFixture({
    required this.id,
    required this.status,
    required this.kickoffAt,
    required this.homeTeam,
    required this.awayTeam,
    required this.competition,
    this.stageName,
    this.groupName,
    this.venueCity,
    this.homeScore,
    this.awayScore,
  });

  factory AdminSettlementFixture.fromRaw(Map<String, dynamic> raw) {
    final status = _requiredEnum(
      raw['status'],
      field: 'fixture.status',
      allowed: const <String>{
        'scheduled',
        'live',
        'finished',
        'postponed',
        'cancelled',
      },
    );
    final homeScore = _optionalScore(raw['home_score'], 'fixture.home_score');
    final awayScore = _optionalScore(raw['away_score'], 'fixture.away_score');
    if ((homeScore == null) != (awayScore == null) ||
        (status == 'finished' && homeScore == null)) {
      throw const FormatException('Invalid fixture score.');
    }
    return AdminSettlementFixture(
      id: _requiredUuid(raw['id'], field: 'fixture.id'),
      status: status,
      kickoffAt: _requiredDate(raw['kickoff_at'], field: 'fixture.kickoff_at'),
      homeTeam: AdminSettlementTeam.fromRaw(raw['home_team']),
      awayTeam: AdminSettlementTeam.fromRaw(raw['away_team']),
      competition: AdminSettlementCompetition.fromRaw(raw['competition']),
      stageName: _optionalString(
        raw['stage_name'],
        field: 'fixture.stage_name',
        max: 80,
      ),
      groupName: _optionalString(
        raw['group_name'],
        field: 'fixture.group_name',
        max: 80,
      ),
      venueCity: _optionalString(
        raw['venue_city'],
        field: 'fixture.venue_city',
        max: 80,
      ),
      homeScore: homeScore,
      awayScore: awayScore,
    );
  }

  final String id;
  final String status;
  final DateTime kickoffAt;
  final AdminSettlementTeam homeTeam;
  final AdminSettlementTeam awayTeam;
  final AdminSettlementCompetition competition;
  final String? stageName;
  final String? groupName;
  final String? venueCity;
  final int? homeScore;
  final int? awayScore;

  bool get canSettle => status == 'scheduled' || status == 'live';
}

class AdminSettlementDraft {
  const AdminSettlementDraft({
    required this.fixtureId,
    required this.homeScore,
    required this.awayScore,
    this.halfTimeHomeScore,
    this.halfTimeAwayScore,
  });

  factory AdminSettlementDraft.fromRaw(Map<String, dynamic> raw) {
    final fixtureId = _requiredUuid(
      raw['fixture_id'],
      field: 'settlement.fixture_id',
    );
    final homeScore = _requiredScore(
      raw['home_score'],
      'settlement.home_score',
    );
    final awayScore = _requiredScore(
      raw['away_score'],
      'settlement.away_score',
    );
    final halfTimeHomeScore = _optionalScore(
      raw['half_time_home_score'],
      'settlement.half_time_home_score',
    );
    final halfTimeAwayScore = _optionalScore(
      raw['half_time_away_score'],
      'settlement.half_time_away_score',
    );
    if ((halfTimeHomeScore == null) != (halfTimeAwayScore == null)) {
      throw const FormatException('Both half-time scores are required.');
    }
    if (halfTimeHomeScore != null &&
        (halfTimeHomeScore > homeScore || halfTimeAwayScore! > awayScore)) {
      throw const FormatException('Invalid half-time score.');
    }
    return AdminSettlementDraft(
      fixtureId: fixtureId,
      homeScore: homeScore,
      awayScore: awayScore,
      halfTimeHomeScore: halfTimeHomeScore,
      halfTimeAwayScore: halfTimeAwayScore,
    );
  }

  final String fixtureId;
  final int homeScore;
  final int awayScore;
  final int? halfTimeHomeScore;
  final int? halfTimeAwayScore;

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'fixture_id': fixtureId,
    'home_score': homeScore,
    'away_score': awayScore,
    if (halfTimeHomeScore != null) 'half_time_home_score': halfTimeHomeScore,
    if (halfTimeAwayScore != null) 'half_time_away_score': halfTimeAwayScore,
  };
}

class AdminSettlementReceipt {
  const AdminSettlementReceipt({
    required this.fixtureId,
    required this.score,
    required this.marketsSettled,
    required this.totalWon,
    required this.totalLost,
  });

  factory AdminSettlementReceipt.fromRaw(Object? raw) {
    final map = _strictMap(raw, 'settlement receipt');
    if (map['status'] != 'success') {
      throw const FormatException('Invalid settlement receipt.');
    }
    return AdminSettlementReceipt(
      fixtureId: _requiredUuid(map['fixture_id'], field: 'receipt.fixture_id'),
      score: _requiredString(map['score'], field: 'receipt.score', max: 12),
      marketsSettled: _boundedInt(
        map['markets_settled'],
        field: 'receipt.markets_settled',
        maximum: 1000,
      ),
      totalWon: _boundedInt(
        map['total_won'],
        field: 'receipt.total_won',
        maximum: 10000000,
      ),
      totalLost: _boundedInt(
        map['total_lost'],
        field: 'receipt.total_lost',
        maximum: 10000000,
      ),
    );
  }

  final String fixtureId;
  final String score;
  final int marketsSettled;
  final int totalWon;
  final int totalLost;
}

class AdminSettlementSnapshot {
  const AdminSettlementSnapshot({
    required this.fixtures,
    this.phase = AdminSettlementPhase.ready,
    this.failure,
    this.isMutating = false,
    this.mutationOutcomeUnconfirmed = false,
  });

  const AdminSettlementSnapshot.empty()
    : fixtures = const <AdminSettlementFixture>[],
      phase = AdminSettlementPhase.ready,
      failure = null,
      isMutating = false,
      mutationOutcomeUnconfirmed = false;

  factory AdminSettlementSnapshot.fromRaw(Object? raw) {
    if (raw is! List || raw.length > 100) {
      throw const FormatException('Invalid settlement fixtures.');
    }
    final fixtures = raw
        .map((row) {
          if (row is Map<String, dynamic>) {
            return AdminSettlementFixture.fromRaw(row);
          }
          if (row is Map) {
            return AdminSettlementFixture.fromRaw(
              Map<String, dynamic>.from(row),
            );
          }
          throw const FormatException('Invalid settlement fixture.');
        })
        .toList(growable: false);
    if (fixtures.map((fixture) => fixture.id).toSet().length !=
        fixtures.length) {
      throw const FormatException('Duplicate settlement fixture.');
    }
    return AdminSettlementSnapshot(
      fixtures: List<AdminSettlementFixture>.unmodifiable(fixtures),
    );
  }

  final List<AdminSettlementFixture> fixtures;
  final AdminSettlementPhase phase;
  final AdminSettlementFailure? failure;
  final bool isMutating;
  final bool mutationOutcomeUnconfirmed;

  bool get actionsEnabled =>
      phase == AdminSettlementPhase.ready &&
      failure == null &&
      !isMutating &&
      !mutationOutcomeUnconfirmed;

  AdminSettlementSnapshot copyWith({
    List<AdminSettlementFixture>? fixtures,
    AdminSettlementPhase? phase,
    AdminSettlementFailure? failure,
    bool clearFailure = false,
    bool? isMutating,
    bool? mutationOutcomeUnconfirmed,
  }) {
    return AdminSettlementSnapshot(
      fixtures: fixtures ?? this.fixtures,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      isMutating: isMutating ?? this.isMutating,
      mutationOutcomeUnconfirmed:
          mutationOutcomeUnconfirmed ?? this.mutationOutcomeUnconfirmed,
    );
  }
}

abstract interface class AdminSettlementGateway {
  Future<AdminSettlementSnapshot> load();

  Future<AdminSettlementReceipt> settle(AdminSettlementDraft draft);
}

class SupabaseAdminSettlementGateway implements AdminSettlementGateway {
  const SupabaseAdminSettlementGateway(this._repository);

  final AdminRepository _repository;

  Future<void> _requireAdmin() async {
    if (!await _repository.isCurrentUserAppMetadataAdmin()) {
      throw const AdminSettlementFailure(
        AdminSettlementFailureKind.permissionDenied,
      );
    }
  }

  @override
  Future<AdminSettlementSnapshot> load() async {
    await _requireAdmin();
    return AdminSettlementSnapshot.fromRaw(
      await _repository.getPredictionSettlementFixtures(),
    );
  }

  @override
  Future<AdminSettlementReceipt> settle(AdminSettlementDraft draft) async {
    await _requireAdmin();
    return AdminSettlementReceipt.fromRaw(
      await _repository.settlePredictionFixture(draft.toPayload()),
    );
  }
}

final adminSettlementGatewayProvider = Provider<AdminSettlementGateway>((ref) {
  return SupabaseAdminSettlementGateway(ref.watch(adminRepositoryProvider));
});
final adminSettlementLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);
final adminSettlementMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);
final adminSettlementEnabledProvider = Provider<bool>((ref) => true);

class AdminSettlementNotifier extends AsyncNotifier<AdminSettlementSnapshot> {
  var _busy = false;

  @override
  Future<AdminSettlementSnapshot> build() => _load();

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminSettlementSnapshot>().copyWithPrevious(
      state,
    );
    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      _applyFailure(
        AdminSettlementFailure.fromError(error),
        stackTrace,
        previous,
      );
    } finally {
      _busy = false;
    }
  }

  Future<AdminSettlementReceipt?> settle(Map<String, dynamic> raw) async {
    if (_busy) return null;
    final previous = state.valueOrNull;
    if (previous == null || !previous.actionsEnabled) return null;
    final draft = AdminSettlementDraft.fromRaw(raw);
    final target = previous.fixtures
        .where((fixture) => fixture.id == draft.fixtureId)
        .firstOrNull;
    if (target == null || !target.canSettle) {
      throw const FormatException('Fixture is not available for settlement.');
    }
    _busy = true;
    state = AsyncData(previous.copyWith(isMutating: true, clearFailure: true));
    try {
      _requireOnline();
      final receipt = await ref
          .read(adminSettlementGatewayProvider)
          .settle(draft)
          .timeout(ref.read(adminSettlementMutationTimeoutProvider));
      if (receipt.fixtureId != draft.fixtureId) {
        throw const FormatException('Invalid settlement receipt.');
      }
      state = AsyncData(await _load());
      return receipt;
    } catch (error, stackTrace) {
      final failure = AdminSettlementFailure.fromError(error);
      _applyFailure(
        failure,
        stackTrace,
        previous,
        mutationOutcomeUnconfirmed:
            failure.kind == AdminSettlementFailureKind.securityTimeout ||
            failure.kind == AdminSettlementFailureKind.conflict,
      );
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<AdminSettlementSnapshot> _load() async {
    _requireOnline();
    try {
      return await ref
          .read(adminSettlementGatewayProvider)
          .load()
          .timeout(ref.read(adminSettlementLoadTimeoutProvider));
    } catch (error, stackTrace) {
      final failure = AdminSettlementFailure.fromError(error);
      AfriLogger.warn(
        'AdminSettlementNotifier',
        'Fixture settlement workspace load failed.',
        failure,
        stackTrace,
      );
      throw failure;
    }
  }

  void _applyFailure(
    AdminSettlementFailure failure,
    StackTrace stackTrace,
    AdminSettlementSnapshot? previous, {
    bool mutationOutcomeUnconfirmed = false,
  }) {
    if (failure.kind == AdminSettlementFailureKind.permissionDenied) {
      state = AsyncData(
        AdminSettlementSnapshot(
          fixtures: const <AdminSettlementFixture>[],
          phase: AdminSettlementPhase.degraded,
          failure: failure,
        ),
      );
      return;
    }
    state = previous != null
        ? AsyncData(
            previous.copyWith(
              phase: AdminSettlementPhase.degraded,
              failure: failure,
              isMutating: false,
              mutationOutcomeUnconfirmed: mutationOutcomeUnconfirmed,
            ),
          )
        : AsyncError(failure, stackTrace);
  }
}

final adminSettlementProvider =
    AsyncNotifierProvider<AdminSettlementNotifier, AdminSettlementSnapshot>(
      AdminSettlementNotifier.new,
    );

void _requireOnline() {
  if (!ConnectivityService.isOnline) {
    throw const AdminSettlementFailure(AdminSettlementFailureKind.offline);
  }
}

Map<String, dynamic> _strictMap(Object? value, String label) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Invalid $label.');
}

String _requiredUuid(Object? value, {required String field}) {
  final id = _requiredString(value, field: field, max: 36);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(id)) {
    throw FormatException('Invalid $field.');
  }
  return id;
}

String _requiredString(
  Object? value, {
  required String field,
  required int max,
}) {
  if (value is! String) throw FormatException('Invalid $field.');
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > max) {
    throw FormatException('Invalid $field.');
  }
  return normalized;
}

String? _optionalString(
  Object? value, {
  required String field,
  required int max,
}) {
  if (value == null || value == '') return null;
  return _requiredString(value, field: field, max: max);
}

String _requiredEnum(
  Object? value, {
  required String field,
  required Set<String> allowed,
}) {
  final result = _requiredString(value, field: field, max: 32).toLowerCase();
  if (!allowed.contains(result)) throw FormatException('Invalid $field.');
  return result;
}

DateTime _requiredDate(Object? value, {required String field}) {
  if (value is! String) throw FormatException('Invalid $field.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $field.');
  return parsed.toUtc();
}

int _requiredScore(Object? value, String field) {
  if (value is! int || value < 0 || value > 99) {
    throw FormatException('Invalid $field.');
  }
  return value;
}

int? _optionalScore(Object? value, String field) {
  if (value == null) return null;
  return _requiredScore(value, field);
}

int _boundedInt(Object? value, {required String field, required int maximum}) {
  if (value is! int || value < 0 || value > maximum) {
    throw FormatException('Invalid $field.');
  }
  return value;
}
