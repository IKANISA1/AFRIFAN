import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/contributor_leaderboard.dart';
import '../widgets/match_card.dart';

enum HomeFeedStatus { success, degraded, empty, error }

class HomeFeedSnapshot {
  const HomeFeedSnapshot({
    this.heroSlides = const <MatchSlide>[],
    this.leaderboard = const <ContributorEntry>[],
    this.globalXp = 0,
    this.fanRank = 0,
    this.status = HomeFeedStatus.empty,
    this.message,
    this.showFixturePlaceholder = false,
  });

  final List<MatchSlide> heroSlides;
  final List<ContributorEntry> leaderboard;
  final int globalXp;
  final int fanRank;
  final HomeFeedStatus status;
  final String? message;
  final bool showFixturePlaceholder;

  bool get hasStats => globalXp > 0 || fanRank > 0;
  bool get hasLeaderboard => leaderboard.isNotEmpty;
  bool get hasHeroSlides => heroSlides.isNotEmpty;
  bool get hasAnyContent => hasHeroSlides || hasStats || hasLeaderboard;
}

enum LatestIntelStatus { ready, empty, error }

@visibleForTesting
String homeHeroRouteForStatus(String status) {
  return switch (status.trim().toUpperCase()) {
    'LIVE' || 'HALF-TIME' || 'FULL-TIME' => '/live',
    _ => '/fanzone/fixtures',
  };
}

class LatestIntelSnapshot {
  const LatestIntelSnapshot({
    this.articles = const <Map<String, dynamic>>[],
    this.status = LatestIntelStatus.empty,
    this.message,
  });

  final List<Map<String, dynamic>> articles;
  final LatestIntelStatus status;
  final String? message;
}

abstract class HomeFeedRepository {
  Future<HomeFeedSnapshot> load();
}

abstract class LatestIntelRepository {
  Future<LatestIntelSnapshot> loadPublishedArticles();
}

final homeFeedRepositoryProvider = Provider<HomeFeedRepository>((ref) {
  return SupabaseHomeFeedRepository(client: ref.watch(supabaseClientProvider));
});

final latestIntelRepositoryProvider = Provider<LatestIntelRepository>((ref) {
  return SupabaseLatestIntelRepository(
    client: ref.watch(supabaseClientProvider),
  );
});

class SupabaseHomeFeedRepository implements HomeFeedRepository {
  SupabaseHomeFeedRepository({required this.client});

  final SupabaseClient client;

