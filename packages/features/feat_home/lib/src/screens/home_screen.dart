import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/home_feed_provider.dart';
import '../repositories/home_content_repository.dart';
import '../widgets/contributor_leaderboard.dart';
import '../widgets/latest_intel_section.dart';
import '../widgets/match_card.dart';
import '../widgets/match_strip.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/stats_row.dart';

const List<ContentBlock> _localHomeContentBlocks = <ContentBlock>[
  ContentBlock(
    blockKey: 'local_home_match_score',
    blockType: 'widget',
    placementKey: 'home_hero',
    content: <String, dynamic>{'widget': 'match_score_card'},
    sortOrder: 1,
  ),
  ContentBlock(
    blockKey: 'local_home_primary_actions',
    blockType: 'widget',
    placementKey: 'home_top',
    content: <String, dynamic>{'widget': 'primary_action_buttons'},
    sortOrder: 2,
  ),
  ContentBlock(
    blockKey: 'local_home_quick_actions',
    blockType: 'widget',
    placementKey: 'home_mid',
    content: <String, dynamic>{'widget': 'quick_actions_grid'},
    sortOrder: 3,
  ),
  ContentBlock(
    blockKey: 'local_home_stats',
    blockType: 'widget',
    placementKey: 'home_mid',
    content: <String, dynamic>{'widget': 'stats_row'},
    sortOrder: 4,
  ),
  ContentBlock(
    blockKey: 'local_home_leaderboard',
    blockType: 'widget',
    placementKey: 'home_bottom',
    content: <String, dynamic>{'widget': 'contributor_leaderboard'},
    sortOrder: 5,
  ),
  ContentBlock(
    blockKey: 'local_home_latest_intel',
    blockType: 'widget',
    placementKey: 'home_bottom',
    content: <String, dynamic>{'widget': 'latest_intel_section'},
    sortOrder: 6,
  ),
];

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

    return AfriScreenScaffold(
      showAppBar: false,
      scrollable: false,
      constrainContent: false,
      bottomNavigationAware: true,
      child: GradientBackground(
        routePath: '/home',
        child: AfriRefreshIndicator(
          onRefresh: () => notifier.refresh(),
          color: ColorTokens.clubAccent,
          child: asyncFeed.when(
            loading: () => _buildLoadingView(context),
            error: (error, _) => _buildErrorView(context, ref, error),
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
        const SliverToBoxAdapter(
          child: _HomeTopChrome(key: ValueKey<String>('home-top-chrome')),
        ),
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
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, WidgetRef ref, Object error) {
    final failureContent = _HomeFailureContent.fromError(error);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        const SliverToBoxAdapter(
          child: _HomeTopChrome(key: ValueKey<String>('home-top-chrome')),
        ),
        SliverToBoxAdapter(
          child: _HomeHeroStateCard(
            child: AfriStateView.error(
              compact: true,
              title: failureContent.title,
              message: failureContent.message,
              actionLabel: failureContent.actionLabel,
              onAction: failureContent.actionLabel == null
                  ? null
                  : () => ref.read(homeFeedProvider.notifier).refresh(),
            ),
          ),
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
    final featureConfig = ref.watch(featureConfigServiceProvider);
    final useLocalComposition = !featureConfig.hasConfig;
    final heroBlocks = _homeBlocksForPlacement(
      'home_hero',
      ref.watch(contentBlocksProvider('home_hero')),
      useLocalComposition: useLocalComposition,
    );
    final topBlocks = _homeBlocksForPlacement(
      'home_top',
      ref.watch(contentBlocksProvider('home_top')),
      useLocalComposition: useLocalComposition,
    );
    final midBlocks = _homeBlocksForPlacement(
      'home_mid',
      ref.watch(contentBlocksProvider('home_mid')),
      useLocalComposition: useLocalComposition,
    );
    final bottomBlocks = _homeBlocksForPlacement(
      'home_bottom',
      ref.watch(contentBlocksProvider('home_bottom')),
      useLocalComposition: useLocalComposition,
    );

    final blocks = [...heroBlocks, ...topBlocks, ...midBlocks, ...bottomBlocks];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        const SliverToBoxAdapter(
          child: _HomeTopChrome(key: ValueKey<String>('home-top-chrome')),
        ),
        if (isRefreshing)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.screenPadding,
                SpacingTokens.spacing4,
                SpacingTokens.screenPadding,
                0,
              ),
              child: AfriStateBanner(
                icon: AfriIcons.refresh,
                title: 'Refreshing Home',
                subtitle:
                    'Keeping the current matchday, points, and shortcuts visible while updates load.',
                tone: AfriStateBannerTone.info,
                compact: true,
              ),
            ),
          ),
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
        if (snapshot.heroSlides.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final fanZoneAccess = ref
            .watch(featureConfigServiceProvider)
            .getFeatureAccess('fanzone');
        if (!fanZoneAccess.isVisible) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final heroRoute =
            snapshot.heroSlides.first.route ?? '/fanzone?section=league';
        content = Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.screenPadding,
            SpacingTokens.sectionGap,
            SpacingTokens.screenPadding,
            0,
          ),
          child: AfriButton(
            label: fanZoneAccess.isAvailable
                ? 'Open matchday'
                : 'Matchday unavailable',
            semanticsLabel: fanZoneAccess.isAvailable
                ? 'Open matchday in Fan Zone'
                : 'Matchday in Fan Zone is unavailable',
            enabled: fanZoneAccess.isAvailable,
            onTap: () => context.push(heroRoute),
            variant: AfriButtonVariant.primary,
          ),
        );
        break;
      case 'quick_actions_grid':
        content = Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenPadding,
          ),
          child: QuickActionsGrid(
            actions: snapshot.hasQuickActions
                ? snapshot.quickActions
                : homeFeedLocalFallbackActions,
          ),
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
        .afriAnimate(context, delay: delayMs.ms)
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
      return _HomeHeroStateCard(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing5),
          child: AfriStateView.empty(
            title: 'Matchday',
            message: snapshot.showFixturePlaceholder
                ? 'The next fixture will appear here when it is published.'
                : 'Club fixtures are not available yet.',
            icon: AfriIcons.league,
            actionLabel: 'Open Fan Zone',
            onAction: () => context.go('/fanzone'),
            compact: true,
          ),
        ),
      );
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
                  ? MatchScoreCard(slides: slides)
                        .afriAnimate(context)
                        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
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

