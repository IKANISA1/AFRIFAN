import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/club_content_models.dart';
import '../repositories/club_content_gateway.dart';
import '../repositories/gikundiro_public_club_gateway.dart';

enum ClubContentFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class ClubContentFailure implements Exception {
  const ClubContentFailure(this.kind);

  final ClubContentFailureKind kind;

  factory ClubContentFailure.fromError(Object error, {required bool isOnline}) {
    if (!isOnline) {
      return const ClubContentFailure(ClubContentFailureKind.offline);
    }
    if (error is TimeoutException) {
      return const ClubContentFailure(ClubContentFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('not authorized') ||
        normalized.contains('rls')) {
      return const ClubContentFailure(ClubContentFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('stale') ||
        normalized.contains('revision') ||
        normalized.contains('version')) {
      return const ClubContentFailure(ClubContentFailureKind.conflict);
    }
    return const ClubContentFailure(ClubContentFailureKind.unknown);
  }

  @override
  String toString() => 'ClubContentFailure(${kind.name})';
}

final clubContentGatewayProvider = Provider<ClubContentGateway>((ref) {
  final mainGateway = SupabaseClubContentGateway(
    ref.watch(supabaseClientProvider),
  );
  final source = ref.watch(gikundiroPublicClientProvider);
  if (source == null) return mainGateway;
  return GikundiroPublicClubGateway(source, mainGateway);
});

/// Maximum time a Club projection may remain in its loading state.
///
/// Club information is read-only and retryable, so a bounded failure is safer
/// than leaving supporters on an indefinite skeleton when the data service is
/// unreachable.
final clubContentLoadTimeoutProvider = Provider<Duration>(
  (_) => const Duration(seconds: 12),
);

final clubOverviewProvider = FutureProvider<ClubOverview?>(
  (ref) => ref
      .watch(clubContentGatewayProvider)
      .loadOverview()
      .timeout(ref.watch(clubContentLoadTimeoutProvider)),
);

final clubNewsProvider = FutureProvider<List<ClubNewsItem>>(
  (ref) => ref
      .watch(clubContentGatewayProvider)
      .loadNews()
      .timeout(ref.watch(clubContentLoadTimeoutProvider)),
);

final clubSquadProvider = FutureProvider<List<ClubSquadMember>>(
  (ref) => ref
      .watch(clubContentGatewayProvider)
      .loadSquad()
      .timeout(ref.watch(clubContentLoadTimeoutProvider)),
);

final clubPlayerProvider = FutureProvider.family<ClubSquadMember?, String>((
  ref,
  id,
) async {
  final gateway = ref.watch(clubContentGatewayProvider);
  if (gateway is ClubEntityGateway) {
    return (gateway as ClubEntityGateway)
        .loadPlayer(id)
        .timeout(ref.watch(clubContentLoadTimeoutProvider));
  }
  return (await ref.watch(
    clubSquadProvider.future,
  )).where((player) => player.id == id).firstOrNull;
});

final clubArticleProvider = FutureProvider.family<ClubNewsItem?, String>((
  ref,
  id,
) async {
  final gateway = ref.watch(clubContentGatewayProvider);
  if (gateway is ClubEntityGateway) {
    return (gateway as ClubEntityGateway)
        .loadArticle(id)
        .timeout(ref.watch(clubContentLoadTimeoutProvider));
  }
  return (await ref.watch(
    clubNewsProvider.future,
  )).where((article) => article.id == id).firstOrNull;
});

final clubMatchesProvider = FutureProvider<List<ClubFixtureItem>>(
  (ref) => ref
      .watch(clubContentGatewayProvider)
      .loadMatches()
      .timeout(ref.watch(clubContentLoadTimeoutProvider)),
);

final clubStandingsProvider = FutureProvider<List<ClubStandingItem>>(
  (ref) => ref
      .watch(clubContentGatewayProvider)
      .loadStandings()
      .timeout(ref.watch(clubContentLoadTimeoutProvider)),
);

final clubHistoryProvider = FutureProvider<List<ClubHistoryItem>>(
  (ref) => ref
      .watch(clubContentGatewayProvider)
      .loadHistory()
      .timeout(ref.watch(clubContentLoadTimeoutProvider)),
);
