import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/contributor_leaderboard.dart';
import '../widgets/match_card.dart';

enum HomeFeedStatus { success, degraded, empty, error }

const String homeFeedLocalFallbackMessage =
    'Live club data is temporarily unavailable. Try again shortly.';

class HomeQuickAction {
  const HomeQuickAction({
    required this.actionKey,
    required this.title,
    required this.route,
    required this.iconKey,
    this.subtitle,
    this.emoji,
    this.countryCode,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String actionKey;
  final String title;
  final String route;
  final String iconKey;
  final String? subtitle;
  final String? emoji;
  final String? countryCode;
  final int sortOrder;
  final bool isActive;

  factory HomeQuickAction.fromJson(Map<String, dynamic> json) {
    return HomeQuickAction(
      actionKey: json['action_key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      iconKey: json['icon_key']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      emoji: json['emoji']?.toString(),
      countryCode: json['country']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
    );
  }
}

class HomeFeedSnapshot {
  const HomeFeedSnapshot({
    this.heroSlides = const <MatchSlide>[],
    this.leaderboard = const <ContributorEntry>[],
    this.quickActions = const <HomeQuickAction>[],
    this.userFet = 0,
    this.fanRank = 0,
    this.status = HomeFeedStatus.empty,
    this.message,
    this.showFixturePlaceholder = false,
  });

  final List<MatchSlide> heroSlides;
  final List<ContributorEntry> leaderboard;
  final List<HomeQuickAction> quickActions;

  /// The current user's own activity balance.
  final int userFet;
  final int fanRank;
  final HomeFeedStatus status;
  final String? message;
  final bool showFixturePlaceholder;

  bool get hasStats => userFet > 0 || fanRank > 0;
  bool get hasLeaderboard => leaderboard.isNotEmpty;
  bool get hasHeroSlides => heroSlides.isNotEmpty;
  bool get hasQuickActions => quickActions.isNotEmpty;
  bool get hasAnyContent => hasHeroSlides || hasStats || hasLeaderboard;
}

@visibleForTesting
HomeFeedSnapshot localHomeFeedFallbackSnapshot() {
  return const HomeFeedSnapshot(
    status: HomeFeedStatus.degraded,
    message: homeFeedLocalFallbackMessage,
    showFixturePlaceholder: true,
  );
}

enum LatestIntelStatus { ready, empty, error }

@visibleForTesting
String homeHeroRouteForStatus(String status) {
  return switch (status.trim().toUpperCase()) {
    'LIVE' || 'HALF-TIME' || 'FULL-TIME' => '/fanzone/match/live',
    _ => '/fanzone?section=league',
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

@visibleForTesting
LatestIntelSnapshot localLatestIntelFallbackSnapshot() {
  return const LatestIntelSnapshot(
    status: LatestIntelStatus.empty,
    message: 'Club updates will appear when published.',
  );
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
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'HomeContentRepository',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      return localHomeFeedFallbackSnapshot();
    }

    List<Map<String, dynamic>> memberships = const <Map<String, dynamic>>[];
    List<Map<String, dynamic>> matches = const <Map<String, dynamic>>[];
    List<HomeQuickAction> quickActions = const <HomeQuickAction>[];
    Object? membershipsError;
    Object? matchesError;
    Object? quickActionsError;

    try {
      final activeCountryCode = RuntimeBranding.displayCountryCode
          .trim()
          .toUpperCase();
      final actionRows = List<Map<String, dynamic>>.from(
        await client
            .from('quick_actions')
            .select()
            .eq('is_active', true)
            .order('sort_order', ascending: true)
            .order('title', ascending: true),
      );

      quickActions = actionRows
          .map(HomeQuickAction.fromJson)
          .where((action) {
            final countryCode = action.countryCode?.trim().toUpperCase();
            return countryCode == null ||
                countryCode.isEmpty ||
                countryCode == activeCountryCode;
          })
          .toList(growable: false);

      // Deduplicate by title — first occurrence (lowest sort_order) wins.
      final seen = <String>{};
      quickActions = quickActions
          .where((action) => seen.add(action.title.toLowerCase()))
          .toList(growable: false);
    } catch (error) {
      quickActionsError = error;
    }

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
      var matchesQuery = client.from('unified_matches').select();
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
      return HomeFeedSnapshot(
        status: HomeFeedStatus.error,
        message: 'Live club data is temporarily unavailable. Pull to refresh.',
        quickActions: quickActions,
      );
    }

    final profile = <String, String>{};
    if (memberships.isNotEmpty) {
      await _loadProfile(
        memberships: memberships,
        currentUserId: currentUserId,
        profile: profile,
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
                profile[userId] ??
                (userId.isEmpty
                    ? '000000'
                    : (100000 + userId.hashCode.abs() % 900000).toString()),
            points: (row['points'] as num?)?.toInt() ?? 0,
          );
        })
        .toList(growable: false);

    // ── Derive the current user's personal activity balance and rank ──
    var userFet = 0;
    var fanRank = 0;
    if (currentUserId != null) {
      final index = memberships.indexWhere(
        (row) => row['user_id']?.toString() == currentUserId,
      );
      if (index != -1) {
        userFet = (memberships[index]['points'] as num?)?.toInt() ?? 0;
        fanRank = index + 1;
      } else {
        // User not in the top-20 batch — look up their row directly.
        await _resolveUserFetAndRank(
          scope: scope,
          currentUserId: currentUserId,
          result: (int fet, int rank) {
            userFet = fet;
            fanRank = rank;
          },
        );
      }
    }

    final heroSlides = matchesError == null
        ? _mapMatchSlides(matches)
        : const <MatchSlide>[];

    if (membershipsError != null || matchesError != null) {
      return HomeFeedSnapshot(
        heroSlides: heroSlides,
        leaderboard: leaderboard,
        quickActions: quickActions,
        userFet: userFet,
        fanRank: fanRank,
        status: HomeFeedStatus.degraded,
        message: quickActionsError == null
            ? 'Some live club data is temporarily unavailable. Pull to refresh.'
            : 'Some live club data is temporarily unavailable. Home shortcuts are unavailable.',
        showFixturePlaceholder: matchesError == null && heroSlides.isEmpty,
      );
    }

    if (heroSlides.isEmpty &&
        leaderboard.isEmpty &&
        userFet == 0 &&
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
      quickActions: quickActions,
      userFet: userFet,
      fanRank: fanRank,
      status: HomeFeedStatus.success,
      showFixturePlaceholder: heroSlides.isEmpty,
    );
  }

  /// Resolves the current user's activity balance and rank when they fall outside
  /// the top-20 batch fetched for the leaderboard.
  Future<void> _resolveUserFetAndRank({
    required ClubScope scope,
    required String currentUserId,
    required void Function(int fet, int rank) result,
  }) async {
    try {
      var query = client
          .from('fan_memberships')
          .select('points')
          .eq('user_id', currentUserId);
      query = ClubScopeResolver(client: client).apply(query, scope);
      final row = await query.maybeSingle();
      if (row == null) return; // Membership is pending for this user.

      final userPoints = (row['points'] as num?)?.toInt() ?? 0;

      // Count how many members have more points to derive rank.
      var countQuery = client
          .from('fan_memberships')
          .select('user_id')
          .gt('points', userPoints);
      countQuery = ClubScopeResolver(client: client).apply(countQuery, scope);
      final higherRows = List<Map<String, dynamic>>.from(await countQuery);
      final rank = higherRows.length + 1;

      result(userPoints, rank);
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'HomeContentRepository',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      // Best-effort — leave values at 0 so stats row hides gracefully.
    }
  }

  Future<void> _loadProfile({
    required List<Map<String, dynamic>> memberships,
    required String? currentUserId,
    required Map<String, String> profile,
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
          profile[currentUserId] = selfAlias;
        }
      } catch (error, stackTrace) {
        AfriLogger.warn(
          'HomeContentRepository',
          'Operation failed (non-critical).',
          error,
          stackTrace,
        );
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
          profile[id] = alias;
        }
      }
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'HomeContentRepository',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
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
      return '$status • $liveMinute\'';
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
      final scope = await ClubScopeResolver(client: client).resolve(null);
      if (!scope.isResolved) {
        return localLatestIntelFallbackSnapshot();
      }
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
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'HomeContentRepository',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      return const LatestIntelSnapshot(
        status: LatestIntelStatus.error,
        message: 'Latest Intel is temporarily unavailable. Pull to refresh.',
      );
    }
  }
}
