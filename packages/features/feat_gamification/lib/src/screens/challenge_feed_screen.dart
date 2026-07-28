import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/challenge_controller.dart';
import '../models/challenge_models.dart';
import '../widgets/challenge_card.dart';

enum _ChallengeFeedFilter {
  all,
  open,
  highPool,
  mostParticipants,
  endingSoon,
  myJoined,
  settled,
}

class ChallengeFeedScreen extends ConsumerStatefulWidget {
  const ChallengeFeedScreen({super.key, this.createFocusNode});

  final FocusNode? createFocusNode;

  @override
  ConsumerState<ChallengeFeedScreen> createState() =>
      _ChallengeFeedScreenState();
}

class _ChallengeFeedScreenState extends ConsumerState<ChallengeFeedScreen> {
  _ChallengeFeedFilter _selectedFilter = _ChallengeFeedFilter.all;

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(challengeFeedProvider);
    final configuredActionsEnabled = ref.watch(
      challengeFeedActionsEnabledProvider,
    );

    return ConnectivityBuilder(
      builder: (context, isOnline) {
        final failure = feedAsync.hasError
            ? ChallengeFeedFailure.fromError(feedAsync.error!)
            : null;
        final actionsEnabled =
            configuredActionsEnabled &&
            isOnline &&
            failure == null &&
            feedAsync.valueOrNull?.status != ChallengeFeedStatus.degraded;

        return AfriScreenScaffold(
          backgroundColor: ColorTokens.background,
          showAppBar: false,
          showBackButton: false,
          scrollable: false,
          constrainContent: false,
          bodyWrapper: (child) => GradientBackground(child: child),
          child: AfriRefreshIndicator(
            onRefresh: () => ref.read(challengeFeedProvider.notifier).refresh(),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                AfriSliverAppBar(
                  floating: true,
                  backgroundColor: ColorTokens.transparent,
                  title: Text(
                    'CHALLENGE',
                    style: TypographyTokens.headlineSmall().copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  actions: [
                    AfriIconButton(
                      icon: AfriIcons.wallet,
                      onTap: actionsEnabled
                          ? () => unawaited(context.push('/challenge/my'))
                          : null,
                      tooltip: 'My challenges',
                    ),
                    AfriIconButton(
                      icon: AfriIcons.add,
                      onTap: actionsEnabled
                          ? () => unawaited(context.push('/challenge/create'))
                          : null,
                      tooltip: 'Create challenge',
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SpacingTokens.screenPadding,
                      SpacingTokens.spacing3,
                      SpacingTokens.screenPadding,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exact-score pools for real fixtures. Create one, join once, and settle automatically from the official final score.',
                          style: TypographyTokens.bodyMedium(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Wrap(
                          spacing: SpacingTokens.spacing2,
                          runSpacing: SpacingTokens.spacing2,
                          children: _ChallengeFeedFilter.values.map((filter) {
                            return AfriChoiceChip(
                              selected: _selectedFilter == filter,
                              label: Text(_labelForFilter(filter)),
                              onSelected: (_) =>
                                  setState(() => _selectedFilter = filter),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        AfriButton(
                          key: const ValueKey<String>(
                            'challenge-create-action',
                          ),
                          label: 'CREATE A NEW CHALLENGE',
                          icon: AfriIcons.versus,
                          variant: AfriButtonVariant.accent,
                          enabled: actionsEnabled,
                          focusNode: widget.createFocusNode,
                          labelMaxLines: 2,
                          onTap: () => context.push('/challenge/create'),
                        ),
                      ],
                    ),
                  ),
                ),
                feedAsync.when(
                  loading: () => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(
                        SpacingTokens.screenPadding,
                      ),
                      child: AfriStateView.loading(
                        title: 'Opening challenges',
                        message:
                            'Checking current fixtures, pools, and your joined challenges.',
                      ),
                    ),
                  ),
                  error: (error, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(
                        SpacingTokens.screenPadding,
                      ),
                      child: _buildFailureView(error, isOnline),
                    ),
                  ),
                  data: (feed) {
                    final filtered = _applyFilter(feed, _selectedFilter);
                    return SliverMainAxisGroup(
                      slivers: [
                        if (feedAsync.isRefreshing)
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
                                title: 'Refreshing challenges',
                                subtitle:
                                    'Keeping current fixtures, pools, and joined challenges visible.',
                                tone: AfriStateBannerTone.info,
                                compact: true,
                              ),
                            ),
                          ),
                        if (!configuredActionsEnabled)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                SpacingTokens.screenPadding,
                                SpacingTokens.spacing4,
                                SpacingTokens.screenPadding,
                                0,
                              ),
                              child: AfriStateBanner(
                                icon: AfriIcons.lock,
                                title: 'Challenge actions unavailable',
                                subtitle:
                                    'You can review current pools, but creating and joining are disabled for this build.',
                                tone: AfriStateBannerTone.warning,
                                compact: true,
                              ),
                            ),
                          )
                        else if (!isOnline)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                SpacingTokens.screenPadding,
                                SpacingTokens.spacing4,
                                SpacingTokens.screenPadding,
                                0,
                              ),
                              child: AfriStateBanner(
                                icon: AfriIcons.offline,
                                title: 'Showing saved challenges',
                                subtitle:
                                    'Reconnect before creating or joining a pool.',
                                tone: AfriStateBannerTone.warning,
                                compact: true,
                              ),
                            ),
                          )
                        else if (feed.status == ChallengeFeedStatus.degraded &&
                            feed.message != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                SpacingTokens.screenPadding,
                                SpacingTokens.spacing4,
                                SpacingTokens.screenPadding,
                                0,
                              ),
                              child: AfriStateBanner(
                                icon: AfriIcons.statusWarning,
                                title: 'Live challenge updates paused',
                                subtitle: feed.message!,
                                tone: AfriStateBannerTone.warning,
                                compact: true,
                              ),
                            ),
                          ),
                        if (_selectedFilter != _ChallengeFeedFilter.all)
                          _buildFilteredList(filtered, actionsEnabled)
                        else if (feed.isEmpty)
                          const SliverFillRemaining(
                            key: ValueKey<String>('challenge-feed-empty'),
                            hasScrollBody: false,
                            child: Padding(
                              padding: EdgeInsets.all(
                                SpacingTokens.screenPadding,
                              ),
                              child: AfriEmptyView(
                                title: 'No challenges available',
                                message:
                                    'New exact-score pools will appear when eligible fixtures open.',
                                icon: AfriIcons.versus,
                              ),
                            ),
                          )
                        else
                          _buildFeedList(feed, actionsEnabled),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFailureView(Object error, bool isOnline) {
    final failure = ChallengeFeedFailure.fromError(error);
    final content = _ChallengeFailureContent.fromFailure(failure, isOnline);
    return AfriStateView.offline(
      title: content.title,
      message: content.message,
      actionLabel: content.actionLabel,
      onAction: content.actionLabel == null
          ? null
          : () => ref.read(challengeFeedProvider.notifier).refresh(),
    );
  }

  SliverPadding _buildFeedList(ChallengeFeedState feed, bool actionsEnabled) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.screenPadding,
        SpacingTokens.spacing4,
        SpacingTokens.screenPadding,
        SpacingTokens.spacing8,
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (feed.featured.isNotEmpty) ...[
            _SectionHeader(
              title: 'Featured / Popular Challenges',
              actionLabel: 'See all',
              onAction: () => setState(
                () => _selectedFilter = _ChallengeFeedFilter.highPool,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            ...feed.featured.map(
              (challenge) => Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
                child: ChallengeCard(
                  challenge: challenge,
                  enabled: actionsEnabled,
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
          ],
          if (feed.open.isNotEmpty) ...[
            _SectionHeader(
              title: 'Open Challenges',
              actionLabel: 'Ending soon',
              onAction: () => setState(
                () => _selectedFilter = _ChallengeFeedFilter.endingSoon,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            ...feed.open
                .take(6)
                .map(
                  (challenge) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: SpacingTokens.spacing3,
                    ),
                    child: ChallengeCard(
                      challenge: challenge,
                      enabled: actionsEnabled,
                    ),
                  ),
                ),
            const SizedBox(height: SpacingTokens.spacing5),
          ],
          if (feed.mine.isNotEmpty) ...[
            _SectionHeader(
              title: 'My Challenges',
              actionLabel: 'Open',
              onAction: actionsEnabled
                  ? () => context.push('/challenge/my')
                  : null,
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            ...feed.mine
                .take(4)
                .map(
                  (challenge) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: SpacingTokens.spacing3,
                    ),
                    child: ChallengeCard(
                      challenge: challenge,
                      enabled: actionsEnabled,
                    ),
                  ),
                ),
            const SizedBox(height: SpacingTokens.spacing5),
          ],
          if (feed.settled.isNotEmpty) ...[
            _SectionHeader(
              title: 'Settled Challenges',
              actionLabel: 'Results',
              onAction: () => setState(
                () => _selectedFilter = _ChallengeFeedFilter.settled,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            ...feed.settled
                .take(4)
                .map(
                  (challenge) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: SpacingTokens.spacing3,
                    ),
                    child: ChallengeCard(
                      challenge: challenge,
                      compact: true,
                      enabled: actionsEnabled,
                    ),
                  ),
                ),
          ],
        ]),
      ),
    );
  }

  SliverList _buildFilteredList(List<Challenge> filtered, bool actionsEnabled) {
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.screenPadding,
            SpacingTokens.spacing4,
            SpacingTokens.screenPadding,
            SpacingTokens.spacing8,
          ),
          child: filtered.isEmpty
              ? const AfriEmptyView(
                  compact: true,
                  title: 'Nothing matches this filter',
                  message: 'Try another view or create a new pool.',
                  icon: AfriIcons.filter,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: filtered
                      .map(
                        (challenge) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.spacing3,
                          ),
                          child: ChallengeCard(
                            challenge: challenge,
                            enabled: actionsEnabled,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
      ]),
    );
  }

  List<Challenge> _applyFilter(
    ChallengeFeedState feed,
    _ChallengeFeedFilter filter,
  ) {
    final all = feed.allVisible();
    switch (filter) {
      case _ChallengeFeedFilter.all:
        return all;
      case _ChallengeFeedFilter.open:
        return feed.open;
      case _ChallengeFeedFilter.highPool:
        final sorted = [...all];
        sorted.sort((a, b) => b.totalPoolFet.compareTo(a.totalPoolFet));
        return sorted;
      case _ChallengeFeedFilter.mostParticipants:
        final sorted = [...all];
        sorted.sort(
          (a, b) => b.totalParticipants.compareTo(a.totalParticipants),
        );
        return sorted;
      case _ChallengeFeedFilter.endingSoon:
        final sorted = [...feed.open];
        sorted.sort((a, b) => a.lockAt.compareTo(b.lockAt));
        return sorted;
      case _ChallengeFeedFilter.myJoined:
        return feed.mine;
      case _ChallengeFeedFilter.settled:
        return feed.settled;
    }
  }

  String _labelForFilter(_ChallengeFeedFilter filter) {
    return switch (filter) {
      _ChallengeFeedFilter.all => 'All',
      _ChallengeFeedFilter.open => 'Open',
      _ChallengeFeedFilter.highPool => 'High Pool',
      _ChallengeFeedFilter.mostParticipants => 'Most Participants',
      _ChallengeFeedFilter.endingSoon => 'Ending Soon',
      _ChallengeFeedFilter.myJoined => 'My Joined',
      _ChallengeFeedFilter.settled => 'Settled',
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TypographyTokens.titleSmall().copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        AfriTextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _ChallengeFailureContent {
  const _ChallengeFailureContent({
    required this.title,
    required this.message,
    this.actionLabel,
  });

  final String title;
  final String message;
  final String? actionLabel;

  factory _ChallengeFailureContent.fromFailure(
    ChallengeFeedFailure failure,
    bool isOnline,
  ) {
    if (!isOnline || failure.kind == ChallengeFeedFailureKind.offline) {
      return const _ChallengeFailureContent(
        title: 'Challenges unavailable offline',
        message: 'Reconnect to load current fixtures and challenge pools.',
      );
    }
    return switch (failure.kind) {
      ChallengeFeedFailureKind.permissionDenied =>
        const _ChallengeFailureContent(
          title: 'Challenge access unavailable',
          message:
              'Your access does not currently allow these challenge pools.',
        ),
      ChallengeFeedFailureKind.conflict => const _ChallengeFailureContent(
        title: 'Challenge data changed',
        message: 'Refresh before reviewing or joining the latest pools.',
        actionLabel: 'Refresh',
      ),
      ChallengeFeedFailureKind.securityTimeout =>
        const _ChallengeFailureContent(
          title: 'Challenge security check timed out',
          message:
              'No challenge action was completed. Refresh before trying again.',
          actionLabel: 'Refresh',
        ),
      ChallengeFeedFailureKind.unknown => const _ChallengeFailureContent(
        title: 'Challenge feed unavailable',
        message: 'Current challenge pools could not be loaded safely.',
        actionLabel: 'Retry',
      ),
      ChallengeFeedFailureKind.offline => const _ChallengeFailureContent(
        title: 'Challenges unavailable offline',
        message: 'Reconnect to load current fixtures and challenge pools.',
      ),
    };
  }
}
