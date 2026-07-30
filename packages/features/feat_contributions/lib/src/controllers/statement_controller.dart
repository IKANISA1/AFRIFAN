import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum StatementPhase { ready, syncing, degraded }

enum StatementFailureKind {
  offline,
  notFound,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class StatementFailure implements Exception {
  const StatementFailure(this.kind);

  final StatementFailureKind kind;

  static StatementFailure fromError(Object error) {
    if (error is StatementFailure) return error;
    if (error is TimeoutException) {
      return const StatementFailure(StatementFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const StatementFailure(StatementFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const StatementFailure(StatementFailureKind.conflict);
    }
    return const StatementFailure(StatementFailureKind.unknown);
  }

  @override
  String toString() => 'StatementFailure(${kind.name})';
}

enum StatementSort { date, amount, alias }

extension StatementSortContract on StatementSort {
  String get label => switch (this) {
    StatementSort.date => 'BY DATE',
    StatementSort.amount => 'BY AMOUNT',
    StatementSort.alias => 'BY ALIAS',
  };
}

enum StatementEntryStatus { confirmed, processing, failed }

extension StatementEntryStatusContract on StatementEntryStatus {
  String get label => switch (this) {
    StatementEntryStatus.confirmed => 'CONFIRMED',
    StatementEntryStatus.processing => 'PROCESSING',
    StatementEntryStatus.failed => 'FAILED',
  };
}

class StatementEntry {
  const StatementEntry({
    required this.publicAlias,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  final String publicAlias;
  final int amount;
  final StatementEntryStatus status;
  final DateTime createdAt;
}

class StatementSnapshot {
  const StatementSnapshot({
    required this.groupName,
    this.entries = const <StatementEntry>[],
  });

  final String groupName;
  final List<StatementEntry> entries;
}

class StatementState {
  const StatementState({
    required this.snapshot,
    this.phase = StatementPhase.ready,
    this.failure,
    this.sort = StatementSort.date,
    this.from,
    this.to,
  });

  final StatementSnapshot snapshot;
  final StatementPhase phase;
  final StatementFailure? failure;
  final StatementSort sort;
  final DateTime? from;
  final DateTime? to;

  bool get actionsBlocked => phase != StatementPhase.ready || failure != null;

  List<StatementEntry> get sortedEntries {
    final sorted = List<StatementEntry>.from(snapshot.entries);
    switch (sort) {
      case StatementSort.date:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case StatementSort.amount:
        sorted.sort((a, b) => b.amount.compareTo(a.amount));
      case StatementSort.alias:
        sorted.sort((a, b) => a.publicAlias.compareTo(b.publicAlias));
    }
    return List<StatementEntry>.unmodifiable(sorted);
  }

  int get confirmedTotal => snapshot.entries
      .where((entry) => entry.status == StatementEntryStatus.confirmed)
      .fold<int>(0, (sum, entry) => sum + entry.amount);

  StatementState copyWith({
    StatementSnapshot? snapshot,
    StatementPhase? phase,
    StatementFailure? failure,
    bool clearFailure = false,
    StatementSort? sort,
    DateTime? from,
    DateTime? to,
    bool replaceRange = false,
  }) {
    return StatementState(
      snapshot: snapshot ?? this.snapshot,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      sort: sort ?? this.sort,
      from: replaceRange ? from : this.from,
      to: replaceRange ? to : this.to,
    );
  }
}

abstract interface class StatementGateway {
  Future<StatementSnapshot?> load(
    String groupId, {
    DateTime? from,
    DateTime? to,
  });
}

class SupabaseStatementGateway implements StatementGateway {
  const SupabaseStatementGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<StatementSnapshot?> load(
    String groupId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final scope = await ClubScopeResolver(client: _client).requireResolved();
    final clubId = scope.clubId;
    if (clubId == null) {
      throw const StatementFailure(StatementFailureKind.permissionDenied);
    }

    final groupRow = await _client
        .from('contribution_groups')
        .select('id, name')
        .eq('id', groupId)
        .eq('club_id', clubId)
        .maybeSingle();
    if (groupRow == null) return null;

    var query = _client
        .from('group_contributions')
        .select('user_id, amount, status, created_at')
        .eq('group_id', groupId);
    if (from != null) {
      query = query.gte(
        'created_at',
        DateTime.utc(from.year, from.month, from.day).toIso8601String(),
      );
    }
    if (to != null) {
      query = query.lt(
        'created_at',
        DateTime.utc(to.year, to.month, to.day + 1).toIso8601String(),
      );
    }
    final rows = await query.order('created_at', ascending: false).limit(200);
    final userIds = rows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final aliases = <String, String>{};
    if (userIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, public_user_id')
          .inFilter('id', userIds);
      for (final profile in profiles) {
        final userId = profile['id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        aliases[userId] = safePublicStatementAlias(profile['public_user_id']);
      }
    }

    final entries = rows
        .map(
          (row) => StatementEntry(
            publicAlias:
                aliases[row['user_id']?.toString() ?? ''] ?? 'Supporter',
            amount: ((row['amount'] as num?)?.toInt() ?? 0).clamp(0, 1 << 31),
            status: statementStatusFrom(row['status']),
            createdAt:
                DateTime.tryParse(
                  row['created_at']?.toString() ?? '',
                )?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        )
        .toList(growable: false);

    final rawName = groupRow['name']?.toString().trim() ?? '';
    return StatementSnapshot(
      groupName: rawName.isEmpty ? 'Contribution initiative' : rawName,
      entries: List<StatementEntry>.unmodifiable(entries),
    );
  }
}

String safePublicStatementAlias(Object? raw) {
  final normalized = raw
      ?.toString()
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')
      .trim();
  if (normalized == null || normalized.isEmpty) return 'Supporter';
  final visible = normalized.length <= 18
      ? normalized
      : normalized.substring(0, 18);
  return '#$visible';
}

StatementEntryStatus statementStatusFrom(Object? raw) {
  return switch (raw?.toString().trim().toLowerCase()) {
    'confirmed' || 'verified' => StatementEntryStatus.confirmed,
    'rejected' || 'failed' || 'reversed' => StatementEntryStatus.failed,
    _ => StatementEntryStatus.processing,
  };
}

String buildStatementCsv(StatementState state) {
  final buffer = StringBuffer()..writeln('Alias,Amount,Status,Date');
  for (final entry in state.sortedEntries) {
    buffer.writeln(
      <Object>[
        entry.publicAlias,
        entry.amount,
        entry.status.label,
        entry.createdAt.toIso8601String(),
      ].map(_escapeCsv).join(','),
    );
  }
  return buffer.toString();
}

String _escapeCsv(Object? value) {
  final field = value?.toString() ?? '';
  if (field.contains(',') || field.contains('"') || field.contains('\n')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}

final statementGatewayProvider = Provider<StatementGateway>(
  (ref) => SupabaseStatementGateway(ref.watch(supabaseClientProvider)),
);

final statementLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final statementExportEnabledProvider = Provider<bool>((ref) => true);

final statementProvider = StateNotifierProvider.autoDispose
    .family<StatementController, AsyncValue<StatementState>, String>(
      (ref, groupId) => StatementController(
        ref.watch(statementGatewayProvider),
        groupId: groupId,
        loadTimeout: ref.watch(statementLoadTimeoutProvider),
      ),
    );

class StatementController extends StateNotifier<AsyncValue<StatementState>> {
  StatementController(
    this._gateway, {
    required this.groupId,
    Duration loadTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : _loadTimeout = loadTimeout,
       super(const AsyncValue.loading()) {
    if (autoLoad) unawaited(refresh());
  }

  final StatementGateway _gateway;
  final String groupId;
  final Duration _loadTimeout;

  StatementSnapshot? _confirmed;
  DateTime? _from;
  DateTime? _to;
  StatementSort _sort = StatementSort.date;
  Future<void>? _activeLoad;

  Future<void> refresh() {
    final active = _activeLoad;
    if (active != null) return active;
    late final Future<void> load;
    load = _load().whenComplete(() {
      if (identical(_activeLoad, load)) _activeLoad = null;
    });
    _activeLoad = load;
    return load;
  }

  void setSort(StatementSort sort) {
    _sort = sort;
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData<StatementState>(current.copyWith(sort: sort));
  }

  Future<void> setRange({DateTime? from, DateTime? to}) {
    _from = from;
    _to = to;
    return refresh();
  }

  Future<void> _load() async {
    final confirmed = _confirmed;
    state = confirmed == null
        ? const AsyncLoading<StatementState>()
        : AsyncData<StatementState>(
            StatementState(
              snapshot: confirmed,
              phase: StatementPhase.syncing,
              sort: _sort,
              from: _from,
              to: _to,
            ),
          );

    try {
      if (!ConnectivityService.isOnline) {
        throw const StatementFailure(StatementFailureKind.offline);
      }
      if (groupId.trim().isEmpty) {
        throw const StatementFailure(StatementFailureKind.notFound);
      }
      final snapshot = await _gateway
          .load(groupId, from: _from, to: _to)
          .timeout(_loadTimeout);
      if (snapshot == null) {
        throw const StatementFailure(StatementFailureKind.notFound);
      }
      _confirmed = snapshot;
      state = AsyncData<StatementState>(
        StatementState(snapshot: snapshot, sort: _sort, from: _from, to: _to),
      );
    } catch (error, stackTrace) {
      final failure = StatementFailure.fromError(error);
      AfriLogger.warn(
        'StatementController',
        'Public statement failed to load.',
        failure,
        stackTrace,
      );
      state = confirmed == null
          ? AsyncError<StatementState>(failure, stackTrace)
          : AsyncData<StatementState>(
              StatementState(
                snapshot: confirmed,
                phase: StatementPhase.degraded,
                failure: failure,
                sort: _sort,
                from: _from,
                to: _to,
              ),
            );
    }
  }
}
