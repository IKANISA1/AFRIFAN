import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';

/// Unified Social Hub — two-tab layout (Friends / Club Fan Zone).
///
/// Mirrors the fanafrika `SocialHub.tsx` — combines friends list with search,
/// challenge CTAs, club fan zone leaderboard, and club identity card.
///
/// All data is loaded dynamically from the FET repository — no demo data.
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
      body: GradientBackground(
        child: SafeArea(
          child: NestedScrollView(
            physics: const BouncingScrollPhysics(),
            headerSliverBuilder: (context, innerBoxScrolled) => [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing6,
                    0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(AfriIcons.back),
                      ),
                      const SizedBox(width: SpacingTokens.spacing2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COMMUNITY',
                              style: TypographyTokens.editorialFont(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: ColorTokens.onSurfaceVariant,
                                letterSpacing: 1.6,
                              ),
                            ),
                            Text(
                              'SOCIAL HUB',
                              style: TypographyTokens.monolithFont(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tab Bar ──
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  tabBar: TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    indicatorColor: ColorTokens.clubAccent,
                    indicatorWeight: 2.5,
                    labelColor: ColorTokens.clubAccent,
                    unselectedLabelColor: ColorTokens.onSurfaceVariant,
                    labelStyle: TypographyTokens.editorialFont(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'FRIENDS'),
                      Tab(text: 'CLUB FAN ZONE'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _FriendsTab(searchController: _searchController),
                const _ClubFanZoneTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FRIENDS TAB — loads real supporters from FET leaderboard
// ═══════════════════════════════════════════════════════════════════

class _FriendsTab extends ConsumerStatefulWidget {
  const _FriendsTab({required this.searchController});

  final TextEditingController searchController;

  @override
  ConsumerState<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<_FriendsTab> {
  List<FetLeaderboardRow> _supporters = const <FetLeaderboardRow>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final leaders = await ref
          .read(fetRepositoryProvider)
          .loadLeaderboard(limit: 20);
      if (!mounted) return;
      setState(() {
        _supporters = leaders
            .where((entry) => !entry.isCurrentUser)
            .toList(growable: false);
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
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

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        // ── Search + Add Friend ──
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing3,
                ),
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: BorderTokens.ghost(),
                ),
                child: Row(
                  children: [
                    Icon(
                      AfriIcons.search,
                      size: 18,
                      color: ColorTokens.onSurfaceVariant,
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Expanded(
                      child: TextField(
                        controller: widget.searchController,
                        decoration: InputDecoration(
                          hintText: 'Search friends...',
                          hintStyle:
                              TypographyTokens.bodyMedium().copyWith(
                            color: ColorTokens.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        style: TypographyTokens.bodyMedium(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing2),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/fanzone/friends');
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      ColorTokens.clubAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: BorderTokens.all(
                    color: ColorTokens.clubAccent
                        .withValues(alpha: 0.25),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person_add_rounded,
                  size: 22,
                  color: ColorTokens.clubAccent,
                ),
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.04, end: 0, duration: 300.ms),

        const SizedBox(height: SpacingTokens.spacing5),

        if (_supporters.isEmpty)
          const AfriEmptyView(
            compact: true,
            title: 'No supporters found',
            message:
                'Top supporters and friends will appear here as the community grows.',
          )
        else
          // ── Friends List ──
          ClayCard(
            child: Column(
              children: _supporters.asMap().entries.map((entry) {
                final index = entry.key;
                final supporter = entry.value;
                final accuracy =
                    '${supporter.totalFet} FET · ${supporter.tier}';
                return Column(
                  children: [
                    if (index > 0)
                      Divider(
                        height: 1,
                        color: ColorTokens.ghostBorder,
                      ),
                    _FriendRow(
                      name: supporter.displayName,
                      accuracy: accuracy,
                      isOnline: false, // Real online status requires presence
                      onChallenge: () {
                        HapticFeedback.lightImpact();
                        context.push('/fanzone/challenge');
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.name,
    required this.accuracy,
    required this.isOnline,
    required this.onChallenge,
  });

  final String name;
  final String accuracy;
  final bool isOnline;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing1,
        vertical: SpacingTokens.spacing3,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColorTokens.surfaceContainerHigh,
                ),
                alignment: Alignment.center,
                child: const Text('👤', style: TextStyle(fontSize: 18)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline
                        ? ColorTokens.success
                        : ColorTokens.onSurfaceVariant,
                    border: Border.all(
                      color: ColorTokens.surfaceContainer,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TypographyTokens.titleSmall()),
                Text(
                  accuracy,
                  style: TypographyTokens.editorialFont(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          AfriPressFeedback(
            onTap: onChallenge,
            builder: (context, state) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing3,
                vertical: SpacingTokens.spacing2,
              ),
              decoration: BoxDecoration(
                color: state.isPressed
                    ? ColorTokens.clubAccent.withValues(alpha: 0.2)
                    : ColorTokens.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: BorderTokens.ghost(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sports_esports_rounded,
                    size: 14,
                    color: ColorTokens.clubAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Challenge',
                    style: TypographyTokens.editorialFont(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ColorTokens.clubAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CLUB FAN ZONE TAB — loads real club leaderboard from FET repository
// ═══════════════════════════════════════════════════════════════════

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
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(fetRepositoryProvider);
      final leaders = await repo.loadLeaderboard(limit: 25);
      if (!mounted) return;
      setState(() {
        _fans = leaders;
        _currentUserEntry = leaders.cast<FetLeaderboardRow?>().firstWhere(
              (entry) => entry?.isCurrentUser == true,
              orElse: () => null,
            );
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Club fan zone is temporarily unavailable.';
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
            title: 'Fan zone unavailable',
            message: _error!,
            actionLabel: 'Retry',
            onAction: _load,
          ),
        ),
      );
    }

    final userEntry = _currentUserEntry;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        // ── Club Identity Card ──
        Container(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ColorTokens.surfaceContainerLow,
                ColorTokens.surfaceContainerHigh,
              ],
            ),
            borderRadius: ShapeTokens.cardRadius,
            border: BorderTokens.ghost(),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColorTokens.surfaceContainer,
                  border: BorderTokens.ghost(),
                ),
                alignment: Alignment.center,
                child: const Text('🦅', style: TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: SpacingTokens.spacing4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLUB FANS',
                      style: TypographyTokens.monolithFont(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEntry != null
                          ? 'You are ranked #${userEntry.rank} among club fans.'
                          : 'Join the leaderboard by earning FET.',
                      style: TypographyTokens.bodySmall(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.04, end: 0, duration: 400.ms),

        const SizedBox(height: SpacingTokens.spacing6),

        // ── Fan Leaderboard ──
        Text(
          'FAN LEADERBOARD',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),

        if (_fans.isEmpty)
          const AfriEmptyView(
            compact: true,
            title: 'No fans ranked yet',
            message: 'The fan leaderboard will populate as members earn FET.',
          )
        else
          ClayCard(
            child: Column(
              children: [
                ..._fans.take(10).map((fan) {
                  final index = _fans.indexOf(fan);
                  return Column(
                    children: [
                      if (index > 0)
                        Divider(
                          height: 1,
                          color: ColorTokens.ghostBorder,
                        ),
                      _FanLeaderboardRow(
                        rank: fan.rank,
                        name: fan.displayName,
                        points: '${fan.totalFet} FET',
                        isMe: fan.isCurrentUser,
                      ),
                    ],
                  );
                }),
                if (userEntry != null &&
                    userEntry.rank > 10)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: SpacingTokens.spacing2,
                    ),
                    width: double.infinity,
                    color: ColorTokens.surfaceContainerHigh,
                    alignment: Alignment.center,
                    child: Text(
                      '···',
                      style: TypographyTokens.monolithFont(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (userEntry != null &&
                    userEntry.rank > 10)
                  _FanLeaderboardRow(
                    rank: userEntry.rank,
                    name: userEntry.displayName,
                    points: '${userEntry.totalFet} FET',
                    isMe: true,
                  ),
              ],
            ),
          ),
      ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing1,
        vertical: SpacingTokens.spacing3,
      ),
      color: isMe ? ColorTokens.clubAccent.withValues(alpha: 0.06) : null,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TypographyTokens.monolithFont(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: rank <= 3
                    ? ColorTokens.clubAccent
                    : ColorTokens.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColorTokens.surfaceContainerHigh,
            ),
            alignment: Alignment.center,
            child: const Text('👤', style: TextStyle(fontSize: 14)),
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
            style: TypographyTokens.monolithFont(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar delegate ───────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: ColorTokens.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
