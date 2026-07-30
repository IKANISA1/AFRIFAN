import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';
import 'repositories/admin_repository.dart';

enum AdminChallengesPhase { ready, degraded }

enum AdminChallengesFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class AdminChallengesFailure implements Exception {
  const AdminChallengesFailure(this.kind);

  final AdminChallengesFailureKind kind;

  static AdminChallengesFailure fromError(Object error) {
    if (error is AdminChallengesFailure) return error;
    if (error is TimeoutException) {
      return const AdminChallengesFailure(
        AdminChallengesFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection refused') ||
        normalized.contains('offline')) {
      return const AdminChallengesFailure(AdminChallengesFailureKind.offline);
    }
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('admin access required') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls') ||
        normalized.contains('42501')) {
      return const AdminChallengesFailure(
        AdminChallengesFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision') ||
        normalized.contains('409')) {
      return const AdminChallengesFailure(AdminChallengesFailureKind.conflict);
    }
    return const AdminChallengesFailure(AdminChallengesFailureKind.unknown);
  }

  @override
  String toString() => 'AdminChallengesFailure(${kind.name})';
}

enum AdminChallengeFilter {
  all('ALL', null),
  open('OPEN', <String>['open']),
  locked('LOCKED', <String>['locked']),
  settled('SETTLED', <String>['settled']),
  voided('VOID', <String>['void', 'cancelled']);

  const AdminChallengeFilter(this.label, this.statuses);

  final String label;
  final List<String>? statuses;
}

class AdminChallengeItem {
  const AdminChallengeItem({
    required this.id,
    required this.competitionName,
    required this.homeTeam,
    required this.awayTeam,
    required this.creatorName,
    required this.totalPoolFet,
    required this.totalParticipants,
    required this.status,
    required this.settlementMode,
    required this.settlementState,
    required this.canRetrySettlement,
    required this.hasVoidReason,
  });

  final String id;
  final String competitionName;
  final String homeTeam;
  final String awayTeam;
  final String creatorName;
  final int totalPoolFet;
  final int totalParticipants;
  final String status;
  final String settlementMode;
  final String settlementState;
  final bool canRetrySettlement;
  final bool hasVoidReason;

  factory AdminChallengeItem.fromJson(Map<String, dynamic> json) {
    final id = _requiredUuid(json['id'], field: 'id');
    final status = _enumValue(
      json['status'],
      field: 'status',
      allowed: const <String>{'open', 'locked', 'settled', 'void', 'cancelled'},
    );
    final fixture = _map(json['fixture'], field: 'fixture');
    final settlement = _optionalMap(json['settlement']);
    final admin = _map(json['admin'], field: 'admin');
    final permissions = _map(json['permissions'], field: 'permissions');

    return AdminChallengeItem(
      id: id,
      competitionName: _boundedString(
        fixture['competition_name'],
        field: 'fixture.competition_name',
        fallback: 'Challenge',
      ),
      homeTeam: _boundedString(
        fixture['home_team_short_name'],
        field: 'fixture.home_team_short_name',
        fallback: 'Home',
      ),
      awayTeam: _boundedString(
        fixture['away_team_short_name'],
        field: 'fixture.away_team_short_name',
        fallback: 'Away',
      ),
      creatorName: _boundedString(
        json['creator_name'],
        field: 'creator_name',
        fallback: 'Supporter',
      ),
      totalPoolFet: _boundedInteger(
        json['total_pool_fet'],
        field: 'total_pool_fet',
        maximum: 1000000000000,
      ),
      totalParticipants: _boundedInteger(
        json['total_participants'],
        field: 'total_participants',
        maximum: 1000000,
      ),
      status: status,
      settlementMode: _settlementMode(
        settlement?['settlement_mode'] ?? admin['settlement_mode'],
      ),
      settlementState: _settlementState(admin['settlement_state']),
      canRetrySettlement:
          status == 'locked' && permissions['can_retry_settlement'] == true,
      hasVoidReason:
          json['void_reason'] is String &&
          (json['void_reason'] as String).trim().isNotEmpty,
    );
  }
}

class AdminChallengeRetryResult {
  const AdminChallengeRetryResult({required this.status});

  final String status;