  @override
  Future<HomeFeedSnapshot> load() async {
    final currentUserId = client.auth.currentUser?.id;
    late final ClubScope scope;

    try {
      scope = await ClubScopeResolver(client: client).requireResolved();
    } catch (_) {
      return const HomeFeedSnapshot(
        status: HomeFeedStatus.error,
        message: 'Could not resolve the active club. Pull to refresh.',
      );
    }

    List<Map<String, dynamic>> memberships = const <Map<String, dynamic>>[];
    List<Map<String, dynamic>> matches = const <Map<String, dynamic>>[];
    Object? membershipsError;
    Object? matchesError;

    try {
      var membershipsQuery = client.from('fan_memberships').select();
      membershipsQuery = ClubScopeResolver(
        client: client,
      ).apply(membershipsQuery, scope);
      memberships = List<Map<String, dynamic>>.from(
        await membershipsQuery.order('points', ascending: false).limit(20),
      );
    } catch (error) {
      membershipsError = error;
    }

    try {
      var matchesQuery = client.from('matches').select();
      matchesQuery = ClubScopeResolver(
        client: client,
      ).apply(matchesQuery, scope);
      matches = List<Map<String, dynamic>>.from(
        await matchesQuery.order('match_date', ascending: true).limit(5),
      );
    } catch (error) {
      matchesError = error;
    }

    if (membershipsError != null && matchesError != null) {
      return const HomeFeedSnapshot(
        status: HomeFeedStatus.error,
        message: 'Live club data is temporarily unavailable. Pull to refresh.',
      );
    }

    final profileAliases = <String, String>{};
    if (memberships.isNotEmpty) {
      await _loadProfileAliases(
        memberships: memberships,
        currentUserId: currentUserId,
        profileAliases: profileAliases,
      );
    }

    final leaderboard = memberships
        .asMap()
        .entries
        .take(3)
        .map((entry) {
          final rank = entry.key + 1;
          final row = entry.value;
          final userId = row['user_id']?.toString() ?? '';
          return ContributorEntry(
            rank: rank,
            alias:
                profileAliases[userId] ??
                (userId.isEmpty
                    ? '000000'
                    : (100000 + userId.hashCode.abs() % 900000).toString()),
            points: (row['points'] as num?)?.toInt() ?? 0,
          );
        })
        .toList(growable: false);

    final globalXp = memberships.fold<int>(
      0,
      (sum, row) => sum + ((row['points'] as num?)?.toInt() ?? 0),
    );

    var fanRank = 0;
    if (currentUserId != null) {
      final index = memberships.indexWhere(
        (row) => row['user_id']?.toString() == currentUserId,
      );
      fanRank = index == -1 ? 0 : index + 1;
    }

    final heroSlides = matchesError == null
        ? _mapMatchSlides(matches)
        : const <MatchSlide>[];

    if (membershipsError != null || matchesError != null) {
      return HomeFeedSnapshot(
        heroSlides: heroSlides,
        leaderboard: leaderboard,
        globalXp: globalXp,
        fanRank: fanRank,
        status: HomeFeedStatus.degraded,
        message:
            'Some live club data is temporarily unavailable. Pull to refresh.',
        showFixturePlaceholder: matchesError == null && heroSlides.isEmpty,
      );
    }

    if (heroSlides.isEmpty &&
        leaderboard.isEmpty &&
        globalXp == 0 &&
        fanRank == 0) {
      return const HomeFeedSnapshot(
        status: HomeFeedStatus.empty,
        message: 'Matchday data will appear when published.',
        showFixturePlaceholder: true,
      );
    }

    return HomeFeedSnapshot(
      heroSlides: heroSlides,
      leaderboard: leaderboard,
      globalXp: globalXp,
      fanRank: fanRank,
      status: HomeFeedStatus.success,
      showFixturePlaceholder: heroSlides.isEmpty,
    );
  }

  Future<void> _loadProfileAliases({
    required List<Map<String, dynamic>> memberships,
    required String? currentUserId,
    required Map<String, String> profileAliases,
  }) async {
    if (currentUserId != null) {
      try {
        final currentProfile = await client
            .from('profiles')
            .select('public_user_id')
            .eq('id', currentUserId)
            .maybeSingle();
        final selfAlias = currentProfile?['public_user_id']?.toString();
        if (selfAlias != null &&
            selfAlias.isNotEmpty &&
            currentUserId.isNotEmpty) {
          profileAliases[currentUserId] = selfAlias;
        }
      } catch (_) {
        // Keep rendering even if self alias lookup is restricted.
      }
    }

    final userIds = memberships
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (userIds.isEmpty) return;

    try {
      final profiles = await client
          .from('profiles')
          .select('id, public_user_id')
          .inFilter('id', userIds);
      for (final profile in profiles) {
        final id = profile['id']?.toString();
        final alias = profile['public_user_id']?.toString();
        if (id != null && alias != null && alias.isNotEmpty) {
          profileAliases[id] = alias;
        }
      }
    } catch (_) {
      // Alias lookup is best-effort only.
    }
  }

  List<MatchSlide> _mapMatchSlides(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const <MatchSlide>[];
    }

