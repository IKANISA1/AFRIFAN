import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/home_feed_provider.dart';
import '../repositories/home_content_repository.dart';
import '../widgets/match_strip.dart';
import '../widgets/contributor_leaderboard.dart';
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
        routePath: '/home',
        child: AfriRefreshIndicator(
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
        SliverToBoxAdapter(child: _HomeTopChrome()),
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
        SliverToBoxAdapter(child: _HomeTopChrome()),
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
    final refreshKey = ref
        .read(homeFeedProvider.notifier)
        .latestIntelRefreshKey;
    final statusMessage = snapshot.message?.trim();
    final hasStatusMessage = statusMessage != null && statusMessage.isNotEmpty;

    // ── Load all placements for home ──
    final heroBlocks = ref.watch(contentBlocksProvider('home_hero'));
    final topBlocks = ref.watch(contentBlocksProvider('home_top'));
    final midBlocks = ref.watch(contentBlocksProvider('home_mid'));
    final bottomBlocks = ref.watch(contentBlocksProvider('home_bottom'));

    final allBlocks = [
      ...heroBlocks,
      ...topBlocks,
      ...midBlocks,
      ...bottomBlocks,
    ];
    final blocks = allBlocks.isEmpty ? _fallbackHomeBlocks : allBlocks;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _HomeTopChrome()),
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

        // ── Dynamic Blocks Loop ──
        ...blocks.map(
          (block) =>
              _buildBlockRenderer(context, ref, block, snapshot, refreshKey),
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

  Widget _buildBlockRenderer(
    BuildContext context,
    WidgetRef ref,
    ContentBlock block,
    HomeFeedSnapshot snapshot,
    int refreshKey,
  ) {
    final widgetKey = block.content['widget']?.toString() ?? '';

    Widget content;
    switch (widgetKey) {
      case 'match_score_card':
        content = _buildHeroSurface(context, ref, snapshot);
        break;
      case 'primary_action_buttons':
        content = Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.screenPadding,
            SpacingTokens.sectionGap,
            SpacingTokens.screenPadding,
            0,
          ),
          child: Row(
            children: [
              FeatureGate(
                featureKey: 'fanzone',
                child: Expanded(
                  child: AfriButton(
                    label: 'Fans',
                    semanticsLabel: 'Fan Zone',
                    onTap: () => context.go('/fanzone'),
                    variant: AfriButtonVariant.secondary,
                  ),
                ),
              ),
              const SizedBox(width: SpacingTokens.listItemGap),
              FeatureGate(
                featureKey: 'contributions',
                child: Expanded(
                  child: AfriButton(
                    label: 'Support',
                    onTap: () => context.go('/fanzone?section=supporters'),
                    variant: AfriButtonVariant.primary,
                  ),
                ),
              ),
              const SizedBox(width: SpacingTokens.listItemGap),
              FeatureGate(
                featureKey: 'live',
                child: Expanded(
                  child: AfriButton(
                    label: 'Live',
                    onTap: () => context.push('/fanzone/match/live'),
                    variant: AfriButtonVariant.secondary,
                  ),
                ),
              ),
            ],
          ),
        );
        break;
      case 'quick_actions_grid':
        content = Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenPadding,
          ),
          child: QuickActionsGrid(actions: snapshot.quickActions),
        );
        break;
      case 'stats_row':
        if (!snapshot.hasStats) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        content = Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenPadding,
            vertical: SpacingTokens.sectionGap,
          ),
          child: StatsRow(
            globalFet: snapshot.userFet,
            fanRank: snapshot.fanRank,
            onFetTap: () => context.go('/fanzone?section=wallet'),
            onRankTap: () => context.go('/fanzone?section=league'),
          ),
        );
        break;
      case 'contributor_leaderboard':
        if (!snapshot.hasLeaderboard) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        content = Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenPadding,
            vertical: SpacingTokens.sectionGap,
          ),
          child: ContributorLeaderboard(entries: snapshot.leaderboard),
        );
        break;
      case 'latest_intel_section':
        content = LatestIntelSection(key: ValueKey<int>(refreshKey));
        break;
      default:
        // Generic fallback for custom blocks
        content = Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenPadding,
            vertical: SpacingTokens.spacing2,
          ),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (block.title != null)
                  Text(block.title!, style: TypographyTokens.titleMedium()),
                if (block.subtitle != null)
                  Text(block.subtitle!, style: TypographyTokens.bodySmall()),
              ],
            ),
          ),
        );
    }

    // Wrap in animations and FeatureGate if necessary
    final wrapped = _buildAnimatedSection(
      context,
      content,
      delayMs: (block.sortOrder ?? 0) * 10,
    );

    if (block.featureKey != null) {
      return SliverToBoxAdapter(
        child: FeatureGate(featureKey: block.featureKey!, child: wrapped),
      );
    }

    return SliverToBoxAdapter(child: wrapped);
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

    final slides = snapshot.heroSlides;

    if (slides.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(ShapeTokens.radiusXl),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(ShapeTokens.radiusXl),
            ),
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
            child: MatchStrip(
              slide: slides.first,
              onTap: slides.first.route != null
                  ? () => context.push(slides.first.route!)
                  : null,
            ),
          ),
      ],
    );
  }
}

