import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
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
    final l10n = context.afriL10n;
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
                    l10n.feedChallengeTitle,
                    style: TypographyTokens.headlineSmall(
                      ColorTokens.chromeForeground,
                    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.6),
                  ),
                  actions: [
                    AfriIconButton(
                      icon: AfriIcons.wallet,
                      onTap: actionsEnabled
                          ? () => unawaited(context.push('/challenge/my'))
                          : null,
                      tooltip: l10n.gameMyChallenges,
                    ),
                    AfriIconButton(
                      icon: AfriIcons.add,
                      onTap: actionsEnabled
                          ? () => unawaited(context.push('/challenge/create'))
                          : null,
                      tooltip: l10n.gameCreateChallenge,
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
                          l10n.feedDescription,
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
                              label: Text(_labelForFilter(context, filter)),
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
                          label: l10n.feedCreateNew,
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
                        title: l10n.feedOpening,
                        message: l10n.feedOpeningBody,
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
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                SpacingTokens.screenPadding,
                                SpacingTokens.spacing4,
                                SpacingTokens.screenPadding,
                                0,
                              ),
                              child: AfriStateBanner(
                                icon: AfriIcons.refresh,
                                title: l10n.feedRefreshing,
                                subtitle: l10n.feedRefreshingBody,
                                tone: AfriStateBannerTone.info,
                                compact: true,
                              ),
                            ),
                          ),
                        if (!configuredActionsEnabled)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                SpacingTokens.screenPadding,
                                SpacingTokens.spacing4,
                                SpacingTokens.screenPadding,
                                0,
                              ),
                              child: AfriStateBanner(
                                icon: AfriIcons.lock,
                                title: l10n.feedActionsUnavailable,
                                subtitle: l10n.feedActionsUnavailableBody,
                                tone: AfriStateBannerTone.warning,
                                compact: true,
                              ),
                            ),
                          )
                        else if (!isOnline)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                SpacingTokens.screenPadding,
                                SpacingTokens.spacing4,
                                SpacingTokens.screenPadding,
                                0,
                              ),
                              child: AfriStateBanner(
                                icon: AfriIcons.offline,
                                title: l10n.feedShowingSaved,
                                subtitle: l10n.feedShowingSavedBody,
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
                                title: l10n.feedUpdatesPaused,
                                subtitle: feed.message!,
                                tone: AfriStateBannerTone.warning,
                                compact: true,
                              ),
                            ),
                          ),
                        if (_selectedFilter != _ChallengeFeedFilter.all)
                          _buildFilteredList(filtered, actionsEnabled)
                        else if (feed.isEmpty)
                          SliverFillRemaining(
                            key: const ValueKey<String>('challenge-feed-empty'),
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.all(
                                SpacingTokens.screenPadding,
                              ),
                              child: AfriEmptyView(
                                title: l10n.feedEmpty,
                                message: l10n.feedEmptyBody,
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
    final content = _ChallengeFailureContent.fromFailure(
      failure,
      isOnline,
      context.afriL10n,
    );
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
              title: context.afriL10n.feedFeatured,
              actionLabel: context.afriL10n.feedSeeAll,
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
              title: context.afriL10n.feedOpenChallenges,
              actionLabel: context.afriL10n.feedEndingSoonAction,
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
              title: context.afriL10n.feedMyChallenges,
              actionLabel: context.afriL10n.gameOpen,
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
              title: context.afriL10n.feedSettledChallenges,
              actionLabel: context.afriL10n.feedResults,
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
              ? AfriEmptyView(
                  compact: true,
                  title: context.afriL10n.feedNoFilterMatches,
                  message: context.afriL10n.feedNoFilterMatchesBody,
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

  String _labelForFilter(BuildContext context, _ChallengeFeedFilter filter) {
    final l10n = context.afriL10n;
    return switch (filter) {
      _ChallengeFeedFilter.all => l10n.feedAll,
      _ChallengeFeedFilter.open => l10n.gameOpen,
      _ChallengeFeedFilter.highPool => l10n.feedHighPool,
      _ChallengeFeedFilter.mostParticipants => l10n.feedMostParticipants,
      _ChallengeFeedFilter.endingSoon => l10n.feedEndingSoon,
      _ChallengeFeedFilter.myJoined => l10n.feedMyJoined,
      _ChallengeFeedFilter.settled => l10n.gameSettled,
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
        AfriTextButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: TypographyTokens.labelLarge(ColorTokens.onSurface),
          ),
        ),
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
    AfriLocalizations l10n,
  ) {
    if (!isOnline || failure.kind == ChallengeFeedFailureKind.offline) {
      return _ChallengeFailureContent(
        title: l10n.feedChallengesOffline,
        message: l10n.feedChallengesOfflineBody,
      );
    }
    return switch (failure.kind) {
      ChallengeFeedFailureKind.permissionDenied => _ChallengeFailureContent(
        title: l10n.feedAccessUnavailable,
        message: l10n.feedAccessUnavailableBody,
      ),
      ChallengeFeedFailureKind.conflict => _ChallengeFailureContent(
        title: l10n.feedDataChanged,
        message: l10n.feedDataChangedBody,
        actionLabel: l10n.gameRefresh,
      ),
      ChallengeFeedFailureKind.securityTimeout => _ChallengeFailureContent(
        title: l10n.challengeSecurityTimedOut,
        message: l10n.feedSecurityTimedOutBody,
        actionLabel: l10n.gameRefresh,
      ),
      ChallengeFeedFailureKind.unknown => _ChallengeFailureContent(
        title: l10n.feedUnavailable,
        message: l10n.feedUnavailableBody,
        actionLabel: l10n.gameRetry,
      ),
      ChallengeFeedFailureKind.offline => _ChallengeFailureContent(
        title: l10n.feedChallengesOffline,
        message: l10n.feedChallengesOfflineBody,
      ),
    };
  }
}
