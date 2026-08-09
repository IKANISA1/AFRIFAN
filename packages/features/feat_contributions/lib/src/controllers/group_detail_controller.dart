import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum GroupDetailPhase { ready, syncing, degraded }

enum GroupDetailFailureKind {
  offline,
  notFound,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class GroupDetailFailure implements Exception {
  const GroupDetailFailure(this.kind);

  final GroupDetailFailureKind kind;

  static GroupDetailFailure fromError(Object error) {
    if (error is GroupDetailFailure) return error;
    if (error is TimeoutException) {
      return const GroupDetailFailure(GroupDetailFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const GroupDetailFailure(GroupDetailFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const GroupDetailFailure(GroupDetailFailureKind.conflict);
    }
    return const GroupDetailFailure(GroupDetailFailureKind.unknown);
  }

  @override
  String toString() => 'GroupDetailFailure(${kind.name})';
}

enum GroupLedgerStatus { confirmed, processing, failed }

extension GroupLedgerStatusContract on GroupLedgerStatus {
  String get label => switch (this) {
    GroupLedgerStatus.confirmed => 'CONFIRMED',
    GroupLedgerStatus.processing => 'PROCESSING',
    GroupLedgerStatus.failed => 'FAILED',
  };
}

class GroupLedgerEntry {
  const GroupLedgerEntry({
    required this.publicAlias,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  final String publicAlias;
  final int amount;
  final GroupLedgerStatus status;
  final DateTime createdAt;
}

class GroupDetailSnapshot {
  const GroupDetailSnapshot({
    required this.group,
    this.ledger = const <GroupLedgerEntry>[],
  });

  final ContributionGroup group;
  final List<GroupLedgerEntry> ledger;
}

class GroupDetailState {
  const GroupDetailState({
    required this.snapshot,
    this.phase = GroupDetailPhase.ready,
    this.failure,
  });

  final GroupDetailSnapshot snapshot;
  final GroupDetailPhase phase;
  final GroupDetailFailure? failure;

  bool get actionsBlocked => phase != GroupDetailPhase.ready;
}

abstract interface class GroupDetailGateway {
  Future<GroupDetailSnapshot?> load(String groupId);
}

class SupabaseGroupDetailGateway implements GroupDetailGateway {
  const SupabaseGroupDetailGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<GroupDetailSnapshot?> load(String groupId) async {
    final scope = await ClubScopeResolver(client: _client).requireResolved();
    final clubId = scope.clubId;
    if (clubId == null) {
      throw const GroupDetailFailure(GroupDetailFailureKind.permissionDenied);
    }

    final groupRow = await _client
        .from('contribution_groups')
        .select(
          'id,name,description,group_type,target_amount,current_total,'
          'momo_recipient_code,momo_route_type,deadline,is_recurring,'
          'is_closed,member_count,created_at,club_id,partner_id,is_active',
        )
        .eq('id', groupId)
        .eq('club_id', clubId)
        .maybeSingle();
    if (groupRow == null) return null;

    final contributionRows = await _client
        .from('group_contributions')
        .select('user_id, amount, created_at, status')
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(20);
    final userIds = contributionRows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final aliases = <String, String>{};
    if (userIds.isNotEmpty) {
      final profileRows = await _client
          .from('profiles')
          .select('id, public_user_id')
          .inFilter('id', userIds);
      for (final row in profileRows) {
        final userId = row['id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        aliases[userId] = _safePublicAlias(row['public_user_id']);
      }
    }

    final ledger = contributionRows
        .map((row) {
          final userId = row['user_id']?.toString() ?? '';
          return GroupLedgerEntry(
            publicAlias: aliases[userId] ?? 'Supporter',
            amount: ((row['amount'] as num?)?.toInt() ?? 0).clamp(0, 1 << 31),
            status: _statusFrom(row['status']),
            createdAt:
                DateTime.tryParse(
                  row['created_at']?.toString() ?? '',
                )?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          );
        })
        .toList(growable: false);

    return GroupDetailSnapshot(
      group: ContributionGroup.fromJson(Map<String, dynamic>.from(groupRow)),
      ledger: List<GroupLedgerEntry>.unmodifiable(ledger),
    );
  }

  static String _safePublicAlias(Object? raw) {
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

  static GroupLedgerStatus _statusFrom(Object? raw) {
    return switch (raw?.toString().trim().toLowerCase()) {
      'confirmed' || 'verified' => GroupLedgerStatus.confirmed,
      'rejected' || 'failed' => GroupLedgerStatus.failed,
      _ => GroupLedgerStatus.processing,
    };
  }
}

final groupDetailGatewayProvider = Provider<GroupDetailGateway>(
  (ref) => SupabaseGroupDetailGateway(ref.watch(supabaseClientProvider)),
);

final groupDetailLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final groupContributionActionsEnabledProvider = Provider<bool>((ref) => true);

final groupDetailProvider = StateNotifierProvider.autoDispose
    .family<GroupDetailController, AsyncValue<GroupDetailState>, String>(
      (ref, groupId) => GroupDetailController(
        ref.watch(groupDetailGatewayProvider),
        groupId: groupId,
        loadTimeout: ref.watch(groupDetailLoadTimeoutProvider),
      ),
    );

class GroupDetailController
    extends StateNotifier<AsyncValue<GroupDetailState>> {
  GroupDetailController(
    this._gateway, {
    required this.groupId,
    Duration loadTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : _loadTimeout = loadTimeout,
       super(const AsyncValue.loading()) {
    if (autoLoad) unawaited(refresh());
  }

  final GroupDetailGateway _gateway;
  final String groupId;
  final Duration _loadTimeout;

  GroupDetailSnapshot? _confirmed;
  Future<void>? _activeLoad;

  Future<void> refresh() {
    final activeLoad = _activeLoad;
    if (activeLoad != null) return activeLoad;
    late final Future<void> load;
    load = _load().whenComplete(() {
      if (identical(_activeLoad, load)) _activeLoad = null;
    });
    _activeLoad = load;
    return load;
  }

  Future<void> _load() async {
    final confirmed = _confirmed;
    state = confirmed == null
        ? const AsyncLoading<GroupDetailState>()
        : AsyncData<GroupDetailState>(
            GroupDetailState(
              snapshot: confirmed,
              phase: GroupDetailPhase.syncing,
            ),
          );

    try {
      if (!ConnectivityService.isOnline) {
        throw const GroupDetailFailure(GroupDetailFailureKind.offline);
      }
      if (groupId.trim().isEmpty) {
        throw const GroupDetailFailure(GroupDetailFailureKind.notFound);
      }
      final snapshot = await _gateway.load(groupId).timeout(_loadTimeout);
      if (snapshot == null) {
        throw const GroupDetailFailure(GroupDetailFailureKind.notFound);
      }
      _confirmed = snapshot;
      state = AsyncData<GroupDetailState>(GroupDetailState(snapshot: snapshot));
    } catch (error, stackTrace) {
      final failure = GroupDetailFailure.fromError(error);
      AfriLogger.warn(
        'GroupDetailController',
        'Public initiative failed to load.',
        failure,
        stackTrace,
      );
      state = confirmed == null
          ? AsyncError<GroupDetailState>(failure, stackTrace)
          : AsyncData<GroupDetailState>(
              GroupDetailState(
                snapshot: confirmed,
                phase: GroupDetailPhase.degraded,
                failure: failure,
              ),
            );
    }
  }
}
