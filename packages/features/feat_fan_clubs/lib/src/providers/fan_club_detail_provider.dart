import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../official_fanclub_register.dart';

enum FanClubDetailPhase { ready, syncing, degraded }

enum FanClubDetailFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class FanClubDetailFailure implements Exception {
  const FanClubDetailFailure(this.kind);

  final FanClubDetailFailureKind kind;

  static FanClubDetailFailure fromError(Object error) {
    if (error is FanClubDetailFailure) return error;
    if (error is TimeoutException) {
      return const FanClubDetailFailure(
        FanClubDetailFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const FanClubDetailFailure(
        FanClubDetailFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const FanClubDetailFailure(FanClubDetailFailureKind.conflict);
    }
    return const FanClubDetailFailure(FanClubDetailFailureKind.unknown);
  }

  @override
  String toString() => 'FanClubDetailFailure(${kind.name})';
}

class FanClubDetailData {
  const FanClubDetailData({required this.club, this.upcomingMatch});

  final Map<String, dynamic> club;
  final Map<String, dynamic>? upcomingMatch;
}

class FanClubDetailState {
  const FanClubDetailState({
    this.data,
    this.phase = FanClubDetailPhase.ready,
    this.failure,
  });

  final FanClubDetailData? data;
  final FanClubDetailPhase phase;
  final FanClubDetailFailure? failure;

  bool get actionsBlocked =>
      phase != FanClubDetailPhase.ready || failure != null;

  FanClubDetailState copyWith({
    FanClubDetailData? data,
    FanClubDetailPhase? phase,
    FanClubDetailFailure? failure,
    bool clearFailure = false,
  }) {
    return FanClubDetailState(
      data: data ?? this.data,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

abstract interface class FanClubDetailGateway {
  Future<FanClubDetailData?> load(String routeId);
}

class SupabaseFanClubDetailGateway implements FanClubDetailGateway {
  const SupabaseFanClubDetailGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<FanClubDetailData?> load(String routeId) async {
    final resolver = ClubScopeResolver(client: _client);
    final scope = await resolver.requireResolved();
    if (scope.clubId == null) {
      throw StateError('Fan clubs require a numeric club scope.');
    }

    final clubRow = await _loadFanclubRow(routeId);
    if (clubRow == null) return null;

    Map<String, dynamic>? matchRow;
    try {
      var query = _client
          .from('unified_matches')
          .select()
          .eq('is_on_sale', true);
      query = resolver.apply(query, scope);
      final match = await query
          .order('match_date', ascending: true)
          .limit(1)
          .maybeSingle();
      matchRow = match == null ? null : Map<String, dynamic>.from(match);
    } catch (_) {
      // Matchday context is optional; the verified club remains usable.
    }

    return FanClubDetailData(
      club: normalizeFanclubRow(Map<String, dynamic>.from(clubRow)),
      upcomingMatch: matchRow,
    );
  }

  Future<Map<String, dynamic>?> _loadFanclubRow(String routeId) async {
    if (_looksLikeUuid(routeId)) {
      final byId = await _client
          .from('fan_clubs')
          .select(
            'id,partner_id,club_id,name,region,description,member_count,'
            'event_count,rating,banner_emoji,is_active,created_at,updated_at',
          )
          .eq('id', routeId)
          .eq('is_active', true)
          .maybeSingle();
      if (byId != null) return Map<String, dynamic>.from(byId);
    }

    for (final fanclub in officialFanclubRegister()) {
      if (fanclub['id']?.toString() == routeId ||
          fanclub['slug']?.toString() == routeId) {
        return fanclub;
      }
    }
    return null;
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}

final fanClubDetailGatewayProvider = Provider<FanClubDetailGateway>(
  (ref) => SupabaseFanClubDetailGateway(ref.watch(supabaseClientProvider)),
);

final fanClubDetailLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final fanClubDetailAccessEnabledProvider = Provider<bool>((ref) => true);

final fanClubDetailProvider =
    StateNotifierProvider.family<
      FanClubDetailController,
      AsyncValue<FanClubDetailState>,
      String
    >((ref, clubId) {
      return FanClubDetailController(
        ref.watch(fanClubDetailGatewayProvider),
        clubId,
        loadTimeout: ref.watch(fanClubDetailLoadTimeoutProvider),
      );
    });

class FanClubDetailController
    extends StateNotifier<AsyncValue<FanClubDetailState>> {
  FanClubDetailController(
    this._gateway,
    this._clubId, {
    Duration loadTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : _loadTimeout = loadTimeout,
       super(const AsyncValue.loading()) {
    if (autoLoad) unawaited(load());
  }

  final FanClubDetailGateway _gateway;
  final String _clubId;
  final Duration _loadTimeout;
  bool _loading = false;

  Future<void> load() => _load(preserveCurrent: false);

  Future<void> refresh() => _load(preserveCurrent: true);

  Future<void> _load({required bool preserveCurrent}) async {
    if (_loading) return;
    _loading = true;
    final previous = state.valueOrNull;
    if (preserveCurrent && previous?.data != null) {
      state = AsyncValue.data(
        previous!.copyWith(
          phase: FanClubDetailPhase.syncing,
          clearFailure: true,
        ),
      );
    } else {
      state = const AsyncLoading<FanClubDetailState>();
    }

    try {
      if (!ConnectivityService.isOnline) {
        throw const FanClubDetailFailure(FanClubDetailFailureKind.offline);
      }
      final data = await _gateway.load(_clubId).timeout(_loadTimeout);
      state = AsyncValue.data(FanClubDetailState(data: data));
    } catch (error, stackTrace) {
      final failure = FanClubDetailFailure.fromError(error);
      state = previous?.data != null
          ? AsyncValue.data(
              previous!.copyWith(
                phase: FanClubDetailPhase.degraded,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }
}
