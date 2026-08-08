import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game_operations_models.dart';

abstract interface class GameOperationsGateway {
  Future<OwnedDisplayInventory> fetchOwnedDisplays();

  Future<Map<String, dynamic>> claimDisplay({
    required String challenge,
    required String displayName,
    required String scopeType,
    String? venueId,
  });

  Future<Map<String, dynamic>> updateDisplay({
    required String displayId,
    required String displayName,
    required String scopeType,
    required String idempotencyKey,
    String? venueId,
  });

  Future<Map<String, dynamic>> revokeDisplay({
    required String displayId,
    required String idempotencyKey,
  });

  Future<Map<String, dynamic>> recoverDisplay({
    required String displayId,
    required String challenge,
    required String idempotencyKey,
  });

  Future<ManagedGamesInventory> fetchManagedGames();

  Future<ManagedGameSession> fetchManagedGame(String sessionId);

  Future<GamePlannerOptions> fetchPlannerOptions();

  Future<ManagedGameSession> createManagedGame({
    required String packId,
    required DateTime scheduledStartAt,
    required String eligibilityScope,
    required List<String> displayIds,
    required List<String> inviteeUserIds,
    required String idempotencyKey,
  });

  Future<ManagedGameSession> transitionManagedGame({
    required ManagedGameSession session,
    required String requestedPhase,
    required String idempotencyKey,
    DateTime? phaseDeadline,
    String? reason,
  });

  Future<ManagedGameSession> skipManagedGameQuestion({
    required ManagedGameSession session,
    required String nextSessionQuestionId,
    required String idempotencyKey,
    required String reason,
  });

  Future<ManagedGameSession> endManagedGameEarly({
    required ManagedGameSession session,
    required String idempotencyKey,
    required String reason,
  });

  Future<void> assignDisplay({
    required String sessionId,
    required String displayId,
    required String idempotencyKey,
  });

  Future<void> unassignDisplay({
    required String sessionId,
    required String displayId,
    required String idempotencyKey,
  });
}

class GameOperationsRepository implements GameOperationsGateway {
  GameOperationsRepository({
    required SupabaseClient client,
    required String expectedClubId,
    Duration operationTimeout = const Duration(seconds: 12),
  }) : _client = client,
       expectedClubId = expectedClubId.trim(),
       _operationTimeout = operationTimeout {
    if (this.expectedClubId.isEmpty) {
      throw ArgumentError.value(expectedClubId, 'expectedClubId');
    }
    if (operationTimeout <= Duration.zero) {
      throw ArgumentError.value(operationTimeout, 'operationTimeout');
    }
  }

  final SupabaseClient _client;
  final String expectedClubId;
  final Duration _operationTimeout;

  @override
  Future<OwnedDisplayInventory> fetchOwnedDisplays() async {
    return _guard(() async {
      final result = await _client.rpc<Object?>('get_owned_displays_v2');
      return OwnedDisplayInventory.fromJson(
        requireObject(result, 'TV inventory'),
        expectedClubId: expectedClubId,
      );
    });
  }

  @override
  Future<Map<String, dynamic>> claimDisplay({
    required String challenge,
    required String displayName,
    required String scopeType,
    String? venueId,
  }) {
    return _guard(() async {
      final result = await _client.rpc<Object?>(
        'claim_display_bootstrap_challenge_v2',
        params: <String, dynamic>{
          'p_challenge': challenge.trim(),
          'p_display_name': displayName.trim(),
          'p_scope_type': scopeType,
          'p_venue_id': _nullIfEmpty(venueId),
        },
      );
      return requireObject(result, 'TV claim');
    });
  }

  @override
  Future<Map<String, dynamic>> updateDisplay({
    required String displayId,
    required String displayName,
    required String scopeType,
    required String idempotencyKey,
    String? venueId,
  }) {
    return _guard(() async {
      final result = await _client.rpc<Object?>(
        'update_owned_display_v2',
        params: <String, dynamic>{
          'p_display_id': displayId,
          'p_display_name': displayName.trim(),
          'p_scope_type': scopeType,
          'p_venue_id': _nullIfEmpty(venueId),
          'p_idempotency_key': idempotencyKey,
        },
      );
      return requireObject(result, 'TV update');
    });
  }