  factory AdminChallengeRetryResult.fromJson(Map<String, dynamic> json) {
    return AdminChallengeRetryResult(
      status: _enumValue(
        json['status'],
        field: 'retry.status',
        allowed: const <String>{'settled', 'void', 'pending', 'ok'},
      ),
    );
  }
}

class AdminChallengesSnapshot {
  const AdminChallengesSnapshot({
    required this.items,
    this.filter = AdminChallengeFilter.all,
    this.phase = AdminChallengesPhase.ready,
    this.failure,
    this.mutationChallengeId,
    this.mutationOutcomeUnconfirmed = false,
  });

  final List<AdminChallengeItem> items;
  final AdminChallengeFilter filter;
  final AdminChallengesPhase phase;
  final AdminChallengesFailure? failure;
  final String? mutationChallengeId;
  final bool mutationOutcomeUnconfirmed;

  bool get isEmpty => items.isEmpty;

  bool get actionsEnabled =>
      phase == AdminChallengesPhase.ready &&
      failure == null &&
      mutationChallengeId == null &&
      !mutationOutcomeUnconfirmed;

  AdminChallengesSnapshot copyWith({
    List<AdminChallengeItem>? items,
    AdminChallengeFilter? filter,
    AdminChallengesPhase? phase,
    AdminChallengesFailure? failure,
    bool clearFailure = false,
    String? mutationChallengeId,
    bool clearMutation = false,
    bool? mutationOutcomeUnconfirmed,
  }) {
    return AdminChallengesSnapshot(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      mutationChallengeId: clearMutation
          ? null
          : mutationChallengeId ?? this.mutationChallengeId,
      mutationOutcomeUnconfirmed:
          mutationOutcomeUnconfirmed ?? this.mutationOutcomeUnconfirmed,
    );
  }
}

abstract interface class AdminChallengesGateway {
  Future<List<AdminChallengeItem>> load(AdminChallengeFilter filter);

  Future<AdminChallengeRetryResult> retrySettlement(String challengeId);
}

class SupabaseAdminChallengesGateway implements AdminChallengesGateway {
  const SupabaseAdminChallengesGateway(this._repository);

  final AdminRepository _repository;

  @override
  Future<List<AdminChallengeItem>> load(AdminChallengeFilter filter) async {
    if (!await _repository.isCurrentUserAdmin()) {
      throw const AdminChallengesFailure(
        AdminChallengesFailureKind.permissionDenied,
      );
    }
    final rows = await _repository.getPredictionChallenges(
      statuses: filter.statuses,
      limit: 50,
    );
    return List<AdminChallengeItem>.unmodifiable(
      rows.map(AdminChallengeItem.fromJson),
    );
  }

  @override
  Future<AdminChallengeRetryResult> retrySettlement(String challengeId) async {
    final result = await _repository.retryPredictionChallengeSettlement(
      challengeId,
    );
    return AdminChallengeRetryResult.fromJson(result);
  }
}

final adminChallengesGatewayProvider = Provider<AdminChallengesGateway>((ref) {
  return SupabaseAdminChallengesGateway(ref.watch(adminRepositoryProvider));
});

final adminChallengesLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final adminChallengesMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final adminChallengesEnabledProvider = Provider<bool>((ref) => true);

class AdminChallengesNotifier extends AsyncNotifier<AdminChallengesSnapshot> {
  var _filter = AdminChallengeFilter.all;
  var _busy = false;
  var _generation = 0;

