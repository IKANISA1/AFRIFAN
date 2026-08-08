import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/game_operations_controllers.dart';
import 'repositories/game_operations_repository.dart';

final gameOperationsExpectedClubIdProvider = Provider<String>((ref) {
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
  throw StateError('An authenticated club context is required.');
});

final gameOperationsGatewayProvider = Provider<GameOperationsGateway>((ref) {
  return GameOperationsRepository(
    client: ref.watch(supabaseClientProvider),
    expectedClubId: ref.watch(gameOperationsExpectedClubIdProvider),
  );
});

final displayInventoryControllerProvider =
    StateNotifierProvider.autoDispose<
      DisplayInventoryController,
      DisplayInventoryState
    >((ref) {
      final controller = DisplayInventoryController(
        ref.watch(gameOperationsGatewayProvider),
      );
      unawaited(Future<void>.microtask(controller.load));
      return controller;
    });

final managedGamesControllerProvider =
    StateNotifierProvider.autoDispose<
      ManagedGamesController,
      ManagedGamesState
    >((ref) {
      final controller = ManagedGamesController(
        ref.watch(gameOperationsGatewayProvider),
      );
      unawaited(Future<void>.microtask(controller.load));
      return controller;
    });

final sessionPlannerControllerProvider =
    StateNotifierProvider.autoDispose<
      SessionPlannerController,
      SessionPlannerState
    >((ref) {
      final controller = SessionPlannerController(
        ref.watch(gameOperationsGatewayProvider),
      );
      unawaited(Future<void>.microtask(controller.load));
      return controller;
    });

final liveGameControlControllerProvider = StateNotifierProvider.autoDispose
    .family<LiveGameControlController, LiveGameControlState, String>((
      ref,
      sessionId,
    ) {
      final controller = LiveGameControlController(
        ref.watch(gameOperationsGatewayProvider),
        sessionId,
      );
      unawaited(Future<void>.microtask(controller.load));
      return controller;
    });
