import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/game_session_models.dart';
import 'repositories/game_session_repository.dart';

class GameSessionControllerArgs {
  const GameSessionControllerArgs({
    required this.sessionId,
    this.sessionPlayerId,
  });

  final String sessionId;
  final String? sessionPlayerId;

  @override
  bool operator ==(Object other) {
    return other is GameSessionControllerArgs &&
        other.sessionId == sessionId &&
        other.sessionPlayerId == sessionPlayerId;
  }

  @override
  int get hashCode => Object.hash(sessionId, sessionPlayerId);
}

final gameSessionRepositoryProvider = Provider<GameSessionRepository>(
  (ref) => GameSessionRepository(client: ref.watch(supabaseClientProvider)),
);

final gameSessionControllerStateProvider = FutureProvider.family<
    GameSessionControllerState,
    GameSessionControllerArgs>((ref, args) async {
  final repository = ref.read(gameSessionRepositoryProvider);
  return repository.loadControllerState(
    sessionId: args.sessionId,
    sessionPlayerId: args.sessionPlayerId,
  );
});
