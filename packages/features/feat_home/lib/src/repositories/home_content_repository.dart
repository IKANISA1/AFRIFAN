import 'package:club_data/club_data.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/contributor_leaderboard.dart';
import '../widgets/match_card.dart';

enum HomeFeedStatus { success, degraded, empty, error }

enum HomeFeedNotice {
  liveUnavailable,
  savedContent,
  offlineShortcuts,
  partialUnavailable,
  partialShortcutsUnavailable,
  matchdayPending,
}

enum LatestIntelNotice { unpublished, unavailable }

const List<HomeQuickAction> homeFeedLocalFallbackActions = <HomeQuickAction>[
  HomeQuickAction(
    actionKey: 'tickets',
    title: '',
    route: '/tickets',
    iconKey: 'tickets',
    sortOrder: 10,
  ),
  HomeQuickAction(
    actionKey: 'membership',
    title: '',
    route: '/membership',
    iconKey: 'membership',
    sortOrder: 20,
  ),
  HomeQuickAction(
    actionKey: 'predict',
    title: '',
    route: '/predict',
    iconKey: 'predict',
    sortOrder: 30,
  ),
  HomeQuickAction(
    actionKey: 'shop',
    title: '',
    route: '/shop',
    iconKey: 'shop',
    sortOrder: 40,
  ),
];

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
    this.membershipTier,
    this.membershipPaymentStatus,
    this.status = HomeFeedStatus.empty,
    this.notice,
    this.showFixturePlaceholder = false,
  });

  final List<MatchSlide> heroSlides;
  final List<ContributorEntry> leaderboard;
  final List<HomeQuickAction> quickActions;

  /// The current user's own activity balance.
  final int userFet;
  final int fanRank;
  final String? membershipTier;
  final String? membershipPaymentStatus;
  final HomeFeedStatus status;
  final HomeFeedNotice? notice;
  final bool showFixturePlaceholder;

  bool get hasStats => userFet > 0 || fanRank > 0;
  bool get hasLeaderboard => leaderboard.isNotEmpty;
  bool get hasHeroSlides => heroSlides.isNotEmpty;
  bool get hasQuickActions => quickActions.isNotEmpty;
  bool get hasMembership =>
      membershipTier != null && membershipTier!.trim().isNotEmpty;
  bool get hasAnyContent =>
      hasHeroSlides ||
      hasStats ||
      hasLeaderboard ||
      hasQuickActions ||
      hasMembership;

  HomeFeedSnapshot copyWith({
    List<MatchSlide>? heroSlides,
    List<ContributorEntry>? leaderboard,
    List<HomeQuickAction>? quickActions,
    int? userFet,
    int? fanRank,
    String? membershipTier,
    String? membershipPaymentStatus,
    HomeFeedStatus? status,
    HomeFeedNotice? notice,
    bool? showFixturePlaceholder,
  }) {
    return HomeFeedSnapshot(
      heroSlides: heroSlides ?? this.heroSlides,
      leaderboard: leaderboard ?? this.leaderboard,
      quickActions: quickActions ?? this.quickActions,
      userFet: userFet ?? this.userFet,
      fanRank: fanRank ?? this.fanRank,
      membershipTier: membershipTier ?? this.membershipTier,
      membershipPaymentStatus:
          membershipPaymentStatus ?? this.membershipPaymentStatus,
      status: status ?? this.status,
      notice: notice ?? this.notice,
      showFixturePlaceholder:
          showFixturePlaceholder ?? this.showFixturePlaceholder,
    );
  }
}

@visibleForTesting
class HomeMembershipProjection {
  const HomeMembershipProjection({
    required this.leaderboard,
    required this.hasCurrentMembership,
    required this.userFet,
    required this.fanRank,
    this.membershipTier,
    this.membershipPaymentStatus,
  });

  final List<ContributorEntry> leaderboard;
  final bool hasCurrentMembership;
  final int userFet;
  final int fanRank;
  final String? membershipTier;
  final String? membershipPaymentStatus;
}