  @override
  Future<AdminChallengesSnapshot> build() => _load(_filter);

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AdminChallengesSnapshot>().copyWithPrevious(
      state,
    );
    try {
      state = AsyncData(await _load(_filter));
    } catch (error, stackTrace) {
      _applyFailure(
        AdminChallengesFailure.fromError(error),
        stackTrace,
        previous,
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> selectFilter(AdminChallengeFilter filter) async {
    if (_busy || filter == _filter) return;
    _busy = true;
    _filter = filter;
    final generation = ++_generation;
    state = const AsyncLoading<AdminChallengesSnapshot>();
    try {
      final snapshot = await _load(filter);
      if (generation == _generation) state = AsyncData(snapshot);
    } catch (error, stackTrace) {
      if (generation == _generation) {
        state = AsyncError(AdminChallengesFailure.fromError(error), stackTrace);
      }
    } finally {
      _busy = false;
    }
  }

  Future<AdminChallengeRetryResult?> retrySettlement(String challengeId) async {
    if (_busy) return null;
    final previous = state.valueOrNull;
    if (previous == null ||
        !previous.actionsEnabled ||
        !previous.items.any(
          (item) => item.id == challengeId && item.canRetrySettlement,
        )) {
      return null;
    }

    _busy = true;
    state = AsyncData(
      previous.copyWith(
        mutationChallengeId: challengeId,
        mutationOutcomeUnconfirmed: false,
      ),
    );
    try {
      if (!ConnectivityService.isOnline) {
        throw const AdminChallengesFailure(AdminChallengesFailureKind.offline);
      }
      final result = await ref
          .read(adminChallengesGatewayProvider)
          .retrySettlement(challengeId)
          .timeout(ref.read(adminChallengesMutationTimeoutProvider));
      state = AsyncData(await _load(_filter));
      return result;
    } catch (error, stackTrace) {
      final failure = AdminChallengesFailure.fromError(error);
      final uncertain =
          failure.kind == AdminChallengesFailureKind.securityTimeout ||
          failure.kind == AdminChallengesFailureKind.conflict;
      _applyFailure(
        failure,
        stackTrace,
        previous,
        mutationOutcomeUnconfirmed: uncertain,
      );
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<AdminChallengesSnapshot> _load(AdminChallengeFilter filter) async {
    if (!ConnectivityService.isOnline) {
      throw const AdminChallengesFailure(AdminChallengesFailureKind.offline);
    }
    try {
      final items = await ref
          .read(adminChallengesGatewayProvider)
          .load(filter)
          .timeout(ref.read(adminChallengesLoadTimeoutProvider));
      return AdminChallengesSnapshot(items: items, filter: filter);
    } catch (error, stackTrace) {
      final failure = AdminChallengesFailure.fromError(error);
      AfriLogger.warn(
        'AdminChallengesNotifier',
        'Challenge operations load failed.',
        failure,
        stackTrace,
      );
      throw failure;
    }
  }

  void _applyFailure(
    AdminChallengesFailure failure,
    StackTrace stackTrace,
    AdminChallengesSnapshot? previous, {
    bool mutationOutcomeUnconfirmed = false,
  }) {
    if (failure.kind == AdminChallengesFailureKind.permissionDenied) {
      state = AsyncData(
        AdminChallengesSnapshot(
          items: const <AdminChallengeItem>[],
          filter: _filter,
          phase: AdminChallengesPhase.degraded,
          failure: failure,
        ),
      );
      return;
    }
    state = previous != null
        ? AsyncData(
            previous.copyWith(
              phase: AdminChallengesPhase.degraded,
              failure: failure,
              clearMutation: true,
              mutationOutcomeUnconfirmed: mutationOutcomeUnconfirmed,
            ),
          )
        : AsyncError(failure, stackTrace);
  }
}

final adminChallengesProvider =
    AsyncNotifierProvider<AdminChallengesNotifier, AdminChallengesSnapshot>(
      AdminChallengesNotifier.new,
    );

Map<String, dynamic> _map(Object? value, {required String field}) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Invalid $field.');
}

Map<String, dynamic>? _optionalMap(Object? value) {
  if (value == null) return null;
  return _map(value, field: 'settlement');
}

String _requiredUuid(Object? value, {required String field}) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    throw FormatException('Invalid $field.');
  }
  return value;
}

String _boundedString(
  Object? value, {
  required String field,
  required String fallback,
  int maximum = 80,
}) {
  if (value == null) return fallback;
  if (value is! String) throw FormatException('Invalid $field.');
  final normalized = value.trim();
  if (normalized.isEmpty) return fallback;
  if (normalized.length > maximum) throw FormatException('Invalid $field.');
  return normalized;
}

int _boundedInteger(
  Object? value, {
  required String field,
  required int maximum,
}) {
  if (value == null) return 0;
  if (value is! num || !value.isFinite) {
    throw FormatException('Invalid $field.');
  }
  final integer = value.toInt();
  if (integer != value || integer < 0 || integer > maximum) {
    throw FormatException('Invalid $field.');
  }
  return integer;
}

String _enumValue(
  Object? value, {
  required String field,
  required Set<String> allowed,
}) {
  if (value is! String) throw FormatException('Invalid $field.');
  final normalized = value.trim().toLowerCase();
  if (!allowed.contains(normalized)) throw FormatException('Invalid $field.');
  return normalized;
}

String _settlementMode(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    null || '' => 'Pending',
    'exact_score' => 'Exact score',
    'wdw' || 'wdw_settled' => 'Win, draw, win',
    'refund' || 'void' => 'Refund',
    'manual' => 'Manual review',
    _ => 'Review required',
  };
}

String _settlementState(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'recorded' => 'Recorded',
    'missing_record' => 'Missing record',
    'pending' || null || '' => 'Pending',
    _ => 'Review required',
  };
}
