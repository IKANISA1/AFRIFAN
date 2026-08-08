import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/live_game_v2_answer_controller.dart';
import '../controllers/live_game_v2_discovery_controller.dart';
import '../controllers/live_game_v2_reconciler.dart';
import '../controllers/live_game_v2_synchronizer.dart';
import '../models/live_game_v2_discovery_models.dart';
import '../models/live_game_v2_models.dart';

class LiveGameV2Repository implements ParticipantDiscoveryGateway {
  LiveGameV2Repository({
    required SupabaseClient client,
    required String expectedClubId,
  }) : _client = client,
       expectedClubId = _requirePositiveClubId(expectedClubId);

  final SupabaseClient _client;
  final String expectedClubId;

  @override
  Future<ParticipantGameDiscoveryFeed> fetchEligibleSessions({
    String? sessionId,
  }) async {
    final normalizedSessionId = sessionId?.trim();
    final targetedSessionId =
        normalizedSessionId == null || normalizedSessionId.isEmpty
        ? null
        : _requireUuid(normalizedSessionId, 'sessionId');
    final result = await _client.rpc<Object?>(
      'get_eligible_game_sessions_v2',
      params: <String, dynamic>{'p_session_id': targetedSessionId},
    );
    return ParticipantGameDiscoveryFeed.fromJson(
      _requireMap(result, 'Participant discovery'),
      expectedClubId: expectedClubId,
    );
  }

  ParticipantLiveGameGateway liveGateway(String sessionId) {
    return SupabaseParticipantLiveGameGateway(
      client: _client,
      expectedClubId: expectedClubId,
      sessionId: sessionId,
    );
  }

  ParticipantAnswerSubmissionGateway answerGateway(String sessionId) {
    return SupabaseParticipantAnswerGateway(
      client: _client,
      expectedClubId: expectedClubId,
      sessionId: sessionId,
    );
  }
}

class SupabaseParticipantLiveGameGateway implements ParticipantLiveGameGateway {
  SupabaseParticipantLiveGameGateway({
    required SupabaseClient client,
    required String expectedClubId,
    required String sessionId,
  }) : _client = client,
       expectedClubId = _requirePositiveClubId(expectedClubId),
       sessionId = _requireUuid(sessionId, 'sessionId');

  final SupabaseClient _client;
  final String expectedClubId;
  final String sessionId;

  @override
  Future<ParticipantGameProjection> fetchProjection() async {
    final result = await _client.rpc<Object?>(
      'get_participant_game_projection_v2',
      params: <String, dynamic>{'p_session_id': sessionId},
    );
    return ParticipantGameProjection.fromJson(
      _requireMap(result, 'Participant game projection'),
      expectedClubId: expectedClubId,
    );
  }

  @override
  Stream<LiveGameInvalidationHint> watchInvalidationHints() {
    late final StreamController<LiveGameInvalidationHint> controller;
    RealtimeChannel? channel;
    var removed = false;

    Future<void> removeChannel() async {
      if (removed) return;
      removed = true;
      final active = channel;
      channel = null;
      if (active != null) {
        await _client.removeChannel(active);
      }
    }

    controller = StreamController<LiveGameInvalidationHint>.broadcast(
      onListen: () {
        final topic = '$expectedClubId:game_session:$sessionId';
        channel =
            _client
                .channel('participant-game:$topic')
                .onPostgresChanges(
                  event: PostgresChangeEvent.insert,
                  schema: 'africlub_game',
                  table: 'game_events',
                  filter: PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'topic',
                    value: topic,
                  ),
                  callback: (payload) {
                    if (controller.isClosed) return;
                    try {
                      controller.add(
                        LiveGameInvalidationHint.fromJson(payload.newRecord),
                      );
                    } catch (error, stackTrace) {
                      controller.addError(error, stackTrace);
                    }
                  },
                )
              ..subscribe((status, error) {
                if (controller.isClosed ||
                    removed ||
                    status == RealtimeSubscribeStatus.subscribed) {
                  return;
                }
                if (status == RealtimeSubscribeStatus.channelError ||
                    status == RealtimeSubscribeStatus.timedOut ||
                    status == RealtimeSubscribeStatus.closed) {
                  controller.addError(
                    StateError(
                      'Live game updates are temporarily unavailable.',
                    ),
                  );
                }
              });
      },
      onCancel: () async {
        await removeChannel();
        if (!controller.isClosed) await controller.close();
      },
    );

    return controller.stream;
  }
}

class SupabaseParticipantAnswerGateway
    implements ParticipantAnswerSubmissionGateway {
  SupabaseParticipantAnswerGateway({
    required SupabaseClient client,
    required String expectedClubId,
    required String sessionId,
  }) : _client = client,
       expectedClubId = _requirePositiveClubId(expectedClubId),
       sessionId = _requireUuid(sessionId, 'sessionId');

  final SupabaseClient _client;
  final String expectedClubId;
  final String sessionId;

  @override
  Future<ParticipantGameProjection> submitAnswer(
    ParticipantAnswerSubmissionRequest request,
  ) async {
    if (request.clubId != expectedClubId || request.sessionId != sessionId) {
      throw const ParticipantAnswerSubmissionFailure(
        ParticipantAnswerSubmissionFailureKind.permissionDenied,
      );
    }
    final result = await _client.rpc<Object?>(
      'submit_participant_answer_v2',
      params: <String, dynamic>{
        'p_session_id': request.sessionId,
        'p_question_id': request.questionId,
        'p_option_key': request.optionKey,
        'p_expected_session_version': request.expectedSessionVersion,
        'p_expected_question_version': request.expectedQuestionVersion,
        'p_idempotency_key': request.idempotencyKey,
      },
    );
    return ParticipantGameProjection.fromJson(
      _requireMap(result, 'Participant answer projection'),
      expectedClubId: expectedClubId,
    );
  }
}

Map<String, dynamic> _requireMap(Object? value, String label) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw LiveGameContractViolation('$label returned an invalid payload.');
}

String _requirePositiveClubId(String value) {
  final normalized = value.trim();
  final parsed = int.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    throw ArgumentError.value(
      value,
      'expectedClubId',
      'A positive numeric club identity is required.',
    );
  }
  return normalized;
}

String _requireUuid(String value, String name) {
  final normalized = value.trim().toLowerCase();
  if (!_uuidPattern.hasMatch(normalized)) {
    throw ArgumentError.value(value, name, 'A valid UUID is required.');
  }
  return normalized;
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