/// Activity balances do not confer a paid membership or replace its selected tier.
@visibleForTesting
String? paidHomeMembershipTier(Map<String, dynamic> row) {
  final expiry = DateTime.tryParse(row['expires_at']?.toString() ?? '');
  if (row['payment_status'] != 'verified' ||
      row['status'] != 'active' ||
      expiry == null ||
      !expiry.isAfter(DateTime.now().toUtc())) {
    return null;
  }
  final tier = row['tier']?.toString();
  if (tier == null || tier == 'fan') return null;
  return tier;
}

/// Projects membership rows without mistaking an owner-only RLS result for a
/// public leaderboard. Personal balance and membership state remain available
/// even when cross-user ranking is suppressed.
@visibleForTesting
HomeMembershipProjection projectHomeMembershipRows({
  required List<Map<String, dynamic>> memberships,
  required String? currentUserId,
  required bool allowsCrossUserLeaderboard,
  Map<String, String> publicAliases = const <String, String>{},
}) {
  final leaderboard = allowsCrossUserLeaderboard
      ? memberships
            .asMap()
            .entries
            .take(3)
            .map((entry) {
              final row = entry.value;
              final userId = row['user_id']?.toString() ?? '';
              return ContributorEntry(
                rank: entry.key + 1,
                alias:
                    publicAliases[userId] ??
                    (userId.isEmpty
                        ? '000000'
                        : (100000 + userId.hashCode.abs() % 900000).toString()),
                points: (row['points'] as num?)?.toInt() ?? 0,
              );
            })
            .toList(growable: false)
      : const <ContributorEntry>[];

  if (currentUserId == null) {
    return HomeMembershipProjection(
      leaderboard: leaderboard,
      hasCurrentMembership: false,
      userFet: 0,
      fanRank: 0,
    );
  }

  final currentIndex = memberships.indexWhere(
    (row) => row['user_id']?.toString() == currentUserId,
  );
  if (currentIndex == -1) {
    return HomeMembershipProjection(
      leaderboard: leaderboard,
      hasCurrentMembership: false,
      userFet: 0,
      fanRank: 0,
    );
  }

  final currentMembership = memberships[currentIndex];
  return HomeMembershipProjection(
    leaderboard: leaderboard,
    hasCurrentMembership: true,
    userFet: (currentMembership['points'] as num?)?.toInt() ?? 0,
    fanRank: allowsCrossUserLeaderboard ? currentIndex + 1 : 0,
    membershipTier: paidHomeMembershipTier(currentMembership),
    membershipPaymentStatus: currentMembership['payment_status']?.toString(),
  );
}

HomeFeedSnapshot localHomeFeedFallbackSnapshot() {
  return const HomeFeedSnapshot(
    status: HomeFeedStatus.degraded,
    notice: HomeFeedNotice.liveUnavailable,
    quickActions: homeFeedLocalFallbackActions,
    showFixturePlaceholder: true,
  );
}

enum LatestIntelStatus { ready, empty, error }

@visibleForTesting
String homeHeroRouteForStatus(String status) {
  return switch (status.trim().toUpperCase()) {
    'LIVE' || 'HALF-TIME' || 'FULL-TIME' => '/predict/match/live',
    _ => '/club/fixtures',
  };
}

class LatestIntelSnapshot {
  const LatestIntelSnapshot({
    this.articles = const <Map<String, dynamic>>[],
    this.status = LatestIntelStatus.empty,
    this.notice,
  });

  final List<Map<String, dynamic>> articles;
  final LatestIntelStatus status;
  final LatestIntelNotice? notice;
}

@visibleForTesting
LatestIntelSnapshot localLatestIntelFallbackSnapshot() {
  return const LatestIntelSnapshot(
    status: LatestIntelStatus.empty,
    notice: LatestIntelNotice.unpublished,
  );
}

abstract class HomeFeedRepository {
  Future<HomeFeedSnapshot> load();
}

abstract class LatestIntelRepository {
  Future<LatestIntelSnapshot> loadPublishedArticles();
}

final homeFeedRepositoryProvider = Provider<HomeFeedRepository>((ref) {
  return SupabaseHomeFeedRepository(
    client: ref.watch(supabaseClientProvider),
    storeReleasePolicy: ref.watch(storeReleasePolicyProvider),
  );
});

