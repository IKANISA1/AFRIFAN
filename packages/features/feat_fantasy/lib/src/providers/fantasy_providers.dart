import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fantasy_models.dart';
import '../repositories/fantasy_repository.dart';

final fantasyRepositoryProvider = Provider<FantasyRepository>((ref) {
  return SupabaseFantasyRepository(client: ref.watch(supabaseClientProvider));
});

final fantasyFeatureEnabledProvider = FutureProvider<bool>((ref) async {
  final config = AppConfigRepository(client: ref.watch(supabaseClientProvider));
  return config.isFeatureEnabled('fantasy_enabled');
});

final fantasyHomePromoEnabledProvider = FutureProvider<bool>((ref) async {
  final config = AppConfigRepository(client: ref.watch(supabaseClientProvider));
  final fantasyEnabled = await config.isFeatureEnabled('fantasy_enabled');
  if (!fantasyEnabled) {
    return false;
  }
  return config.isFeatureEnabled('fantasy_home_promo_enabled');
});

final fantasyCompetitionsProvider =
    FutureProvider<List<FantasyCompetitionSummary>>((ref) async {
      final enabled = await ref.watch(fantasyFeatureEnabledProvider.future);
      if (!enabled) {
        return const <FantasyCompetitionSummary>[];
      }
      return ref.watch(fantasyRepositoryProvider).loadCompetitions();
    });

final fantasyFeaturedCompetitionProvider =
    FutureProvider<FantasyCompetitionSummary?>((ref) async {
      final enabled = await ref.watch(fantasyHomePromoEnabledProvider.future);
      if (!enabled) {
        return null;
      }
      return ref.watch(fantasyRepositoryProvider).loadFeaturedCompetition();
    });

final fantasyCompetitionProvider =
    FutureProvider.family<FantasyCompetitionSummary?, String>((
      ref,
      slug,
    ) async {
      final enabled = await ref.watch(fantasyFeatureEnabledProvider.future);
      if (!enabled || slug.trim().isEmpty) {
        return null;
      }
      return ref.watch(fantasyRepositoryProvider).loadCompetitionBySlug(slug);
    });

final fantasyLeaderboardProvider =
    FutureProvider.family<List<FantasyLeaderboardRow>, String>((
      ref,
      slug,
    ) async {
      final enabled = await ref.watch(fantasyFeatureEnabledProvider.future);
      if (!enabled || slug.trim().isEmpty) {
        return const <FantasyLeaderboardRow>[];
      }
      return ref.watch(fantasyRepositoryProvider).loadLeaderboard(slug);
    });

final fantasyCompetitionContextProvider =
    FutureProvider.family<FantasyEntryContext?, String>((ref, slug) async {
      final enabled = await ref.watch(fantasyFeatureEnabledProvider.future);
      if (!enabled || slug.trim().isEmpty) {
        return null;
      }
      return ref.watch(fantasyRepositoryProvider).loadCompetitionContext(slug);
    });

final fantasyPlayerPoolProvider =
    FutureProvider.family<List<FantasyPlayerPoolItem>, String>((
      ref,
      slug,
    ) async {
      final enabled = await ref.watch(fantasyFeatureEnabledProvider.future);
      if (!enabled || slug.trim().isEmpty) {
        return const <FantasyPlayerPoolItem>[];
      }
      return ref.watch(fantasyRepositoryProvider).loadPlayerPool(slug);
    });

class FantasySquadQuery {
  const FantasySquadQuery({required this.entryId, this.gameweekId});

  final String entryId;
  final String? gameweekId;

  @override
  bool operator ==(Object other) {
    return other is FantasySquadQuery &&
        other.entryId == entryId &&
        other.gameweekId == gameweekId;
  }

  @override
  int get hashCode => Object.hash(entryId, gameweekId);
}

final fantasySquadProvider =
    FutureProvider.family<List<FantasySquadSelection>, FantasySquadQuery>((
      ref,
      query,
    ) async {
      final enabled = await ref.watch(fantasyFeatureEnabledProvider.future);
      if (!enabled || query.entryId.trim().isEmpty) {
        return const <FantasySquadSelection>[];
      }
      return ref
          .watch(fantasyRepositoryProvider)
          .loadSquad(entryId: query.entryId, gameweekId: query.gameweekId);
    });

final fantasySquadBuilderProvider =
    FutureProvider.family<FantasySquadBuilderData?, String>((ref, slug) async {
      final enabled = await ref.watch(fantasyFeatureEnabledProvider.future);
      if (!enabled || slug.trim().isEmpty) {
        return null;
      }

      final repository = ref.watch(fantasyRepositoryProvider);
      final context = await repository.loadCompetitionContext(slug);
      if (context == null) {
        return null;
      }

      final playerPool = await repository.loadPlayerPool(slug);
      final gameweekId = context.gameweek?.id;
      final squad =
          context.entryId != null &&
              gameweekId != null &&
              gameweekId.trim().isNotEmpty
          ? await repository.loadSquad(
              entryId: context.entryId!,
              gameweekId: gameweekId,
            )
          : const <FantasySquadSelection>[];

      return FantasySquadBuilderData(
        context: context,
        playerPool: playerPool,
        squad: squad,
      );
    });
