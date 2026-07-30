import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'discovery_search.dart';
import 'federated_discovery_search_repository.dart';
import 'local_discovery_search_repository.dart';
import 'recent_discovery_search_store.dart';

final discoverySearchRepositoryProvider = Provider<DiscoverySearchRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return FederatedDiscoverySearchRepository(
    local: const LocalDiscoverySearchRepository(),
    liveSources: <DiscoverySearchSource>[
      SupabaseClubDiscoverySource(client: client),
      SupabaseSupporterDiscoverySource(client: client),
      SupabaseFixtureDiscoverySource(client: client),
      SupabaseCommerceDiscoverySource(client: client),
      SupabaseVenueDiscoverySource(client: client),
    ],
  );
});

final discoverySearchTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final discoverySearchProvider = FutureProvider.autoDispose
    .family<DiscoverySearchResponse, DiscoverySearchQuery>((ref, query) async {
      try {
        return await ref
            .watch(discoverySearchRepositoryProvider)
            .search(query)
            .timeout(ref.watch(discoverySearchTimeoutProvider));
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          DiscoverySearchFailure.fromError(error),
          stackTrace,
        );
      }
    });

final recentDiscoverySearchStoreProvider = Provider<RecentDiscoverySearchStore>(
  (ref) => const SecureRecentDiscoverySearchStore(),
);

class RecentDiscoverySearchesNotifier extends AsyncNotifier<List<String>> {
  static const maxEntries = 5;

  @override
  Future<List<String>> build() async {
    final stored = await ref.read(recentDiscoverySearchStoreProvider).load();
    return _normalize(stored);
  }

  Future<void> add(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) {
      return;
    }
    final current = state.valueOrNull ?? await future;
    final next = _normalize(<String>[
      normalized,
      ...current.where(
        (item) => item.toLowerCase() != normalized.toLowerCase(),
      ),
    ]);
    state = AsyncData<List<String>>(next);
    await ref.read(recentDiscoverySearchStoreProvider).save(next);
  }

  Future<void> clear() async {
    state = const AsyncData<List<String>>(<String>[]);
    await ref.read(recentDiscoverySearchStoreProvider).clear();
  }

  List<String> _normalize(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final normalized = value.trim();
      final identity = normalized.toLowerCase();
      if (normalized.length < 2 ||
          normalized.length > 80 ||
          !seen.add(identity)) {
        continue;
      }
      result.add(normalized);
      if (result.length == maxEntries) {
        break;
      }
    }
    return List<String>.unmodifiable(result);
  }
}

final recentDiscoverySearchesProvider =
    AsyncNotifierProvider<RecentDiscoverySearchesNotifier, List<String>>(
      RecentDiscoverySearchesNotifier.new,
    );