final latestIntelRepositoryProvider = Provider<LatestIntelRepository>((ref) {
  return SupabaseLatestIntelRepository(
    client: ref.watch(supabaseClientProvider),
  );
});

class SupabaseHomeFeedRepository implements HomeFeedRepository {
  SupabaseHomeFeedRepository({
    required this.client,
    required this.storeReleasePolicy,
    ClubScopeResolver? scopeResolver,
  }) : _scopeResolver = scopeResolver ?? ClubScopeResolver(client: client);

  final ClubScopeResolver _scopeResolver;
  final SupabaseClient client;
  final StoreReleasePolicy storeReleasePolicy;

  @override
  Future<HomeFeedSnapshot> load() async {
    final currentUserId = client.auth.currentUser?.id;
    late final ClubScope scope;

    try {
      scope = await _scopeResolver.requireResolved();
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
    final allowsCrossUserLeaderboard = storeReleasePolicy.allowsCrossUserText;

    Future<void> loadActions() async {
      try {
        final activeCountryCode = RuntimeBranding.displayCountryCode
            .trim()
            .toUpperCase();
        final actionRows = List<Map<String, dynamic>>.from(
          await client
              .from('quick_actions')
              .select(
                'id,action_key,title,subtitle,emoji,route,country,sort_order,'
                'is_active,icon_key',
              )
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
    }

    Future<void> loadMemberships() async {
      try {
        // Membership rows require an authenticated session even when the
        // development policy permits displaying a supporter leaderboard.
        if (currentUserId != null) {
          var membershipsQuery = client
              .from('fan_memberships')
              .select(
                'id,user_id,partner_id,club_id,tier,points,joined_at,chapter,'
                'membership_number,display_name,expires_at,renewed_at,'
                'payment_status,status,created_at,updated_at',
              );
          membershipsQuery = ClubScopeResolver(
            client: client,
          ).apply(membershipsQuery, scope);
          memberships = List<Map<String, dynamic>>.from(
            allowsCrossUserLeaderboard
                ? await membershipsQuery
                      .order('points', ascending: false)
                      .limit(20)
                : await membershipsQuery.eq('user_id', currentUserId).limit(1),
          );
        }
      } catch (error) {
        membershipsError = error;
      }
    }

    Future<void> loadMatches() async {
      try {
        matches = await PublicMatchWindow(
          client,
        ).load(clubId: scope.requiredClubId, limitPerSection: 3);
      } catch (error) {
        matchesError = error;
      }
    }

    await Future.wait([loadActions(), loadMemberships(), loadMatches()]);

    if (membershipsError != null && matchesError != null) {
      return HomeFeedSnapshot(
        status: HomeFeedStatus.error,
        notice: HomeFeedNotice.liveUnavailable,
        quickActions: quickActions,
      );
    }

    final profile = <String, String>{};
    if (allowsCrossUserLeaderboard && memberships.isNotEmpty) {
      await _loadProfile(
        memberships: memberships,
        currentUserId: currentUserId,
        profile: profile,
      );
    }

    final membershipProjection = projectHomeMembershipRows(
      memberships: memberships,
      currentUserId: currentUserId,
      allowsCrossUserLeaderboard: allowsCrossUserLeaderboard,
      publicAliases: profile,
    );
    final leaderboard = membershipProjection.leaderboard;

    // ── Derive the current user's personal activity balance and rank ──
    var userFet = membershipProjection.userFet;
    var fanRank = membershipProjection.fanRank;
    var membershipTier = membershipProjection.membershipTier;
    var membershipPaymentStatus = membershipProjection.membershipPaymentStatus;
    if (currentUserId != null && !membershipProjection.hasCurrentMembership) {
      // The user can fall outside a genuine top-20 batch. In the owner-only
      // store mode this remains a self-row lookup and never derives a rank.
      await _resolveUserFetAndRank(
        scope: scope,
        currentUserId: currentUserId,
        includeCrossUserRank: allowsCrossUserLeaderboard,
        result: (int fet, int rank, String? tier, String? paymentStatus) {
          userFet = fet;
          fanRank = rank;
          membershipTier = tier;
          membershipPaymentStatus = paymentStatus;
        },
      );
    }

    final heroSlides = matchesError == null
        ? _mapMatchSlides(matches)
        : const <MatchSlide>[];

    if (membershipsError != null ||
        matchesError != null ||
        quickActionsError != null) {
      return HomeFeedSnapshot(
        heroSlides: heroSlides,
        leaderboard: leaderboard,
        quickActions: quickActions,
        userFet: userFet,
        fanRank: fanRank,
        membershipTier: membershipTier,
        membershipPaymentStatus: membershipPaymentStatus,
        status: HomeFeedStatus.degraded,
        notice: quickActionsError == null
            ? HomeFeedNotice.partialUnavailable
            : membershipsError == null && matchesError == null
            ? HomeFeedNotice.offlineShortcuts
            : HomeFeedNotice.partialShortcutsUnavailable,
        showFixturePlaceholder: matchesError == null && heroSlides.isEmpty,
      );
    }

    if (heroSlides.isEmpty &&
        leaderboard.isEmpty &&
        userFet == 0 &&
        fanRank == 0) {
      return HomeFeedSnapshot(
        quickActions: quickActions,
        status: HomeFeedStatus.empty,
        notice: HomeFeedNotice.matchdayPending,
        showFixturePlaceholder: true,
      );
    }

    return HomeFeedSnapshot(
      heroSlides: heroSlides,
      leaderboard: leaderboard,
      quickActions: quickActions,
      userFet: userFet,
      fanRank: fanRank,
      membershipTier: membershipTier,
      membershipPaymentStatus: membershipPaymentStatus,
      status: HomeFeedStatus.success,
      showFixturePlaceholder: heroSlides.isEmpty,
    );
  }

  /// Resolves the current user's activity balance and rank when they fall outside
  /// the top-20 batch fetched for the leaderboard.
  Future<void> _resolveUserFetAndRank({
    required ClubScope scope,
    required String currentUserId,
    required bool includeCrossUserRank,
    required void Function(
      int fet,
      int rank,
      String? tier,
      String? paymentStatus,
    )
    result,
  }) async {
    try {
      var query = client
          .from('fan_memberships')
          .select('points, tier, payment_status, status, expires_at')
          .eq('user_id', currentUserId);
      query = ClubScopeResolver(client: client).apply(query, scope);
      final row = await query.maybeSingle();
      if (row == null) return; // Membership is pending for this user.

      final userPoints = (row['points'] as num?)?.toInt() ?? 0;

      var rank = 0;
      if (includeCrossUserRank) {
        // Count how many visible members have more points only when the
        // cross-user dataset itself is authorized for this build.
        var countQuery = client
            .from('fan_memberships')
            .select('user_id')
            .gt('points', userPoints);
        countQuery = ClubScopeResolver(client: client).apply(countQuery, scope);
        final higherRows = List<Map<String, dynamic>>.from(await countQuery);
        rank = higherRows.length + 1;
      }

      result(
        userPoints,
        rank,
        paidHomeMembershipTier(row),
        row['payment_status']?.toString(),
      );
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
          final imageProvenanceId =
              row['image_provenance_id']?.toString().trim() ?? '';
          final imageRightsApproved =
              row['image_rights_approved'] == true &&
              imageProvenanceId.isNotEmpty;
          final status = _resolveMatchStatus(
            row['match_status']?.toString(),
            matchDate,
            now,
            row['is_on_sale'] == true,
          );
          return MatchSlide(
            imageUrl: imageRightsApproved ? row['image_url']?.toString() : null,
            imageProvenanceId: imageProvenanceId.isEmpty
                ? null
                : imageProvenanceId,
            imageRightsApproved: imageRightsApproved,
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
          .select(
            'id,club_id,title,subtitle,image_url,is_published,sort_order,'
            'image_provenance_id,image_rights_approved',
          )
          .eq('is_published', true);
      query = ClubScopeResolver(client: client).apply(query, scope);
      final response = await query
          .order('sort_order', ascending: true)
          .limit(10);

      final articles = List<Map<String, dynamic>>.from(response);
      if (articles.isEmpty) {
        return const LatestIntelSnapshot(
          status: LatestIntelStatus.empty,
          notice: LatestIntelNotice.unpublished,
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
        notice: LatestIntelNotice.unavailable,
      );
    }
  }
}
