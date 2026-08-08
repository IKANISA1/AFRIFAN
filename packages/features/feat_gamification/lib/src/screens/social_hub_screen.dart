import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';

class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key});

  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.gameSocialHub,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.gameBack,
        ),
        bottom: AfriTabBar.line(
          controller: _tabController,
          tabs: [
            Tab(text: context.afriL10n.gameFriendsTitle),
            Tab(text: context.afriL10n.gameClub),
          ],
        ),
      ),
      scrollable: false,
      constrainContent: false,
      child: TabBarView(
        controller: _tabController,
        children: [
          _FriendsTab(searchController: _searchController),
          const _ClubFanZoneTab(),
        ],
      ),
    );
  }
}

class _FriendsTab extends ConsumerStatefulWidget {
  const _FriendsTab({required this.searchController});

  final TextEditingController searchController;

  @override
  ConsumerState<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<_FriendsTab> {
  List<FetFriendProfile> _friends = const <FetFriendProfile>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_handleSearchChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_handleSearchChanged);
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    try {
      final friends = await ref
          .read(fetRepositoryProvider)
          .loadFriends(limit: 20);
      if (!mounted) {
        return;
      }
      setState(() {
        _friends = friends;
        _isLoading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'SocialHubScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = context.afriL10n.gameSupportersTemporarilyUnavailable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(SpacingTokens.spacing6),
        child: AfriSkeletonList(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriStateView.offline(
            title: context.afriL10n.gameSupportersUnavailable,
            message: _error!,
            actionLabel: context.afriL10n.gameRetry,
            onAction: _load,
          ),
        ),
      );
    }

    final query = widget.searchController.text.trim().toLowerCase();
    final visibleFriends = query.isEmpty
        ? _friends
        : _friends
              .where((friend) {
                final haystack =
                    '${friend.displayName} ${friend.publicUserId ?? ''} ${friend.tier}'
                        .toLowerCase();
                return haystack.contains(query);
              })
              .toList(growable: false);

    return AfriRefreshIndicator(
      onRefresh: _load,
      color: ColorTokens.clubAccent,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AfriInputField(
                  controller: widget.searchController,
                  hint: context.afriL10n.gameSearchYourFriends,
                  prefixIcon: AfriIcons.search,
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              AfriButton(
                onTap: () => context.push('/fanzone'),
                label: context.afriL10n.gameBrowse,
                variant: AfriButtonVariant.ghost,
                fullWidth: false,
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          SocialHubFriendsSection(
            friends: visibleFriends,
            onViewAll: () => context.push('/fanzone'),
            onChallenge: (friend) {
              unawaited(context.push('/fanzone'));
            },
          ),
        ],
      ),
    );
  }
}

class SocialHubFriendsSection extends StatelessWidget {
  const SocialHubFriendsSection({
    super.key,
    required this.friends,
    required this.onViewAll,
    required this.onChallenge,
  });

