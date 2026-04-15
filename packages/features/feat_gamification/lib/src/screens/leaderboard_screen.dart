import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/prediction_models.dart';
import '../prediction_providers.dart';

/// Enhanced leaderboard with multi-tab (All / Weekly / Monthly),
/// podium display, and pinned "Your Rank" row.
///
/// Mirrors the fanafrika reference `Leaderboard.tsx`.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<PredictionLeaderboardEntry> _rows = const <PredictionLeaderboardEntry>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadLeaderboard();
      }
    });
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentPeriod {
    return switch (_tabController.index) {
      1 => 'weekly',
      2 => 'monthly',
      _ => 'all',
    };
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(predictionRepositoryProvider);
      final leaderboard = await repo.loadLeaderboard(
        limit: 25,
        period: _currentPeriod,
      );

      if (!mounted) return;
      setState(() {
        _rows = leaderboard;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Leaderboard is temporarily unavailable.';
      });
    }
  }

  PredictionLeaderboardEntry? get _currentUserEntry {
    final userId = ref.read(predictionRepositoryProvider).currentUserId;
    if (userId == null || userId.isEmpty) return null;
    return _rows.cast<PredictionLeaderboardEntry?>().firstWhere(
      (e) => e?.userId == userId,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final podium = _rows.take(3).toList(growable: false);
    final userEntry = _currentUserEntry;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: NestedScrollView(
            physics: const BouncingScrollPhysics(),
            headerSliverBuilder: (context, innerBoxScrolled) => [
              // ── App bar ──
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
                      Text(
                        'LEADERBOARD',
                        style: TypographyTokens.monolithFont(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Podium ──
              if (!_isLoading && _error == null && podium.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SpacingTokens.spacing6,
                      SpacingTokens.spacing4,
                      SpacingTokens.spacing6,
                      SpacingTokens.spacing4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _PodiumCard(
                            entry: podium.length > 1 ? podium[1] : null,
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.spacing3),
                        Expanded(
                          child: _PodiumCard(
                            entry: podium.first,
                            featured: true,
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.spacing3),
                        Expanded(
                          child: _PodiumCard(
                            entry: podium.length > 2 ? podium[2] : null,
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.04, end: 0, duration: 400.ms),
                  ),
                ),

              // ── Pinned "Your Rank" row ──
              if (userEntry != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing6,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(SpacingTokens.spacing3),
                      decoration: BoxDecoration(
                        color:
                            ColorTokens.clubAccent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: BorderTokens.all(
                          color: ColorTokens.clubAccent
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            child: Text(
                              '#${userEntry.rank.toString().padLeft(2, '0')}',
                              style: TypographyTokens.monolithFont(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: ColorTokens.clubAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: SpacingTokens.spacing3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      userEntry.displayName,
                                      style:
                                          TypographyTokens.titleSmall(),
                                    ),
                                    const SizedBox(
                                      width: SpacingTokens.spacing2,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ColorTokens.clubAccent,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'YOU',
                                        style:
                                            TypographyTokens.editorialFont(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: ColorTokens.background,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${userEntry.winRate.toStringAsFixed(1)}% accuracy · ${userEntry.wins} wins',
                                  style: TypographyTokens.bodySmall(),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+${userEntry.totalFetEarned} FET',
                            style: TypographyTokens.monolithFont(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ColorTokens.clubAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Tab bar ──
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
                      Tab(text: 'ALL TIME'),
                      Tab(text: 'WEEKLY'),
                      Tab(text: 'MONTHLY'),
                    ],
                  ),
                ),
              ),
            ],
            body: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(SpacingTokens.spacing6),
                    child: AfriSkeletonList(),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(SpacingTokens.spacing6),
                      child: AfriStateView.offline(
                        title: 'Leaderboard unavailable',
                        message: _error!,
                        actionLabel: 'Retry',
                        onAction: _loadLeaderboard,
                      ),
                    ),
                  )
                : _rows.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(SpacingTokens.spacing6),
                      child: AfriEmptyView(
                        title: 'No ranks yet',
                        message:
                            'The board fills as predictions settle.',
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(
                      SpacingTokens.spacing6,
                    ),
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final entry = _rows[index];
                      final currentUserId = ref.read(predictionRepositoryProvider).currentUserId;
                      final isMe =
                          currentUserId != null &&
                          currentUserId.isNotEmpty &&
                          entry.userId == currentUserId;

                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: SpacingTokens.spacing3,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(
                            SpacingTokens.spacing3,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? ColorTokens.clubAccent
                                    .withValues(alpha: 0.10)
                                : ColorTokens.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: isMe
                                ? BorderTokens.all(
                                    color: ColorTokens.clubAccent
                                        .withValues(alpha: 0.3),
                                  )
                                : BorderTokens.ghost(),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '#${entry.rank.toString().padLeft(2, '0')}',
                                  style: TypographyTokens.monolithFont(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: entry.rank <= 3
                                        ? ColorTokens.clubAccent
                                        : ColorTokens.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: SpacingTokens.spacing3,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          entry.displayName,
                                          style: TypographyTokens
                                              .titleSmall(),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(
                                            width:
                                                SpacingTokens.spacing2,
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ColorTokens
                                                  .clubAccent,
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(4),
                                            ),
                                            child: Text(
                                              'YOU',
                                              style: TypographyTokens
                                                  .editorialFont(
                                                fontSize: 9,
                                                fontWeight:
                                                    FontWeight.w800,
                                                color: ColorTokens
                                                    .background,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${entry.winRate.toStringAsFixed(1)}% accuracy · ${entry.wins} wins',
                                      style:
                                          TypographyTokens.bodySmall(),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '+${entry.totalFetEarned} FET',
                                    style:
                                        TypographyTokens.monolithFont(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: ColorTokens.clubAccent,
                                    ),
                                  ),
                                  Text(
                                    '${entry.totalSettled} settled',
                                    style:
                                        TypographyTokens.bodySmall(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate(delay: (index * 40).ms)
                          .fadeIn(duration: 200.ms)
                          .slideY(
                            begin: 0.03,
                            end: 0,
                            duration: 200.ms,
                          );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────

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

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.entry, this.featured = false});

  final PredictionLeaderboardEntry? entry;
  final bool featured;

  String get _medal {
    if (entry == null) return '';
    return switch (entry!.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        children: [
          if (_medal.isNotEmpty)
            Text(_medal, style: const TextStyle(fontSize: 28)),
          if (_medal.isEmpty) const SizedBox(height: 28),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry == null
                ? '--'
                : '#${entry!.rank.toString().padLeft(2, '0')}',
            style: TypographyTokens.monolithFont(
              fontSize: featured ? 28 : 22,
              fontWeight: FontWeight.w800,
              color: featured
                  ? ColorTokens.clubAccent
                  : ColorTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry?.displayName ?? 'No rank',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.bodyMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry == null ? '0 FET' : '+${entry!.totalFetEarned} FET',
            style: TypographyTokens.monolithFont(
              fontSize: featured ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
        ],
      ),
    );
  }
}
