import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'discovery_search.dart';
import 'local_discovery_search_repository.dart';

abstract interface class DiscoverySearchSource {
  bool supports(DiscoverySearchQuery query);

  Future<List<DiscoveryResult>> search(DiscoverySearchQuery query);
}

/// Combines the safe local destination catalog with bounded live sources.
///
/// Each live source fails independently. When every requested live source
/// fails, local results remain available and the response is marked offline.
class FederatedDiscoverySearchRepository implements DiscoverySearchRepository {
  const FederatedDiscoverySearchRepository({
    required this.local,
    required this.liveSources,
  });

  final DiscoverySearchRepository local;
  final List<DiscoverySearchSource> liveSources;

  @override
  Future<DiscoverySearchResponse> search(DiscoverySearchQuery query) async {
    final localResponse = await local.search(query);
    final requestedSources = liveSources
        .where((source) => source.supports(query))
        .toList(growable: false);
    if (query.text.trim().length < 2 || requestedSources.isEmpty) {
      return localResponse;
    }

    final sourceResults = await Future.wait(
      requestedSources.map((source) async {
        try {
          return _SourceResponse(results: await source.search(query));
        } catch (_) {
          return const _SourceResponse(failed: true);
        }
      }),
    );
    final failedCount = sourceResults.where((result) => result.failed).length;
    final merged = <DiscoveryResult>[];
    final seen = <String>{};

    for (final result in <DiscoveryResult>[
      ...sourceResults.expand((result) => result.results),
      ...localResponse.results,
    ]) {
      final identity =
          '${result.category.name}:${result.destination}:${result.title.toLowerCase()}';
      if (seen.add(identity)) {
        merged.add(result);
      }
      if (merged.length == LocalDiscoverySearchRepository.maxResults) {
        break;
      }
    }

    return DiscoverySearchResponse(
      results: List<DiscoveryResult>.unmodifiable(merged),
      offline:
          localResponse.offline ||
          (sourceResults.isNotEmpty && failedCount == sourceResults.length),
    );
  }
}

class _SourceResponse {
  const _SourceResponse({
    this.results = const <DiscoveryResult>[],
    this.failed = false,
  });

  final List<DiscoveryResult> results;
  final bool failed;
}

abstract base class SupabaseDiscoverySearchSource
    implements DiscoverySearchSource {
  SupabaseDiscoverySearchSource({
    required SupabaseClient client,
    required this.category,
  }) : _client = client,
       _scopeResolver = ClubScopeResolver(client: client);

  static const sourceLimit = 8;

  final DiscoveryCategory category;
  final SupabaseClient _client;
  final ClubScopeResolver _scopeResolver;

  SupabaseClient get client => _client;
  ClubScopeResolver get scopeResolver => _scopeResolver;

  @override
  bool supports(DiscoverySearchQuery query) {
    return query.category == DiscoveryCategory.all ||
        query.category == category;
  }

  bool matches(DiscoverySearchQuery query, Iterable<String?> fields) {
    final terms = query.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    final searchable = fields.whereType<String>().join(' ').toLowerCase();
    return terms.every(searchable.contains);
  }
}

