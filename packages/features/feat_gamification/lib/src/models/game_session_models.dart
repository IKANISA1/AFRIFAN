enum GameSessionControllerPhase {
  join,
  waiting,
  answering,
  locked,
  reveal,
  leaderboard,
  reconnecting,
}

class GameAnswerOption {
  const GameAnswerOption({required this.key, required this.label});

  final String key;
  final String label;

  factory GameAnswerOption.fromJson(Map<String, dynamic> json) {
    return GameAnswerOption(
      key: _asString(json['key']) ?? '',
      label: _asString(json['label']) ?? '',
    );
  }
}

class GameLeaderboardRow {
  const GameLeaderboardRow({
    required this.rank,
    required this.teamName,
    required this.score,
  });

  final int rank;
  final String teamName;
  final int score;

  factory GameLeaderboardRow.fromJson(Map<String, dynamic> json) {
    return GameLeaderboardRow(
      rank: _asInt(json['rank']) ?? 0,
      teamName: _asString(json['teamName'] ?? json['team_name']) ?? 'Team',
      score: _asInt(json['score']) ?? 0,
    );
  }
}

class GameSessionJoinResult {
  const GameSessionJoinResult({
    required this.sessionId,
    required this.sessionPlayerId,
    required this.displayName,
    required this.joinCode,
    required this.score,
    this.teamId,
    this.teamName,
  });

  final String sessionId;
  final String sessionPlayerId;
  final String displayName;
  final String joinCode;
  final int score;
  final String? teamId;
  final String? teamName;

  factory GameSessionJoinResult.fromJson(Map<String, dynamic> json) {
    return GameSessionJoinResult(
      sessionId: _asString(json['sessionId'] ?? json['session_id']) ?? '',
      sessionPlayerId:
          _asString(json['sessionPlayerId'] ?? json['session_player_id']) ?? '',
      displayName: _asString(json['displayName'] ?? json['display_name']) ??
          'Supporter',
      joinCode: _asString(json['joinCode'] ?? json['join_code']) ?? '',
      score: _asInt(json['score']) ?? 0,
      teamId: _asString(json['teamId'] ?? json['team_id']),
      teamName: _asString(json['teamName'] ?? json['team_name']),
    );
  }
}

class GameSessionControllerState {
  const GameSessionControllerState({
    required this.sessionId,
    required this.phase,
    required this.joinCode,
    required this.playerName,
    required this.teamName,
    required this.questionLabel,
    required this.prompt,
    required this.options,
    required this.selectedOptionKey,
    required this.statusMessage,
    required this.leaderboard,
    this.sessionQuestionId,
    this.sessionPlayerId,
    this.updatedAt,
  });

  final String sessionId;
  final GameSessionControllerPhase phase;
  final String joinCode;
  final String playerName;
  final String teamName;
  final String questionLabel;
  final String prompt;
  final List<GameAnswerOption> options;
  final String? selectedOptionKey;
  final String statusMessage;
  final List<GameLeaderboardRow> leaderboard;
  final String? sessionQuestionId;
  final String? sessionPlayerId;
  final DateTime? updatedAt;

  bool get canSubmitAnswer =>
      phase == GameSessionControllerPhase.answering &&
      sessionQuestionId != null &&
      sessionQuestionId!.isNotEmpty &&
      sessionPlayerId != null &&
      sessionPlayerId!.isNotEmpty;

  GameSessionControllerState copyWith({
    GameSessionControllerPhase? phase,
    String? sessionPlayerId,
    String? selectedOptionKey,
    String? statusMessage,
  }) {
    return GameSessionControllerState(
      sessionId: sessionId,
      phase: phase ?? this.phase,
      joinCode: joinCode,
      playerName: playerName,
      teamName: teamName,
      questionLabel: questionLabel,
      prompt: prompt,
      options: options,
      selectedOptionKey: selectedOptionKey ?? this.selectedOptionKey,
      statusMessage: statusMessage ?? this.statusMessage,
      leaderboard: leaderboard,
      sessionQuestionId: sessionQuestionId,
      sessionPlayerId: sessionPlayerId ?? this.sessionPlayerId,
      updatedAt: updatedAt,
    );
  }

