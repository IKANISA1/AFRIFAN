import 'dart:async';

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
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'Social Hub',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
        bottom: AfriTabBar.line(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Club'),
          ],
        ),
      ),
      body: TabBarView(
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
        _error = 'Supporters are temporarily unavailable.';
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
            title: 'Supporters unavailable',
            message: _error!,
            actionLabel: 'Retry',
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
                  hint: 'Search your friends',
                  prefixIcon: AfriIcons.search,
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              AfriButton(
                onTap: () => context.push('/fanzone/friends'),
                label: 'Browse',
                variant: AfriButtonVariant.ghost,
                fullWidth: false,
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          SocialHubFriendsSection(
            friends: visibleFriends,
            onViewAll: () => context.push('/fanzone/friends'),
            onChallenge: (friend) {
              unawaited(
                context.push('/fanzone/challenge?opponent=${friend.userId}'),
              );
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
      title: 'Your friends',
      trailingLabel: 'View all',
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
                    details: _friendDetails(friend),
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

  String _friendDetails(FetFriendProfile friend) {
    final parts = <String>[
      if (friend.publicUserId != null) '#${friend.publicUserId}',
      friend.tier.toUpperCase(),
      '${friend.balance} FET',
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
              'Online',
              style: TypographyTokens.labelSmall(ColorTokens.success),
            ),
            const SizedBox(width: SpacingTokens.spacing3),
          ],
          AfriButton(
            onTap: onChallenge,
            label: 'Challenge',
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
        _error = 'Club standings are temporarily unavailable.';
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
            title: 'Club standings unavailable',
            message: _error!,
            actionLabel: 'Retry',
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
                  'Club standing',
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  userEntry == null ? 'Unranked' : '#${userEntry.rank}',
                  style: TypographyTokens.displaySmall(
                    ColorTokens.clubAccent,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  userEntry == null
                      ? 'Earn FET to appear in the club table.'
                      : '${userEntry.totalFet} FET earned so far.',
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
      title: 'Leaderboard',
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
                    points: '${fan.totalFet} FET',
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
              '#$rank',
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
              isMe ? '$name (You)' : name,
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
