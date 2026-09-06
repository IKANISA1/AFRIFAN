import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'discovery_search.dart';
import 'local_discovery_search_repository.dart';

abstract interface class DiscoverySearchSource {
  bool supports(DiscoverySearchQuery query);

  Future<List<DiscoveryResult>> search(DiscoverySearchQuery query);
}

/// A failed section carries the healthy results from the same source.
class PartialDiscoverySourceFailure implements Exception {
  const PartialDiscoverySourceFailure(this.results);
  final List<DiscoveryResult> results;
}

String clubSearchFilter(DiscoverySearchQuery query, List<String> fields) {
  final terms = query.text.trim().split(RegExp(r'\s+')).take(8);
  String escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');
  return 'and(${terms.map((term) => 'or(${fields.map((field) => '$field.ilike."%${escape(term)}%"').join(',')})').join(',')})';
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
        } on PartialDiscoverySourceFailure catch (failure) {
          return _SourceResponse(results: failure.results, failed: true);
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
      partial: failedCount > 0,
      offline:
          localResponse.offline ||
          (sourceResults.isNotEmpty &&
              failedCount == sourceResults.length &&
              sourceResults.every((source) => source.results.isEmpty)),
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

final class SupabaseClubDiscoverySource extends SupabaseDiscoverySearchSource {
  SupabaseClubDiscoverySource({required super.client})
    : super(category: DiscoveryCategory.club);

  @override
  Future<List<DiscoveryResult>> search(DiscoverySearchQuery query) async {
    if (!supports(query)) {
      return const <DiscoveryResult>[];
    }

    final scope = await scopeResolver.requireResolved();
    final clubId = scope.clubId;
    if (clubId == null || clubId <= 0) {
      throw StateError('The active club could not be resolved.');
    }

    var failed = false;
    final responses = await Future.wait(
      <Future<List<DiscoveryResult>>>[
        _searchIdentity(query, clubId),
        _searchNews(query, clubId),
        _searchSquad(query, clubId),
        _searchHistory(query, clubId),
        _searchProjects(query, clubId),
      ].map((request) async {
        try {
          return await request;
        } catch (_) {
          failed = true;
          return const <DiscoveryResult>[];
        }
      }),
    );
    final results = responses
        .expand((items) => items)
        .take(SupabaseDiscoverySearchSource.sourceLimit)
        .toList(growable: false);
    if (failed) throw PartialDiscoverySourceFailure(results);
    return results;
  }

  Future<List<DiscoveryResult>> _searchIdentity(
    DiscoverySearchQuery query,
    int clubId,
  ) async {
    final row = await client
        .from('african_football_clubs')
        .select('id, club_name, country_name, league, nickname_brand_identity')
        .eq('id', clubId)
        .maybeSingle();
    if (row == null ||
        !matches(query, <String?>[
          row['club_name']?.toString(),
          row['country_name']?.toString(),
          row['league']?.toString(),
          row['nickname_brand_identity']?.toString(),
        ])) {
      return const <DiscoveryResult>[];
    }
    final name = row['club_name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      return const <DiscoveryResult>[];
    }
    return <DiscoveryResult>[
      DiscoveryResult(
        id: 'club:$clubId',
        title: name,
        description: <String>[
          row['league']?.toString() ?? '',
          row['country_name']?.toString() ?? '',
        ].where((value) => value.trim().isNotEmpty).join(' • '),
        category: DiscoveryCategory.club,
        destination: '/club',
        icon: AfriIcons.stadium,
        keywords: const <String>['club', 'official', 'football'],
      ),
    ];
  }

  Future<List<DiscoveryResult>> _searchNews(
    DiscoverySearchQuery query,
    int clubId,
  ) async {
    final rows = await client
        .from('news_articles')
        .select('id, title, subtitle, category')
        .eq('club_id', clubId)
        .eq('is_published', true)
        .or(clubSearchFilter(query, ['title', 'subtitle', 'category']))
        .order('published_at', ascending: false)
        .limit(SupabaseDiscoverySearchSource.sourceLimit * 3);
    return rows
        .where(
          (row) => matches(query, <String?>[
            row['title']?.toString(),
            row['subtitle']?.toString(),
            row['category']?.toString(),
          ]),
        )
        .map((row) {
          final id = row['id']?.toString() ?? '';
          return DiscoveryResult(
            id: 'club-news:$id',
            title: row['title']?.toString() ?? query.l10n.clubNewsTitle,
            description:
                row['subtitle']?.toString() ?? query.l10n.clubNewsSubtitle,
            category: DiscoveryCategory.club,
            destination: '/club/news/$id',
            icon: AfriIcons.article,
            keywords: const <String>['club', 'news', 'article'],
          );
        })
        .where((result) => !result.destination.endsWith('/'))
        .toList(growable: false);
  }

  Future<List<DiscoveryResult>> _searchSquad(
    DiscoverySearchQuery query,
    int clubId,
  ) async {
    final rows = await client
        .from('squad_players')
        .select('id, name, position, nationality')
        .eq('club_id', clubId)
        .eq('is_active', true)
        .or(clubSearchFilter(query, ['name', 'position', 'nationality']))
        .order('shirt_number')
        .limit(SupabaseDiscoverySearchSource.sourceLimit * 3);
    return rows
        .where(
          (row) => matches(query, <String?>[
            row['name']?.toString(),
            row['position']?.toString(),
            row['nationality']?.toString(),
          ]),
        )
        .map(
          (row) => DiscoveryResult(
            id: 'club-player:${row['id'] ?? ''}',
            title: row['name']?.toString() ?? query.l10n.clubTeamTitle,
            description:
                row['position']?.toString() ?? query.l10n.clubTeamSubtitle,
            category: DiscoveryCategory.club,
            destination:
                '/club/team/${Uri.encodeComponent(row['id'].toString())}',
            icon: AfriIcons.people,
            keywords: const <String>['team', 'squad', 'player'],
          ),
        )
        .toList(growable: false);
  }

  Future<List<DiscoveryResult>> _searchHistory(
    DiscoverySearchQuery query,
    int clubId,
  ) async {
    final rows = await client
        .from('ai_content')
        .select('id, title, subtitle')
        .eq('club_id', clubId)
        .eq('content_type', 'club_history')
        .eq('is_active', true)
        .or(clubSearchFilter(query, ['title', 'subtitle']))
        .order('sort_order')
        .limit(SupabaseDiscoverySearchSource.sourceLimit * 2);
    return rows
        .where(
          (row) => matches(query, <String?>[
            row['title']?.toString(),
            row['subtitle']?.toString(),
          ]),
        )
        .map(
          (row) => DiscoveryResult(
            id: 'club-history:${row['id'] ?? ''}',
            title: row['title']?.toString() ?? query.l10n.clubHistoryTitle,
            description:
                row['subtitle']?.toString() ?? query.l10n.clubHistorySubtitle,
            category: DiscoveryCategory.club,
            destination: '/club/history',
            icon: AfriIcons.history,
            keywords: const <String>['club', 'history', 'heritage'],
          ),
        )
        .toList(growable: false);
  }

  Future<List<DiscoveryResult>> _searchProjects(
    DiscoverySearchQuery query,
    int clubId,
  ) async {
    final rows = await client
        .from('contribution_groups')
        .select('id, name, description')
        .eq('club_id', clubId)
        .eq('is_active', true)
        .or(clubSearchFilter(query, ['name', 'description']))
        .order('created_at', ascending: false)
        .limit(SupabaseDiscoverySearchSource.sourceLimit * 2);
    return rows
        .where(
          (row) => matches(query, <String?>[
            row['name']?.toString(),
            row['description']?.toString(),
          ]),
        )
        .map((row) {
          final id = row['id']?.toString() ?? '';
          return DiscoveryResult(
            id: 'club-project:$id',
            title: row['name']?.toString() ?? query.l10n.clubProjectsTitle,
            description:
                row['description']?.toString() ??
                query.l10n.clubProjectsSubtitle,
            category: DiscoveryCategory.club,
            destination: '/club/projects/$id',
            icon: AfriIcons.business,
            keywords: const <String>['club', 'project', 'contribution'],
          );
        })
        .where((result) => !result.destination.endsWith('/'))
        .toList(growable: false);
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

    final l10n = query.l10n;
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
            description: l10n.searchPublicSupporterDescription,
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

    final l10n = query.l10n;
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
          final home =
              row['home_team']?.toString() ?? l10n.searchHomeTeamFallback;
          final away =
              row['away_team']?.toString() ?? l10n.searchAwayTeamFallback;
          final competition =
              row['competition']?.toString() ?? l10n.searchClubFixtureFallback;
          final onSale = row['is_on_sale'] == true;
          return DiscoveryResult(
            id: 'fixture:$id',
            title: l10n.searchMatchTitle(home, away),
            description: onSale
                ? l10n.searchFixtureOnSaleDescription(competition)
                : l10n.searchFixtureDescription(competition),
            category: DiscoveryCategory.fixtures,
            destination: '/club/fixtures/$id',
            icon: AfriIcons.fixture,
            keywords: const <String>['fixture', 'match', 'live'],
          );
        })
        .where((result) => !result.destination.endsWith('/'))
        .toList(growable: false);
  }
}