List<ContentBlock> _homeBlocksForPlacement(
  String placementKey,
  List<ContentBlock> configuredBlocks, {
  required bool useLocalComposition,
}) {
  if (!useLocalComposition || configuredBlocks.isNotEmpty) {
    return configuredBlocks;
  }

  return _localHomeContentBlocks
      .where((block) => block.placementKey == placementKey)
      .toList(growable: false);
}

class _HomeTopChrome extends StatelessWidget {
  const _HomeTopChrome({super.key});

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
          onSearchTap: () => context.push('/search'),
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
    final height = homeHeroHeight(context);
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
    final height = homeHeroHeight(context);
    return Container(
      constraints: BoxConstraints(minHeight: height),
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

class _HomeFailureContent {
  const _HomeFailureContent({
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String? actionLabel;

  factory _HomeFailureContent.fromError(Object error) {
    final failure = HomeFeedFailure.fromError(error);
    return switch (failure.kind) {
      HomeFeedFailureKind.permissionDenied => const _HomeFailureContent(
        title: 'Home access not available',
        message:
            'Your account cannot load Home right now. Contact support if this should be available.',
        actionLabel: null,
      ),
      HomeFeedFailureKind.conflict => const _HomeFailureContent(
        title: 'Home changed',
        message:
            'Home data changed while you were viewing it. Refresh to load the current version.',
        actionLabel: 'Refresh',
      ),
      HomeFeedFailureKind.securityTimeout => const _HomeFailureContent(
        title: 'Home security check timed out',
        message: 'We could not confirm current Home access. Refresh to retry.',
        actionLabel: 'Refresh',
      ),
      HomeFeedFailureKind.unknown => const _HomeFailureContent(
        title: 'Home unavailable',
        message: 'Live club data is temporarily unavailable.',
        actionLabel: 'Try Again',
      ),
    };
  }
}