  factory GameSessionControllerState.fromTvState(
    Map<String, dynamic> json, {
    String? sessionPlayerId,
  }) {
    final currentQuestion = _asMap(
      json['currentQuestion'] ?? json['current_question'],
    );
    final leaderboardRows = _asList(json['leaderboard'])
        .whereType<Map>()
        .map((row) => GameLeaderboardRow.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    final questionTotal =
        _asInt(json['questionTotal'] ?? json['question_total']) ?? 0;
    final questionIndex =
        _asInt(json['questionIndex'] ?? json['question_index']) ?? 0;
    final rawPhase = _asString(
      currentQuestion?['phase'] ?? json['phase'],
    );
    final phase = _phaseFromTvValue(rawPhase);
    final prompt = _asString(currentQuestion?['prompt']);
    final options = _asList(currentQuestion?['options'])
        .whereType<Map>()
        .map(
          (option) => GameAnswerOption.fromJson(
            Map<String, dynamic>.from(option),
          ),
        )
        .where((option) => option.key.isNotEmpty && option.label.isNotEmpty)
        .toList(growable: false);

    return GameSessionControllerState(
      sessionId: _asString(json['sessionId'] ?? json['session_id']) ?? '',
      phase: phase,
      joinCode: _asString(json['joinCode'] ?? json['join_code']) ?? 'WAIT',
      playerName: _asString(json['playerName'] ?? json['player_name']) ??
          'Supporter',
      teamName: _asString(json['teamName'] ?? json['team_name']) ?? 'Fan Zone',
      questionLabel: questionTotal > 0
          ? 'Question $questionIndex of $questionTotal'
          : 'Waiting room',
      prompt: prompt ?? 'Waiting for the host to open the next question.',
      options: options,
      selectedOptionKey: _asString(
        json['selectedOptionKey'] ?? json['selected_option_key'],
      ),
      statusMessage: _statusMessageFor(phase),
      leaderboard: leaderboardRows,
      sessionQuestionId: _asString(currentQuestion?['id']),
      sessionPlayerId: sessionPlayerId ??
          _asString(json['sessionPlayerId'] ?? json['session_player_id']),
      updatedAt: DateTime.tryParse(
        _asString(json['updatedAt'] ?? json['updated_at']) ?? '',
      ),
    );
  }

  static GameSessionControllerState demo(
    String sessionId,
    GameSessionControllerPhase phase, {
    String? sessionPlayerId,
  }) {
    return GameSessionControllerState(
      sessionId: sessionId,
      phase: phase,
      joinCode: 'RAYON24',
      playerName: 'Supporter',
      teamName: 'Blue Zone',
      questionLabel: 'Question 4 of 20',
      prompt: 'Which season delivered the first league title of the modern era?',
      selectedOptionKey: phase == GameSessionControllerPhase.locked ? 'b' : null,
      statusMessage: _statusMessageFor(phase),
      sessionQuestionId: '00000000-0000-4000-8000-000000000004',
      sessionPlayerId: sessionPlayerId,
      options: const [
        GameAnswerOption(key: 'a', label: '1995'),
        GameAnswerOption(key: 'b', label: '1998'),
        GameAnswerOption(key: 'c', label: '2002'),
        GameAnswerOption(key: 'd', label: '2004'),
      ],
      leaderboard: const [
        GameLeaderboardRow(rank: 1, teamName: 'East Stand', score: 820),
        GameLeaderboardRow(rank: 2, teamName: 'Blue Zone', score: 760),
        GameLeaderboardRow(rank: 3, teamName: 'Away Corner', score: 610),
      ],
    );
  }
}

GameSessionControllerPhase _phaseFromTvValue(String? phase) {
  return switch (phase) {
    'open' => GameSessionControllerPhase.answering,
    'claimed' => GameSessionControllerPhase.locked,
    'revealed' => GameSessionControllerPhase.reveal,
    'closed' => GameSessionControllerPhase.leaderboard,
    'lobby' => GameSessionControllerPhase.join,
    'queued' => GameSessionControllerPhase.waiting,
    _ => GameSessionControllerPhase.waiting,
  };
}

String _statusMessageFor(GameSessionControllerPhase phase) {
  return switch (phase) {
    GameSessionControllerPhase.join =>
      'Join the session from the TV code or shared link.',
    GameSessionControllerPhase.waiting =>
      'Waiting for the host to open the next question.',
    GameSessionControllerPhase.answering =>
      'Choose once. The server decides the first correct claim.',
    GameSessionControllerPhase.locked =>
      'Answer submitted. Waiting for claim or reveal.',
    GameSessionControllerPhase.reveal => 'Answer revealed on the TV display.',
    GameSessionControllerPhase.leaderboard =>
      'Round complete. Review team standings.',
    GameSessionControllerPhase.reconnecting =>
      'Reconnecting. Keeping the last confirmed server state.',
  };
}

String? _asString(Object? value) => value is String ? value : value?.toString();

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

List<Object?> _asList(Object? value) => value is List ? value : const [];