final class SupabaseVenueDiscoverySource extends SupabaseDiscoverySearchSource {
  SupabaseVenueDiscoverySource({required super.client})
    : super(category: DiscoveryCategory.services);

  @override
  Future<List<DiscoveryResult>> search(DiscoverySearchQuery query) async {
    if (!supports(query)) {
      return const <DiscoveryResult>[];
    }

    final l10n = query.l10n;
    final scope = await scopeResolver.requireResolved();
    var request = client
        .from('venues')
        .select('id, slug, display_name, city, public_summary')
        .eq('approved_public_profile', true)
        .eq('status', 'approved');
    request = scopeResolver.apply(request, scope);
    final rows = await request
        .order('display_name')
        .limit(SupabaseDiscoverySearchSource.sourceLimit * 3);

    return rows
        .where(
          (row) => matches(query, <String?>[
            row['display_name']?.toString(),
            row['city']?.toString(),
            row['public_summary']?.toString(),
          ]),
        )
        .take(SupabaseDiscoverySearchSource.sourceLimit)
        .map((row) {
          final slug = row['slug']?.toString() ?? '';
          return DiscoveryResult(
            id: 'venue:${row['id'] ?? slug}',
            title: row['display_name']?.toString() ?? l10n.fanZoneVenueCode,
            description:
                row['public_summary']?.toString() ??
                row['city']?.toString() ??
                l10n.searchFanZoneDescription,
            category: DiscoveryCategory.services,
            destination:
                '/fanzone/venue?venue=${Uri.encodeQueryComponent(slug)}',
            icon: AfriIcons.location,
            keywords: const <String>['venue', 'bar', 'watch', 'matchday'],
          );
        })
        .where((result) => !result.destination.endsWith('venue='))
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

    final l10n = query.l10n;
    final scope = await scopeResolver.requireResolved();
    var request = client
        .from('shop_products')
        .select('id, name, description, category, collection')
        .eq('is_active', true);
    request = scopeResolver.apply(request, scope);
    final rows = await request
        .or(
          clubSearchFilter(query, [
            'name',
            'description',
            'category',
            'collection',
          ]),
        )
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
          final name =
              row['name']?.toString() ?? l10n.searchClubProductFallback;
          final category =
              row['category']?.toString() ?? l10n.searchMerchandiseFallback;
          return DiscoveryResult(
            id: 'product:$id',
            title: name,
            description: l10n.searchProductDescription(category),
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