    final now = DateTime.now();
    return rows
        .map((row) {
          final matchDate = DateTime.tryParse(
            row['match_date']?.toString() ?? '',
          );
          final status = _resolveMatchStatus(
            row['match_status']?.toString(),
            matchDate,
            now,
            row['is_on_sale'] == true,
          );
          return MatchSlide(
            imageUrl: row['image_url']?.toString(),
            homeTeam: _compactHeroTeamName(
              _resolveText(
                row['home_team']?.toString(),
                RuntimeBranding.displayHomeTeamName,
              ),
            ),
            awayTeam: _compactHeroTeamName(
              _resolveText(
                row['away_team']?.toString(),
                RuntimeBranding.displayRivalTeamName,
              ),
            ),
            venue: _resolveText(
              row['venue']?.toString(),
              RuntimeBranding.displayHomeVenueName,
            ),
            status: status,
            dateInfo: _formatMatchDateInfo(
              matchDate,
              status,
              (row['live_minute'] as num?)?.toInt(),
            ),
            route: homeHeroRouteForStatus(status),
          );
        })
        .take(3)
        .toList(growable: false);
  }

  String _resolveText(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _compactHeroTeamName(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return value;
    }

    final suffixStripped = normalized.replaceFirst(
      RegExp(r'\s+(FC|SC|CF|AFC)$', caseSensitive: false),
      '',
    );

    if (suffixStripped.length <= 12) {
      return suffixStripped;
    }

    final words = suffixStripped.split(' ');
    if (words.length >= 2) {
      final firstTwo = '${words.first} ${words[1]}';
      if (firstTwo.length <= 12) {
        if (firstTwo.length <= 10) {
          return firstTwo;
        }
        if (words[1].length > 3) {
          return '${words.first} ${words[1][0]}.';
        }
        return words.first;
      }
      return words.first;
    }

    return suffixStripped;
  }

  String _resolveMatchStatus(
    String? rawStatus,
    DateTime? matchDate,
    DateTime now,
    bool isOnSale,
  ) {
    final normalized = rawStatus?.trim().toLowerCase() ?? '';
    if (normalized == 'live') return 'LIVE';
    if (normalized == 'halftime') return 'HALF-TIME';
    if (normalized == 'fulltime') return 'FULL-TIME';
    if (normalized == 'postponed') return 'POSTPONED';
    if (normalized == 'cancelled') return 'CANCELLED';

    final isPast = matchDate != null && matchDate.isBefore(now);
    if (isPast) return 'FULL-TIME';
    return isOnSale ? 'ON SALE' : 'UPCOMING';
  }

  String _formatMatchDateInfo(
    DateTime? matchDate,
    String status,
    int? liveMinute,
  ) {
    if (matchDate == null) {
      return RuntimeBranding.displayCompetitionName.toUpperCase();
    }

    if ((status == 'LIVE' || status == 'HALF-TIME') && liveMinute != null) {
      return '$status • ${liveMinute.toString()}\'';
    }

    final local = matchDate.toLocal();
    final month = _monthLabel(local.month);
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final prefix = status == 'FULL-TIME' ? 'FT' : '$day $month';
    return '$prefix • $hour:$minute';
  }

  String _monthLabel(int month) {
    const months = <String>[
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    if (month < 1 || month > months.length) {
      return 'TBD';
    }
    return months[month - 1];
  }
}

class SupabaseLatestIntelRepository implements LatestIntelRepository {
  SupabaseLatestIntelRepository({required this.client});

  final SupabaseClient client;

  @override
  Future<LatestIntelSnapshot> loadPublishedArticles() async {
    try {
      final scope = await ClubScopeResolver(client: client).requireResolved();
      var query = client
          .from('news_articles')
          .select()
          .eq('is_published', true);
      query = ClubScopeResolver(client: client).apply(query, scope);
      final response = await query
          .order('sort_order', ascending: true)
          .limit(10);

      final articles = List<Map<String, dynamic>>.from(response);
      if (articles.isEmpty) {
        return const LatestIntelSnapshot(
          status: LatestIntelStatus.empty,
          message: 'Club updates will appear when published.',
        );
      }

      return LatestIntelSnapshot(
        status: LatestIntelStatus.ready,
        articles: articles,
      );
    } catch (_) {
      return const LatestIntelSnapshot(
        status: LatestIntelStatus.error,
        message: 'Latest Intel is temporarily unavailable. Pull to refresh.',
      );
    }
  }
}
