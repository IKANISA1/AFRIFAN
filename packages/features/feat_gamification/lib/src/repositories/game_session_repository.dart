import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game_session_models.dart';

class GameSessionRepository {
  GameSessionRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  Future<GameSessionControllerState> loadControllerState({
    required String sessionId,
    String? sessionPlayerId,
  }) async {
    final result = await _invokeAction(<String, dynamic>{
      'action': 'get_tv_state',
      'session_id': sessionId,
    });
    if (result is! Map) {
      throw StateError('Game session state returned unexpected data.');
    }

    final data = Map<String, dynamic>.from(result);
    assertTvPayloadIsSafe(data);
    return GameSessionControllerState.fromTvState(
      data,
      sessionPlayerId: sessionPlayerId,
    );
  }

  Future<Object?> submitAnswer({
    required String sessionQuestionId,
    required String sessionPlayerId,
    required String selectedOptionKey,
    required String idempotencyKey,
  }) {
    return _invokeAction(<String, dynamic>{
      'action': 'submit_answer',
      'session_question_id': sessionQuestionId,
      'session_player_id': sessionPlayerId,
      'selected_option_key': selectedOptionKey,
      'idempotency_key': idempotencyKey,
    });
  }

  Future<GameSessionJoinResult> joinSession({
    required String sessionId,
    String? displayName,
  }) async {
    final result = await _invokeAction(<String, dynamic>{
      'action': 'join_session',
      'session_id': sessionId,
      'display_name': displayName,
    });
    if (result is! Map) {
      throw StateError('Game join returned unexpected data.');
    }
    return GameSessionJoinResult.fromJson(Map<String, dynamic>.from(result));
  }

  Future<GameSessionJoinResult> joinSessionByCode({
    required String joinCode,
    String? displayName,
  }) async {
    final result = await _invokeAction(<String, dynamic>{
      'action': 'join_session',
      'join_code': joinCode,
      'display_name': displayName,
    });
    if (result is! Map) {
      throw StateError('Game join returned unexpected data.');
    }
    return GameSessionJoinResult.fromJson(Map<String, dynamic>.from(result));
  }

  Future<Object?> _invokeAction(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke(
      'game-session-action',
      body: body,
    );
    final payload = response.data;
    if (payload is! Map) {
      throw StateError('Game action returned an invalid response.');
    }

    final data = Map<String, dynamic>.from(payload);
    if (data['success'] != true) {
      throw StateError(
        data['error']?.toString() ??
            data['message']?.toString() ??
            'Game action failed.',
      );
    }

    return data['data'];
  }
}

const _tvPayloadForbiddenFieldNames = <String>{
  'correct_answer',
  'correct_answer_key',
  'correct_option',
  'correct_option_key',
  'explanation',
  'answer_explanation',
};

final _tvPayloadForbiddenKeys = _tvPayloadForbiddenFieldNames
    .map(_normalizePayloadKey)
    .toSet();

List<String> findTvPayloadLeakKeys(Object? value, [String path = '']) {
  if (value == null) {
    return const <String>[];
  }
  if (value is List) {
    return [
      for (var index = 0; index < value.length; index++)
        ...findTvPayloadLeakKeys(
          value[index],
          path.isEmpty ? '$index' : '$path.$index',
        ),
    ];
  }
  if (value is! Map) {
    return const <String>[];
  }

  final findings = <String>[];
  for (final entry in value.entries) {
    final key = entry.key.toString();
    final currentPath = path.isEmpty ? key : '$path.$key';
    if (_tvPayloadForbiddenKeys.contains(_normalizePayloadKey(key))) {
      findings.add(currentPath);
    }
    findings.addAll(findTvPayloadLeakKeys(entry.value, currentPath));
  }
  return findings;
}

void assertTvPayloadIsSafe(Object? value) {
  final leakKeys = findTvPayloadLeakKeys(value);
  if (leakKeys.isNotEmpty) {
    throw StateError(
      'TV session state contains answer-only field(s): ${leakKeys.join(', ')}',
    );
  }
}

String _normalizePayloadKey(String key) {
  return key.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toLowerCase();
}
