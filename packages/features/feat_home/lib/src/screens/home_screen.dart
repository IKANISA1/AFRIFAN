import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/home_feed_provider.dart';
import '../repositories/home_content_repository.dart';
import '../widgets/contributor_leaderboard.dart';
import '../widgets/elite_match_strip.dart';
import '../widgets/latest_intel_section.dart';
import '../widgets/match_card.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/stats_row.dart';

/// Home screen — live matches, quick actions, gamification, and club news.
///
/// Uses [HomeFeedNotifier] via Riverpod for async state management instead
/// of manual setState, enabling proper caching and DevTools integration.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFeed = ref.watch(homeFeedProvider);
    final notifier = ref.read(homeFeedProvider.notifier);

    return Scaffold(
      body: GradientBackground(
        child: RefreshIndicator(
          onRefresh: () => notifier.refresh(),
          color: ColorTokens.clubAccent,
          child: asyncFeed.when(
            loading: () => _buildLoadingView(context),
            error: (error, _) => _buildErrorView(context, ref),
            data: (snapshot) =>
                _buildContent(context, ref, snapshot, asyncFeed.isRefreshing),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _HomeHeroSkeleton()),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenPadding,
              vertical: SpacingTokens.sectionGap,
            ),
            child: AfriSkeletonList(itemCount: 2),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: SpacingTokens.spacing20),
        ),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _HomeHeroStateCard(
            child: AfriErrorView(
              compact: true,
              message: 'Live club data is temporarily unavailable.',
              onRetry: () => ref.read(homeFeedProvider.notifier).refresh(),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: SpacingTokens.spacing20),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    HomeFeedSnapshot snapshot,
    bool isRefreshing,
  ) {
    final refreshKey =
        ref.read(homeFeedProvider.notifier).latestIntelRefreshKey;
    final statusMessage = snapshot.message?.trim();
    final hasStatusMessage =
        statusMessage != null && statusMessage.isNotEmpty;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _buildHeroSurface(context, ref, snapshot)),

        // ── Degraded / partial error banner ──
        if (hasStatusMessage &&
            (snapshot.status == HomeFeedStatus.degraded ||
                (snapshot.status == HomeFeedStatus.error &&
                    snapshot.hasAnyContent)))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.screenPadding,
                SpacingTokens.spacing4,
                SpacingTokens.screenPadding,
                0,
              ),
              child: AfriStateView.offline(
                title: 'Live updates paused',
                message: statusMessage,
                compact: true,
              ),
            ),
          ),

        // ── Primary Actions ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.screenPadding,
              SpacingTokens.sectionGap,
              SpacingTokens.screenPadding,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: EliteButton(
                    label: 'Fan Zone',
                    onTap: () => context.push('/fanzone'),
                    variant: EliteButtonVariant.secondary,
                  ),
                ),
                const SizedBox(width: SpacingTokens.listItemGap),
                Expanded(
                  child: EliteButton(
                    label: 'BioPay',
                    onTap: () => context.push('/BioPay'),
                    variant: EliteButtonVariant.primary,
                  ),
                ),
                const SizedBox(width: SpacingTokens.listItemGap),
                Expanded(
                  child: EliteButton(
                    label: 'Live',
                    onTap: () => context.push('/live'),
                    variant: EliteButtonVariant.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Quick actions rail ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenPadding,
            ),
            child: QuickActionsGrid(actions: snapshot.quickActions),
          ),
        ),

        // ── Stats row ──
        if (snapshot.hasStats) ...[
          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.sectionGap),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.screenPadding,
              ),
              child: _buildAnimatedSection(
                context,
                StatsRow(
                  globalFet: snapshot.userFet,
                  fanRank: snapshot.fanRank,
                  onFetTap: () =>
                      context.push('/fanzone/leaderboard?tab=fet'),
                  onRankTap: () =>
                      context.push('/fanzone/leaderboard?tab=supporters'),
                ),
                delayMs: 200,
              ),
            ),
          ),
        ],

        // ── Leaderboard ──
        if (snapshot.hasLeaderboard) ...[
          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.sectionGap),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.screenPadding,
              ),
              child: _buildAnimatedSection(
                context,
                ContributorLeaderboard(entries: snapshot.leaderboard),
                delayMs: 300,
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(
          child: SizedBox(height: SpacingTokens.sectionGap),
        ),

        // ── Latest Intel ──
        SliverToBoxAdapter(
          child: _buildAnimatedSection(
            context,
            LatestIntelSection(key: ValueKey<int>(refreshKey)),
            delayMs: 400,
          ),
        ),

        // ── Refresh indicator skeleton ──
        if (isRefreshing)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: SpacingTokens.screenPadding,
                vertical: SpacingTokens.sectionGap,
              ),
              child: AfriSkeletonList(itemCount: 2),
            ),
          ),

        const SliverToBoxAdapter(
          child: SizedBox(height: SpacingTokens.spacing20),
        ),
      ],
    );
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

  Widget _buildHeroSurface(
    BuildContext context,
    WidgetRef ref,
    HomeFeedSnapshot snapshot,
  ) {
    final statusMessage = snapshot.message?.trim();

    if (snapshot.status == HomeFeedStatus.error &&
        !snapshot.hasAnyContent &&
        !snapshot.showFixturePlaceholder) {
      return _HomeHeroStateCard(
        child: AfriErrorView(
          compact: true,
          message: statusMessage,
          onRetry: () => ref.read(homeFeedProvider.notifier).refresh(),
        ),
      );
    }

    final slides = snapshot.heroSlides.isNotEmpty
        ? snapshot.heroSlides
        : (snapshot.showFixturePlaceholder ? _buildEmptyHeroSlides() : null);

    if (slides == null || slides.isEmpty) {
      return const _HomeHeroStateCard(
        child: AfriEmptyView(
          compact: true,
          title: 'No fixture yet',
          message: 'The next fixture appears here when confirmed.',
          icon: AfriIcons.fixture,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(ShapeTokens.radiusXl)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(ShapeTokens.radiusXl)),
            child: RepaintBoundary(
              child: _animationsEnabled(context)
                  ? MatchScoreCard(
                      slides: slides,
                    ).animate().fadeIn(duration: 500.ms, curve: Curves.easeOut)
                  : MatchScoreCard(slides: slides),
            ),
          ),
        ),
        if (slides.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: EliteMatchStrip(
              slide: slides.first,
              onTap: slides.first.route != null ? () => context.push(slides.first.route!) : null,
            ),
          ),
      ],
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
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.333;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(ShapeTokens.radiusXl)),
        color: ColorTokens.surface,
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
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(ShapeTokens.radiusXl)),
        color: ColorTokens.surface,
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }
}
