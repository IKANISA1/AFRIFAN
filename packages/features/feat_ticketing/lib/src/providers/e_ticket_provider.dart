import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ETicketPhase { ready, syncing, degraded }

enum ETicketFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class ETicketFailure implements Exception {
  const ETicketFailure(this.kind);

  final ETicketFailureKind kind;

  static ETicketFailure fromError(Object error) {
    if (error is ETicketFailure) return error;
    if (error is TimeoutException) {
      return const ETicketFailure(ETicketFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const ETicketFailure(ETicketFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const ETicketFailure(ETicketFailureKind.conflict);
    }
    return const ETicketFailure(ETicketFailureKind.unknown);
  }

  @override
  String toString() => 'ETicketFailure(${kind.name})';
}

class ETicketState {
  const ETicketState({
    this.ticket,
    this.phase = ETicketPhase.ready,
    this.failure,
  });

  final ClubTicket? ticket;
  final ETicketPhase phase;
  final ETicketFailure? failure;

  ETicketState copyWith({
    ClubTicket? ticket,
    ETicketPhase? phase,
    ETicketFailure? failure,
    bool clearFailure = false,
  }) {
    return ETicketState(
      ticket: ticket ?? this.ticket,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

abstract interface class ETicketGateway {
  Future<ClubTicket?> load(String ticketId);
}

class SupabaseETicketGateway implements ETicketGateway {
  const SupabaseETicketGateway({
    required SupabaseClient client,
    required String? userId,
    required String? clubId,
  })  : _client = client,
        _userId = userId,
        _clubId = clubId;

  final SupabaseClient _client;
  final String? _userId;
  final String? _clubId;

  @override
  Future<ClubTicket?> load(String ticketId) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty || ticketId.isEmpty) return null;
    final resolver = ClubScopeResolver(client: _client);
    final scope = await resolver.requireResolved(_clubId);
    var query = _client
        .from('tickets')
        .select('*, match:matches(*)')
        .eq('user_id', userId)
        .eq('id', ticketId);
    query = resolver.apply(query, scope);
    final row = await query.maybeSingle();
    if (row == null) return null;
    return ClubTicket.fromJson(Map<String, dynamic>.from(row));
  }
}

final eTicketGatewayProvider = Provider<ETicketGateway>((ref) {
  final user = ref.watch(currentUserProvider);
  return SupabaseETicketGateway(
    client: ref.watch(supabaseClientProvider),
    userId: user?.id,
    clubId: user?.clubId,
  );
});

final eTicketLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final eTicketAccessEnabledProvider = Provider<bool>((ref) => true);

final eTicketProvider = StateNotifierProvider.family<ETicketController,
    AsyncValue<ETicketState>, String>((ref, ticketId) {
  return ETicketController(
    ref.watch(eTicketGatewayProvider),
    ticketId,
    loadTimeout: ref.watch(eTicketLoadTimeoutProvider),
  );
});

class ETicketController extends StateNotifier<AsyncValue<ETicketState>> {
  ETicketController(
    this._gateway,
    this._ticketId, {
    Duration loadTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  })  : _loadTimeout = loadTimeout,
        super(const AsyncValue.loading()) {
    if (autoLoad) unawaited(load());
  }

  final ETicketGateway _gateway;
  final String _ticketId;
  final Duration _loadTimeout;
  bool _loading = false;

  Future<void> load() => _load(preserveCurrent: false);

  Future<void> refresh() => _load(preserveCurrent: true);

  Future<void> _load({required bool preserveCurrent}) async {
    if (_loading) return;
    _loading = true;
    final previous = state.valueOrNull;
    state = preserveCurrent && previous?.ticket != null
        ? const AsyncLoading<ETicketState>().copyWithPrevious(state)
        : const AsyncLoading<ETicketState>();
    try {
      if (!ConnectivityService.isOnline) {
        throw const ETicketFailure(ETicketFailureKind.offline);
      }
      final ticket = await _gateway.load(_ticketId).timeout(_loadTimeout);
      state = AsyncValue.data(ETicketState(ticket: ticket));
    } catch (error, stackTrace) {
      final failure = ETicketFailure.fromError(error);
      state = previous?.ticket != null
          ? AsyncValue.data(
              previous!.copyWith(
                phase: ETicketPhase.degraded,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }
}
