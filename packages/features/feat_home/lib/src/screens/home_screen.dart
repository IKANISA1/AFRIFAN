import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/home_content_repository.dart';
import '../widgets/contributor_leaderboard.dart';
import '../widgets/latest_intel_section.dart';
import '../widgets/match_card.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/stats_row.dart';

/// Home screen — live matches, quick actions, gamification, and club news.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  HomeFeedSnapshot _snapshot = const HomeFeedSnapshot();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final isInitialLoad = _isInitialLoading;
    if (!isInitialLoad) {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      final snapshot = await ref.read(homeFeedRepositoryProvider).load();

      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _snapshot = const HomeFeedSnapshot(
          status: HomeFeedStatus.error,
          message:
              'Live club data is temporarily unavailable. Pull to refresh.',
        );
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Stack(
          children: [
            // ── Scrollable content (hero goes edge-to-edge to top) ──
            RefreshIndicator(
              onRefresh: _loadData,
              color: Theme.of(context).primaryColor,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeroSurface(context)),
                  if (_statusMessage != null &&
                      (_snapshot.status == HomeFeedStatus.degraded ||
                          (_snapshot.status == HomeFeedStatus.error &&
                              _snapshot.hasAnyContent)))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing6,
                          0,
                        ),
                        child: ClayCard(
                          padding: const EdgeInsets.all(SpacingTokens.spacing6),
                          child: Text(
                            _statusMessage!,
                            style: TypographyTokens.bodyMedium(),
                          ),
                        ),
                      ),
                    ),

                  // ── Quick actions rail ──
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing6,
                      ),
                      child: QuickActionsGrid(),
                    ),
                  ),

                  // ── Stats row ──
                  if (_snapshot.hasStats) ...[
                    const SliverToBoxAdapter(
                      child: SizedBox(height: SpacingTokens.spacing8),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.spacing6,
                        ),
                        child: _buildAnimatedSection(
                          context,
                          StatsRow(
                            globalXp: _snapshot.globalXp,
                            fanRank: _snapshot.fanRank,
                          ),
                          delayMs: 200,
                        ),
                      ),
                    ),
                  ],

                  // ── Leaderboard ──
                  if (_snapshot.hasLeaderboard) ...[
                    const SliverToBoxAdapter(
                      child: SizedBox(height: SpacingTokens.spacing8),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.spacing6,
                        ),
                        child: _buildAnimatedSection(
                          context,
                          ContributorLeaderboard(
                            entries: _snapshot.leaderboard,
                          ),
                          delayMs: 300,
                        ),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(
                    child: SizedBox(height: SpacingTokens.spacing8),
                  ),

                  // ── Latest Intel ──
                  SliverToBoxAdapter(
                    child: _buildAnimatedSection(
                      context,
                      const LatestIntelSection(),
                      delayMs: 400,
                    ),
                  ),

                  if (_isInitialLoading || _isRefreshing)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: SpacingTokens.spacing6,
                          vertical: SpacingTokens.spacing8,
                        ),
                        child: AfriSkeletonList(itemCount: 2),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: SpacingTokens.spacing20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? get _statusMessage {
    final message = _snapshot.message?.trim();
    if (message == null || message.isEmpty) {
      return null;
    }
    return message;
  }

  bool _animationsEnabled(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return !(mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true);
  }

  Widget _buildAnimatedSection(
    BuildContext context,
    Widget child, {
    required int delayMs,
  }) {
    if (!_animationsEnabled(context)) {
      return child;
    }

    return child
        .animate(delay: delayMs.ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.04, end: 0, duration: 400.ms);
  }

  Widget _buildHeroSurface(BuildContext context) {
    if (_isInitialLoading) {
      return const _HomeHeroSkeleton();
    }

    if (_snapshot.status == HomeFeedStatus.error &&
        !_snapshot.hasAnyContent &&
        !_snapshot.showFixturePlaceholder) {
      return _HomeHeroStateCard(
        child: AfriErrorView(
          compact: true,
          message: _statusMessage,
          onRetry: _loadData,
        ),
      );
    }

    final slides = _snapshot.heroSlides.isNotEmpty
        ? _snapshot.heroSlides
        : (_snapshot.showFixturePlaceholder ? _buildEmptyHeroSlides() : null);

    if (slides == null || slides.isEmpty) {
      return const _HomeHeroStateCard(
        child: AfriEmptyView(
          compact: true,
          title: 'NO FIXTURE YET',
          message: 'Next fixture will be published when confirmed.',
          icon: Icons.calendar_month_rounded,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: ColorTokens.background.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: RepaintBoundary(
          child: _animationsEnabled(context)
              ? MatchScoreCard(
                  slides: slides,
                ).animate().fadeIn(duration: 500.ms, curve: Curves.easeOut)
              : MatchScoreCard(slides: slides),
        ),
      ),
    );
  }

  List<MatchSlide> _buildEmptyHeroSlides() {
    final homeTeam = RuntimeBranding.displayHomeTeamName;

    return <MatchSlide>[
      MatchSlide(
        homeTeam: homeTeam,
        awayTeam: 'MATCHDAY',
        venue: RuntimeBranding.displayHomeVenueName,
        status: 'NO FIXTURE',
        dateInfo: 'NEXT FIXTURE COMING SOON',
      ),
    ];
  }
}

class _HomeHeroSkeleton extends StatelessWidget {
  const _HomeHeroSkeleton();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.333;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        color: ColorTokens.surfaceContainerHigh,
      ),
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Spacer(flex: 4),
              AfriSkeleton(width: 220, height: 28),
              SizedBox(height: 10),
              AfriSkeleton(width: 170, height: 28),
              SizedBox(height: 14),
              AfriSkeleton(width: 140, height: 12),
              SizedBox(height: 8),
              AfriSkeleton(width: 180, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeroStateCard extends StatelessWidget {
  const _HomeHeroStateCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.333;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        color: ColorTokens.surfaceContainerHigh,
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }
}
