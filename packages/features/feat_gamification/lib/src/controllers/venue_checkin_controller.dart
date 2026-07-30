import 'dart:async';
import 'dart:convert';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum VenueCheckinPhase { ready, syncing, degraded, confirmed }

enum VenueCheckinFailureKind {
  invalidCode,
  expiredCode,
  alreadyCheckedIn,
  campaignUnavailable,
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class VenueCheckinFailure implements Exception {
  const VenueCheckinFailure(this.kind);

  final VenueCheckinFailureKind kind;

  static VenueCheckinFailure fromError(Object error) {
    if (error is VenueCheckinFailure) return error;
    if (error is TimeoutException) {
      return const VenueCheckinFailure(VenueCheckinFailureKind.securityTimeout);
    }
    final text = error.toString().toLowerCase();
    if (text.contains('permission') ||
        text.contains('forbidden') ||
        text.contains('unauthorized') ||
        text.contains('row-level security') ||
        text.contains('rls')) {
      return const VenueCheckinFailure(
        VenueCheckinFailureKind.permissionDenied,
      );
    }
    if (text.contains('conflict') ||
        text.contains('stale') ||
        text.contains('already') ||
        text.contains('busy')) {
      return const VenueCheckinFailure(VenueCheckinFailureKind.conflict);
    }
    return const VenueCheckinFailure(VenueCheckinFailureKind.unknown);
  }

  @override
  String toString() => 'VenueCheckinFailure(${kind.name})';
}

class VenueCheckinResult {
  const VenueCheckinResult({
    required this.status,
    required this.code,
    this.checkinId,
    this.venueId,
    this.fetAwarded = 0,
    this.locationVerificationStatus,
  });

  factory VenueCheckinResult.fromJson(Map<String, dynamic> json) {
    return VenueCheckinResult(
      status: json['status']?.toString() ?? 'error',
      code: json['code']?.toString() ?? 'unknown',
      checkinId: json['checkin_id']?.toString(),
      venueId: json['venue_id']?.toString(),
      fetAwarded: (json['fet_awarded'] as num?)?.toInt() ?? 0,
      locationVerificationStatus: json['location_verification_status']
          ?.toString(),
    );
  }

  final String status;
  final String code;
  final String? checkinId;
  final String? venueId;
  final int fetAwarded;
  final String? locationVerificationStatus;

  bool get isAccepted =>
      code == 'ok' ||
      code == 'idempotent_replay' ||
      status == 'confirmed' ||
      status == 'pending_review';
}

class VenueCheckinRouteState {
  const VenueCheckinRouteState({
    this.phase = VenueCheckinPhase.ready,
    this.failure,
    this.result,
    this.locationConsent = false,
    this.uncertainMutation = false,
  });

  final VenueCheckinPhase phase;
  final VenueCheckinFailure? failure;
  final VenueCheckinResult? result;
  final bool locationConsent;
  final bool uncertainMutation;

  bool get actionBlocked =>
      phase == VenueCheckinPhase.syncing ||
      phase == VenueCheckinPhase.confirmed ||
      failure != null ||
      uncertainMutation;

