import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ticketing_providers.dart';

enum TicketDetailPhase { ready, syncing, degraded }

enum TicketDetailFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class TicketDetailFailure implements Exception {
  const TicketDetailFailure(this.kind);

  final TicketDetailFailureKind kind;

  static TicketDetailFailure fromError(Object error) {
    if (error is TicketDetailFailure) return error;
    if (error is TimeoutException) {
      return const TicketDetailFailure(TicketDetailFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const TicketDetailFailure(
        TicketDetailFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const TicketDetailFailure(TicketDetailFailureKind.conflict);
    }
    return const TicketDetailFailure(TicketDetailFailureKind.unknown);
  }

  @override
  String toString() => 'TicketDetailFailure(${kind.name})';
}

class TicketDetailState {
  const TicketDetailState({
    this.match,
    this.phase = TicketDetailPhase.ready,
    this.failure,
  });

  final ClubMatch? match;
  final TicketDetailPhase phase;
  final TicketDetailFailure? failure;

  TicketDetailState copyWith({
    ClubMatch? match,
    TicketDetailPhase? phase,
    TicketDetailFailure? failure,
    bool clearFailure = false,
  }) {
    return TicketDetailState(
      match: match ?? this.match,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

abstract interface class TicketDetailGateway {
  Future<ClubMatch?> load(String matchId);
}

class RiverpodTicketDetailGateway implements TicketDetailGateway {
  const RiverpodTicketDetailGateway(this._ref);

  final Ref _ref;

  @override
  Future<ClubMatch?> load(String matchId) {
    return _ref.read(ticketMatchProvider(matchId).future);
  }
}

final ticketDetailGatewayProvider = Provider<TicketDetailGateway>(
  (ref) => RiverpodTicketDetailGateway(ref),
);

final ticketDetailLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final ticketDetailMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final ticketDetailAccessEnabledProvider = Provider<bool>((ref) => true);

final seatMapAccessEnabledProvider = Provider<bool>((ref) => true);

final ticketDetailProvider =
    StateNotifierProvider.family<
      TicketDetailController,
      AsyncValue<TicketDetailState>,
      String
    >((ref, matchId) {
      return TicketDetailController(
        ref.watch(ticketDetailGatewayProvider),
        matchId,
        loadTimeout: ref.watch(ticketDetailLoadTimeoutProvider),
      );
    });

class TicketDetailController
    extends StateNotifier<AsyncValue<TicketDetailState>> {
  TicketDetailController(
    this._gateway,
    this._matchId, {
    Duration loadTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : _loadTimeout = loadTimeout,
       super(const AsyncValue.loading()) {
    if (autoLoad) unawaited(load());
  }

  final TicketDetailGateway _gateway;
  final String _matchId;
  final Duration _loadTimeout;
  bool _loading = false;

  Future<void> load() => _load(preserveCurrent: false);

  Future<void> refresh() => _load(preserveCurrent: true);

  Future<void> _load({required bool preserveCurrent}) async {
    if (_loading) return;
    _loading = true;
    final previous = state.valueOrNull;
    if (preserveCurrent && previous?.match != null) {
      state = AsyncValue.data(
        previous!.copyWith(
          phase: TicketDetailPhase.syncing,
          clearFailure: true,
        ),
      );
    } else {
      state = const AsyncLoading<TicketDetailState>();
    }

    try {
      if (!ConnectivityService.isOnline) {
        throw const TicketDetailFailure(TicketDetailFailureKind.offline);
      }
      final match = await _gateway.load(_matchId).timeout(_loadTimeout);
      state = AsyncValue.data(TicketDetailState(match: match));
    } catch (error, stackTrace) {
      final failure = TicketDetailFailure.fromError(error);
      state = previous?.match != null
          ? AsyncValue.data(
              previous!.copyWith(
                phase: TicketDetailPhase.degraded,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }
}