  @override
  Future<Map<String, dynamic>> revokeDisplay({
    required String displayId,
    required String idempotencyKey,
  }) {
    return _guard(() async {
      final result = await _client.rpc<Object?>(
        'revoke_owned_display_v2',
        params: <String, dynamic>{
          'p_display_id': displayId,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return requireObject(result, 'TV revocation');
    });
  }

  @override
  Future<Map<String, dynamic>> recoverDisplay({
    required String displayId,
    required String challenge,
    required String idempotencyKey,
  }) {
    return _guard(() async {
      final result = await _client.rpc<Object?>(
        'recover_owned_display_from_bootstrap_v2',
        params: <String, dynamic>{
          'p_display_id': displayId,
          'p_challenge': challenge.trim().toUpperCase(),
          'p_idempotency_key': idempotencyKey,
        },
      );
      return requireObject(result, 'TV recovery');
    });
  }

  @override
  Future<ManagedGamesInventory> fetchManagedGames() {
    return _guard(() async {
      final result = await _client.rpc<Object?>('get_managed_game_sessions_v2');
      return ManagedGamesInventory.fromJson(
        requireObject(result, 'Managed games'),
        expectedClubId: expectedClubId,
      );
    });
  }

  @override
  Future<ManagedGameSession> fetchManagedGame(String sessionId) {
    return _guard(() async {
      final result = await _client.rpc<Object?>(
        'get_organizer_game_projection_v2',
        params: <String, dynamic>{'p_session_id': sessionId},
      );
      return ManagedGameSession.fromJson(
        requireObject(result, 'Managed game'),
        expectedClubId: expectedClubId,
      );
    });
  }

  @override
  Future<GamePlannerOptions> fetchPlannerOptions() {
    return _guard(() async {
      final result = await _client.rpc<Object?>('get_game_planner_options_v2');
      return GamePlannerOptions.fromJson(
        requireObject(result, 'Planner options'),
        expectedClubId: expectedClubId,
      );
    });
  }

  @override
  Future<ManagedGameSession> createManagedGame({
    required String packId,
    required DateTime scheduledStartAt,
    required String eligibilityScope,
    required List<String> displayIds,
    required List<String> inviteeUserIds,
    required String idempotencyKey,
  }) {
    return _guard(() async {
      final result = await _client.rpc<Object?>(
        'create_managed_game_session_v2',
        params: <String, dynamic>{
          'p_pack_id': packId,
          'p_scheduled_start_at': scheduledStartAt.toUtc().toIso8601String(),
          'p_eligibility_scope': eligibilityScope,
          'p_display_ids': displayIds,
          'p_invitee_user_ids': inviteeUserIds,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return ManagedGameSession.fromJson(
        requireObject(result, 'Created game'),
        expectedClubId: expectedClubId,
      );
    });
  }

  @override
  Future<ManagedGameSession> transitionManagedGame({
    required ManagedGameSession session,
    required String requestedPhase,
    required String idempotencyKey,
    DateTime? phaseDeadline,
    String? reason,
  }) {
    return _guard(() async {
      await _client.rpc<Object?>(
        'transition_managed_game_session_v2',
        params: <String, dynamic>{
          'p_session_id': session.id,
          'p_requested_phase': requestedPhase,
          'p_expected_session_version': session.sessionVersion,
          'p_idempotency_key': idempotencyKey,
          'p_session_question_id': session.currentQuestion?.id,
          'p_phase_deadline': phaseDeadline?.toUtc().toIso8601String(),
          'p_reason': _nullIfEmpty(reason),
        },
      );
      return fetchManagedGame(session.id);
    });
  }

  @override
  Future<ManagedGameSession> skipManagedGameQuestion({
    required ManagedGameSession session,
    required String nextSessionQuestionId,
    required String idempotencyKey,
    required String reason,
  }) {
    return _guard(() async {
      await _client.rpc<Object?>(
        'skip_managed_game_question_v2',
        params: <String, dynamic>{
          'p_session_id': session.id,
          'p_next_session_question_id': nextSessionQuestionId,
          'p_expected_session_version': session.sessionVersion,
          'p_idempotency_key': idempotencyKey,
          'p_reason': reason.trim(),
        },
      );
      return fetchManagedGame(session.id);
    });
  }

  @override
  Future<ManagedGameSession> endManagedGameEarly({
    required ManagedGameSession session,
    required String idempotencyKey,
    required String reason,
  }) {
    return _guard(() async {
      await _client.rpc<Object?>(
        'end_managed_game_session_v2',
        params: <String, dynamic>{
          'p_session_id': session.id,
          'p_expected_session_version': session.sessionVersion,
          'p_idempotency_key': idempotencyKey,
          'p_reason': reason.trim(),
        },
      );
      return fetchManagedGame(session.id);
    });
  }

  @override
  Future<void> assignDisplay({
    required String sessionId,
    required String displayId,
    required String idempotencyKey,
  }) {
    return _guard(() async {
      await _client.rpc<Object?>(
        'assign_managed_game_display_v2',
        params: <String, dynamic>{
          'p_session_id': sessionId,
          'p_display_id': displayId,
          'p_idempotency_key': idempotencyKey,
        },
      );
    });
  }

  @override
  Future<void> unassignDisplay({
    required String sessionId,
    required String displayId,
    required String idempotencyKey,
  }) {
    return _guard(() async {
      await _client.rpc<Object?>(
        'unassign_managed_game_display_v2',
        params: <String, dynamic>{
          'p_session_id': sessionId,
          'p_display_id': displayId,
          'p_idempotency_key': idempotencyKey,
        },
      );
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(_operationTimeout);
    } on GameOperationsFailure {
      rethrow;
    } on TimeoutException catch (error) {
      throw GameOperationsFailure(GameOperationsFailureKind.timeout, error);
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (_looksOffline(message)) {
        throw GameOperationsFailure(GameOperationsFailureKind.offline, error);
      }
      if (message.contains('not authorized') ||
          message.contains('authentication required') ||
          message.contains('not found or not authorized')) {
        throw GameOperationsFailure(
          GameOperationsFailureKind.permissionDenied,
          error,
        );
      }
      if (message.contains('version') ||
          message.contains('conflict') ||
          message.contains('another active')) {
        throw GameOperationsFailure(GameOperationsFailureKind.conflict, error);
      }
      if (message.contains('invalid') ||
          message.contains('required') ||
          message.contains('exactly 20') ||
          message.contains('supported window')) {
        throw GameOperationsFailure(
          GameOperationsFailureKind.invalidInput,
          error,
        );
      }
      throw GameOperationsFailure(GameOperationsFailureKind.unavailable, error);
    } on FormatException catch (error) {
      throw GameOperationsFailure(GameOperationsFailureKind.unavailable, error);
    } on Object catch (error) {
      if (_looksOffline(error.toString().toLowerCase())) {
        throw GameOperationsFailure(GameOperationsFailureKind.offline, error);
      }
      throw GameOperationsFailure(GameOperationsFailureKind.unavailable, error);
    }
  }
}

bool _looksOffline(String message) {
  return message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('network is unreachable') ||
      message.contains('connection refused') ||
      message.contains('xmlhttprequest error') ||
      message.contains('clientexception');
}

String? _nullIfEmpty(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