  final List<FetFriendProfile> friends;
  final VoidCallback onViewAll;
  final ValueChanged<FetFriendProfile> onChallenge;

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return const SizedBox.shrink(
        key: ValueKey<String>('social-hub-friends-empty'),
      );
    }

    return AfriSectionCard(
      title: context.afriL10n.gameYourFriends,
      trailingLabel: context.afriL10n.gameViewAll,
      onTrailingTap: onViewAll,
      child: Column(
        children: friends
            .asMap()
            .entries
            .map((entry) {
              final friend = entry.value;
              return Column(
                children: [
                  if (entry.key > 0) const AfriDivider(),
                  _FriendRow(
                    name: friend.displayName,
                    details: _friendDetails(context, friend),
                    isOnline: friend.isOnline,
                    onChallenge: () => onChallenge(friend),
                  ),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }

  String _friendDetails(BuildContext context, FetFriendProfile friend) {
    final parts = <String>[
      if (friend.publicUserId != null) '#${friend.publicUserId}',
      friend.tier.toUpperCase(),
      context.afriL10n.gamePointBalance(friend.balance),
    ];
    return parts.join(' · ');
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.name,
    required this.details,
    required this.isOnline,
    required this.onChallenge,
  });

  final String name;
  final String details;
  final bool isOnline;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing3),
      child: Row(
        children: [
          Container(
            width: SpacingTokens.spacing10,
            height: SpacingTokens.spacing10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColorTokens.surfaceContainerLow,
            ),
            alignment: Alignment.center,
            child: Text(
              name.characters.first.toUpperCase(),
              style: TypographyTokens.titleSmall(),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TypographyTokens.titleSmall()),
                const SizedBox(height: SpacingTokens.spacing1 / 2),
                Text(details, style: TypographyTokens.bodySmall()),
              ],
            ),
          ),
          if (isOnline) ...[
            Text(
              context.afriL10n.gameOnline,
              style: TypographyTokens.labelSmall(ColorTokens.success),
            ),
            const SizedBox(width: SpacingTokens.spacing3),
          ],
          AfriButton(
            onTap: onChallenge,
            label: context.afriL10n.gameChallenge,
            variant: AfriButtonVariant.ghost,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}

class _ClubFanZoneTab extends ConsumerStatefulWidget {
  const _ClubFanZoneTab();

  @override
  ConsumerState<_ClubFanZoneTab> createState() => _ClubFanZoneTabState();
}

class _ClubFanZoneTabState extends ConsumerState<_ClubFanZoneTab> {
  List<FetLeaderboardRow> _fans = const <FetLeaderboardRow>[];
  FetLeaderboardRow? _currentUserEntry;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final leaders = await ref
          .read(fetRepositoryProvider)
          .loadLeaderboard(limit: 25);
      if (!mounted) {
        return;
      }
      setState(() {
        _fans = leaders;
        _currentUserEntry = leaders.cast<FetLeaderboardRow?>().firstWhere(
          (entry) => entry?.isCurrentUser == true,
          orElse: () => null,
        );
        _isLoading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'SocialHubScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = context.afriL10n.gameClubStandingsTemporarilyUnavailable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(SpacingTokens.spacing6),
        child: AfriSkeletonList(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriStateView.offline(
            title: context.afriL10n.gameClubStandingsUnavailable,
            message: _error!,
            actionLabel: context.afriL10n.gameRetry,
            onAction: _load,
          ),
        ),
      );
    }

    final userEntry = _currentUserEntry;

    return AfriRefreshIndicator(
      onRefresh: _load,
      color: ColorTokens.clubAccent,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.afriL10n.gameClubStanding,
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  userEntry == null
                      ? context.afriL10n.gameUnranked
                      : context.afriL10n.gameRankHash(userEntry.rank),
                  style: TypographyTokens.displaySmall(
                    ColorTokens.clubAccent,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  userEntry == null
                      ? context.afriL10n.gameEarnPointsForClubTable
                      : context.afriL10n.gamePointsEarnedSoFar(
                          userEntry.totalFet,
                        ),
                  style: TypographyTokens.bodyMedium(),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          SocialHubLeaderboardSection(fans: _fans),
        ],
      ),
    );
  }
}

class SocialHubLeaderboardSection extends StatelessWidget {
  const SocialHubLeaderboardSection({super.key, required this.fans});

  final List<FetLeaderboardRow> fans;

  @override
  Widget build(BuildContext context) {
    if (fans.isEmpty) {
      return const SizedBox.shrink(
        key: ValueKey<String>('social-hub-leaderboard-empty'),
      );
    }

    return AfriSectionCard(
      title: context.afriL10n.gameLeaderboardTitle,
      child: Column(
        children: fans
            .take(10)
            .toList(growable: false)
            .asMap()
            .entries
            .map((entry) {
              final fan = entry.value;
              return Column(
                children: [
                  if (entry.key > 0) const AfriDivider(),
                  _FanLeaderboardRow(
                    rank: fan.rank,
                    name: fan.displayName,
                    points: context.afriL10n.gamePointBalance(fan.totalFet),
                    isMe: fan.isCurrentUser,
                  ),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _FanLeaderboardRow extends StatelessWidget {
  const _FanLeaderboardRow({
    required this.rank,
    required this.name,
    required this.points,
    this.isMe = false,
  });

  final int rank;
  final String name;
  final String points;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: isMe ? ColorTokens.clubAccent.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
      ),
      child: Row(
        children: [
          SizedBox(
            width: SpacingTokens.spacing8,
            child: Text(
              context.afriL10n.gameRankHash(rank),
              style: TypographyTokens.titleSmall(
                rank <= 3
                    ? ColorTokens.clubAccent
                    : ColorTokens.onSurfaceVariant,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Text(
              isMe ? context.afriL10n.gameNameYou(name) : name,
              style: TypographyTokens.titleSmall().copyWith(
                color: isMe ? ColorTokens.clubAccent : null,
              ),
            ),
          ),
          Text(
            points,
            style: TypographyTokens.titleSmall(
              ColorTokens.clubAccent,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