const List<ContentBlock> _fallbackHomeBlocks = <ContentBlock>[
  ContentBlock(
    blockKey: 'fallback_home_match_score',
    blockType: 'widget',
    placementKey: 'home_hero',
    content: <String, Object>{'widget': 'match_score_card'},
    sortOrder: 1,
  ),
  ContentBlock(
    blockKey: 'fallback_home_primary_actions',
    blockType: 'widget',
    placementKey: 'home_top',
    content: <String, Object>{'widget': 'primary_action_buttons'},
    sortOrder: 2,
  ),
  ContentBlock(
    blockKey: 'fallback_home_quick_actions',
    blockType: 'widget',
    placementKey: 'home_mid',
    content: <String, Object>{'widget': 'quick_actions_grid'},
    sortOrder: 3,
  ),
  ContentBlock(
    blockKey: 'fallback_home_latest_intel',
    blockType: 'widget',
    placementKey: 'home_bottom',
    content: <String, Object>{'widget': 'latest_intel_section'},
    sortOrder: 4,
  ),
];

class _HomeTopChrome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.screenPadding,
          SpacingTokens.spacing3,
          SpacingTokens.screenPadding,
          SpacingTokens.spacing3,
        ),
        child: AfriTopCommandBar(
          searchHint: 'Find',
          searchSemanticsLabel: 'Search fans, fixtures, wallet',
          onSearchTap: () => context.go('/fanzone'),
          onAvatarTap: () => context.go('/settings'),
          actions: [
            AfriTopCommandAction(
              icon: AfriIcons.notifications,
              label: 'Notifications',
              onTap: () => context.push('/settings/notifications'),
            ),
            AfriTopCommandAction(
              icon: AfriIcons.wallet,
              label: 'Wallet',
              onTap: () => context.go('/fanzone?section=wallet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeroSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.333;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(ShapeTokens.radiusXl),
        ),
        color: ColorTokens.surface,
      ),
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.spacing5 + SpacingTokens.spacing1 / 2,
            SpacingTokens.spacing5,
            SpacingTokens.spacing5 + SpacingTokens.spacing1 / 2,
            SpacingTokens.spacing5 + SpacingTokens.spacing1 / 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Spacer(flex: 4),
              AfriSkeleton(
                width:
                    SpacingTokens.spacing20 * 2 +
                    SpacingTokens.spacing10 +
                    SpacingTokens.spacing5,
                height: SpacingTokens.spacing7,
              ),
              SizedBox(
                height: SpacingTokens.spacing2 + SpacingTokens.spacing1 / 2,
              ),
              AfriSkeleton(
                width:
                    SpacingTokens.spacing20 * 2 +
                    SpacingTokens.spacing2 +
                    SpacingTokens.spacing1 / 2,
                height: SpacingTokens.spacing7,
              ),
              SizedBox(
                height: SpacingTokens.spacing3 + SpacingTokens.spacing1 / 2,
              ),
              AfriSkeleton(
                width:
                    SpacingTokens.spacing20 +
                    SpacingTokens.spacing12 +
                    SpacingTokens.spacing3,
                height: SpacingTokens.spacing3,
              ),
              SizedBox(height: SpacingTokens.spacing2),
              AfriSkeleton(
                width: SpacingTokens.spacing20 * 2 + SpacingTokens.spacing5,
                height: SpacingTokens.spacing3,
              ),
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
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(ShapeTokens.radiusXl),
        ),
        color: ColorTokens.surface,
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }
}