  VenueCheckinRouteState copyWith({
    VenueCheckinPhase? phase,
    VenueCheckinFailure? failure,
    VenueCheckinResult? result,
    bool? locationConsent,
    bool? uncertainMutation,
    bool clearFailure = false,
    bool clearResult = false,
  }) {
    return VenueCheckinRouteState(
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      result: clearResult ? null : result ?? this.result,
      locationConsent: locationConsent ?? this.locationConsent,
      uncertainMutation: uncertainMutation ?? this.uncertainMutation,
    );
  }
}

abstract interface class VenueCheckinGateway {
  Future<VenueCheckinResult> submit({
    required String rawCode,
    required String idempotencyKey,
  });
}

class RepositoryVenueCheckinGateway implements VenueCheckinGateway {
  RepositoryVenueCheckinGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<VenueCheckinResult> submit({
    required String rawCode,
    required String idempotencyKey,
  }) async {
    final scope = await ClubScopeResolver(client: _client).requireResolved();
    if (scope.clubId == null) {
      throw const VenueCheckinFailure(VenueCheckinFailureKind.permissionDenied);
    }
    final codeHash = sha256
        .convert(utf8.encode(rawCode.trim().toUpperCase()))
        .toString();
    final response = await SafeRpc.call(
      'venue_checkin_validate',
      params: <String, dynamic>{
        'p_club_id': scope.clubId,
        'p_code_hash': codeHash,
        'p_idempotency_key': idempotencyKey,
        // Precise location remains intentionally uncollected until the
        // separately governed foreground-location release gate is approved.
        'p_location_accuracy_meters': null,
      },
      tag: 'VenueCheckin',
      maxAttempts: 1,
    );
    if (!response.isSuccess || response.data is! Map) {
      throw StateError('Venue check-in returned an invalid response.');
    }
    return VenueCheckinResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

class VenueCheckinController
    extends StateNotifier<AsyncValue<VenueCheckinRouteState>> {
  VenueCheckinController(
    this._gateway, {
    Duration timeout = const Duration(seconds: 12),
  }) : _timeout = timeout,
       super(const AsyncData<VenueCheckinRouteState>(VenueCheckinRouteState()));

  final VenueCheckinGateway _gateway;
  final Duration _timeout;
  bool _submitting = false;
  int _attempt = 0;

  void setLocationConsent(bool value) {
    final current = state.valueOrNull;
    if (current == null ||
        _submitting ||
        current.phase == VenueCheckinPhase.confirmed) {
      return;
    }
    state = AsyncData(
      current.copyWith(locationConsent: value, clearFailure: true),
    );
  }

  void acknowledgeFailure() {
    final current = state.valueOrNull;
    if (current == null || _submitting || current.failure == null) return;
    state = AsyncData(
      current.copyWith(
        phase: VenueCheckinPhase.ready,
        clearFailure: true,
        uncertainMutation: false,
      ),
    );
  }

  Future<bool> submit(String rawCode) async {
    final current = state.valueOrNull;
    if (_submitting || current == null || current.actionBlocked) return false;
    final normalized = rawCode.trim();
    if (normalized.length < 4) {
      _retainFailure(
        current,
        const VenueCheckinFailure(VenueCheckinFailureKind.invalidCode),
      );
      return false;
    }
    if (!ConnectivityService.isOnline) {
      _retainFailure(
        current,
        const VenueCheckinFailure(VenueCheckinFailureKind.offline),
      );
      return false;
    }

    _submitting = true;
    _attempt += 1;
    final idempotencyKey =
        'venue-${DateTime.now().microsecondsSinceEpoch}-$_attempt';
    state = AsyncData(
      current.copyWith(
        phase: VenueCheckinPhase.syncing,
        clearFailure: true,
        clearResult: true,
      ),
    );
    try {
      final result = await _gateway
          .submit(rawCode: normalized, idempotencyKey: idempotencyKey)
          .timeout(_timeout);
      if (!result.isAccepted) {
        _retainFailure(current, _failureForCode(result.code));
        return false;
      }
      state = AsyncData(
        current.copyWith(
          phase: VenueCheckinPhase.confirmed,
          result: result,
          clearFailure: true,
          uncertainMutation: false,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'VenueCheckinController',
        'Venue check-in failed.',
        error,
        stackTrace,
      );
      final failure = VenueCheckinFailure.fromError(error);
      _retainFailure(
        current,
        failure,
        uncertain: failure.kind == VenueCheckinFailureKind.securityTimeout,
      );
      return false;
    } finally {
      _submitting = false;
    }
  }

  Future<void> connectionRestored() async {
    final current = state.valueOrNull;
    if (current?.failure?.kind != VenueCheckinFailureKind.offline ||
        current?.uncertainMutation == true) {
      return;
    }
    acknowledgeFailure();
  }

  void _retainFailure(
    VenueCheckinRouteState current,
    VenueCheckinFailure failure, {
    bool uncertain = false,
  }) {
    state = AsyncData(
      current.copyWith(
        phase: VenueCheckinPhase.degraded,
        failure: failure,
        uncertainMutation: uncertain,
      ),
    );
  }

  VenueCheckinFailure _failureForCode(String code) {
    return VenueCheckinFailure(switch (code) {
      'invalid_code' => VenueCheckinFailureKind.invalidCode,
      'expired_code' => VenueCheckinFailureKind.expiredCode,
      'already_checked_in' => VenueCheckinFailureKind.alreadyCheckedIn,
      'campaign_paused' || 'campaign_inactive' || 'campaign_budget_exhausted' =>
        VenueCheckinFailureKind.campaignUnavailable,
      'auth_required' => VenueCheckinFailureKind.permissionDenied,
      _ => VenueCheckinFailureKind.unknown,
    });
  }
}