final class SupabaseSupporterDiscoverySource
    extends SupabaseDiscoverySearchSource {
  SupabaseSupporterDiscoverySource({required super.client})
    : super(category: DiscoveryCategory.supporters);

  @override
  Future<List<DiscoveryResult>> search(DiscoverySearchQuery query) async {
    if (!supports(query)) {
      return const <DiscoveryResult>[];
    }

    final scope = await scopeResolver.requireResolved();
    var request = client
        .from('fan_memberships')
        .select('display_name')
        .ilike('display_name', '%${query.text.trim()}%');
    request = scopeResolver.apply(request, scope);
    final rows = await request
        .order('points', ascending: false)
        .limit(SupabaseDiscoverySearchSource.sourceLimit);

    return rows
        .map((row) => row['display_name']?.toString().trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .take(SupabaseDiscoverySearchSource.sourceLimit)
        .map(
          (name) => DiscoveryResult(
            id: 'public-supporter:${name.toLowerCase()}',
            title: name,
            description: 'Public supporter profile in the club registry.',
            category: DiscoveryCategory.supporters,
            destination:
                '/membership/fans?search=${Uri.encodeQueryComponent(query.text.trim())}',
            icon: AfriIcons.friend,
            keywords: const <String>['supporter', 'fan', 'member'],
          ),
        )
        .toList(growable: false);
  }
}

final class SupabaseFixtureDiscoverySource
    extends SupabaseDiscoverySearchSource {
  SupabaseFixtureDiscoverySource({required super.client})
    : super(category: DiscoveryCategory.fixtures);

  @override
  Future<List<DiscoveryResult>> search(DiscoverySearchQuery query) async {
    if (!supports(query)) {
      return const <DiscoveryResult>[];
    }

    final scope = await scopeResolver.requireResolved();
    var request = client
        .from('unified_matches')
        .select(
          'id, home_team, away_team, competition, venue, match_date, is_on_sale',
        );
    request = scopeResolver.apply(request, scope);
    final rows = await request
        .order('match_date', ascending: true)
        .limit(SupabaseDiscoverySearchSource.sourceLimit * 5);

    return rows
        .where(
          (row) => matches(query, <String?>[
            row['home_team']?.toString(),
            row['away_team']?.toString(),
            row['competition']?.toString(),
            row['venue']?.toString(),
          ]),
        )
        .take(SupabaseDiscoverySearchSource.sourceLimit)
        .map((row) {
          final id = row['id']?.toString() ?? '';
          final home = row['home_team']?.toString() ?? 'Home';
          final away = row['away_team']?.toString() ?? 'Away';
          final competition = row['competition']?.toString() ?? 'Club fixture';
          final onSale = row['is_on_sale'] == true;
          return DiscoveryResult(
            id: 'fixture:$id',
            title: '$home vs $away',
            description: onSale
                ? '$competition fixture with ticket sales available.'
                : '$competition fixture.',
            category: DiscoveryCategory.fixtures,
            destination: '/fanzone/match/$id',
            icon: AfriIcons.fixture,
            keywords: const <String>['fixture', 'match', 'live'],
          );
        })
        .where((result) => !result.destination.endsWith('/'))
        .toList(growable: false);
  }
}

final class SupabaseCommerceDiscoverySource
    extends SupabaseDiscoverySearchSource {
  SupabaseCommerceDiscoverySource({required super.client})
    : super(category: DiscoveryCategory.commerce);

  @override
  Future<List<DiscoveryResult>> search(DiscoverySearchQuery query) async {
    if (!supports(query)) {
      return const <DiscoveryResult>[];
    }

    final scope = await scopeResolver.requireResolved();
    var request = client
        .from('shop_products')
        .select('id, name, description, category, collection')
        .eq('is_active', true);
    request = scopeResolver.apply(request, scope);
    final rows = await request
        .order('sort_order', ascending: true)
        .limit(SupabaseDiscoverySearchSource.sourceLimit * 5);

    return rows
        .where(
          (row) => matches(query, <String?>[
            row['name']?.toString(),
            row['description']?.toString(),
            row['category']?.toString(),
            row['collection']?.toString(),
          ]),
        )
        .take(SupabaseDiscoverySearchSource.sourceLimit)
        .map((row) {
          final id = row['id']?.toString() ?? '';
          final name = row['name']?.toString() ?? 'Club product';
          final category = row['category']?.toString() ?? 'Merchandise';
          return DiscoveryResult(
            id: 'product:$id',
            title: name,
            description: 'Official club shop item in $category.',
            category: DiscoveryCategory.commerce,
            destination: '/shop/product/$id',
            icon: AfriIcons.shop,
            keywords: const <String>['shop', 'product', 'merchandise'],
          );
        })
        .where((result) => !result.destination.endsWith('/'))
        .toList(growable: false);
  }
}
