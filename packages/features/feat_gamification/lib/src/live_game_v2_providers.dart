import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/live_game_v2_entry_controller.dart';
import 'controllers/live_game_v2_participant_controller.dart';
import 'repositories/live_game_v2_repository.dart';

final liveGameV2ExpectedClubIdProvider = Provider<String>((ref) {
  final profileClubId = ref.watch(currentUserProvider)?.clubId.trim();
  if (profileClubId != null && profileClubId.isNotEmpty) {
    return profileClubId;
  }
  final metadataClubId = ref
      .watch(supabaseClientProvider)
      .auth
      .currentUser
      ?.userMetadata?['club_id']
      ?.toString()
      .trim();
  if (metadataClubId != null && metadataClubId.isNotEmpty) {
    return metadataClubId;
  }
  throw StateError('An authenticated club context is required for live games.');
});

final liveGameV2RepositoryProvider = Provider<LiveGameV2Repository>((ref) {
  return LiveGameV2Repository(
    client: ref.watch(supabaseClientProvider),
    expectedClubId: ref.watch(liveGameV2ExpectedClubIdProvider),
  );
});

final liveGameV2RuntimeFactoryProvider =
    Provider<ParticipantLiveGameRuntimeFactory>((ref) {
      return _RepositoryParticipantRuntimeFactory(
        repository: ref.watch(liveGameV2RepositoryProvider),
      );
    });

final participantGameEntryControllerProvider =
    StateNotifierProvider.autoDispose<
      ParticipantGameEntryController,
      ParticipantGameEntryState
    >((ref) {
      return ParticipantGameEntryController(
        discoveryGateway: ref.watch(liveGameV2RepositoryProvider),
        runtimeFactory: ref.watch(liveGameV2RuntimeFactoryProvider),
        expectedClubId: ref.watch(liveGameV2ExpectedClubIdProvider),
      );
    });

class _RepositoryParticipantRuntimeFactory
    implements ParticipantLiveGameRuntimeFactory {
  const _RepositoryParticipantRuntimeFactory({required this.repository});

  final LiveGameV2Repository repository;

  @override
  ParticipantLiveGameController create({
    required String clubId,
    required String sessionId,
  }) {
    if (clubId != repository.expectedClubId) {
      throw StateError('Live game runtime is outside the active club.');
    }
    return ParticipantLiveGameController(
      syncGateway: repository.liveGateway(sessionId),
      answerGateway: repository.answerGateway(sessionId),
      expectedClubId: clubId,
      sessionId: sessionId,
    );
  }
}
