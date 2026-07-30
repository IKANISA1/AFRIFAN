import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/game_session_controller.dart';
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

final gameSessionGatewayProvider = Provider<GameSessionGateway>(
  (ref) =>
      RepositoryGameSessionGateway(ref.watch(gameSessionRepositoryProvider)),
);

final gameSessionLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final gameSessionMutationTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final gameSessionControllerAccessEnabledProvider = Provider<bool>(
  (ref) => true,
);

final gameSessionControllerStateProvider =
    StateNotifierProvider.family<
      GameSessionController,
      AsyncValue<GameSessionRouteState>,
      GameSessionControllerArgs
    >((ref, args) {
      return GameSessionController(
        ref.watch(gameSessionGatewayProvider),
        sessionId: args.sessionId,
        sessionPlayerId: args.sessionPlayerId,
        loadTimeout: ref.watch(gameSessionLoadTimeoutProvider),
        mutationTimeout: ref.watch(gameSessionMutationTimeoutProvider),
      );
    });
