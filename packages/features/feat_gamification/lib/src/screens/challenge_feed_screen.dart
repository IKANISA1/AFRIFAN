import 'dart:async';

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
  const ChallengeFeedScreen({super.key});

  @override
  ConsumerState<ChallengeFeedScreen> createState() =>
      _ChallengeFeedScreenState();
}

class _ChallengeFeedScreenState extends ConsumerState<ChallengeFeedScreen> {
  _ChallengeFeedFilter _selectedFilter = _ChallengeFeedFilter.all;

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(challengeFeedProvider);

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
                  onTap: () => unawaited(context.push('/challenge/my')),
                  tooltip: 'My challenges',
                ),
                AfriIconButton(
                  icon: AfriIcons.add,
                  onTap: () => unawaited(context.push('/challenge/create')),
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
                    AfriActionRow(
                      icon: AfriIcons.versus,
                      label: 'CREATE A NEW CHALLENGE',
                      accentColor: ColorTokens.clubAccent,
                      onTap: () => context.push('/challenge/create'),
                    ),
                  ],
                ),
              ),
            ),
            feedAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: AfriLoadingIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                  child: AfriStateView.error(
                    title: 'Challenge feed unavailable',
                    message: error.toString(),
                    actionLabel: 'Retry',
                    onAction: () =>
                        ref.read(challengeFeedProvider.notifier).refresh(),
                  ),
                ),
              ),
              data: (feed) {
                final filtered = _applyFilter(feed, _selectedFilter);
                if (_selectedFilter != _ChallengeFeedFilter.all) {
                  return _buildFilteredList(filtered);
                }

                if (feed.isEmpty) {
                  return const SliverToBoxAdapter(
                    key: ValueKey<String>('challenge-feed-empty'),
                    child: SizedBox.shrink(),
                  );
                }

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
                            () =>
                                _selectedFilter = _ChallengeFeedFilter.highPool,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        ...feed.featured.map(
                          (challenge) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: SpacingTokens.spacing3,
                            ),
                            child: ChallengeCard(challenge: challenge),
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing5),
                      ],
                      if (feed.open.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Open Challenges',
                          actionLabel: 'Ending soon',
                          onAction: () => setState(
                            () => _selectedFilter =
                                _ChallengeFeedFilter.endingSoon,
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
                                child: ChallengeCard(challenge: challenge),
                              ),
                            ),
                        const SizedBox(height: SpacingTokens.spacing5),
                      ],
                      if (feed.mine.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'My Challenges',
                          actionLabel: 'Open',
                          onAction: () => context.push('/challenge/my'),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        ...feed.mine
                            .take(4)
                            .map(
                              (challenge) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: SpacingTokens.spacing3,
                                ),
                                child: ChallengeCard(challenge: challenge),
                              ),
                            ),
                        const SizedBox(height: SpacingTokens.spacing5),
                      ],
                      if (feed.settled.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Settled Challenges',
                          actionLabel: 'Results',
                          onAction: () => setState(
                            () =>
                                _selectedFilter = _ChallengeFeedFilter.settled,
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
                                ),
                              ),
                            ),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  SliverList _buildFilteredList(List<Challenge> filtered) {
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
                          child: ChallengeCard(challenge: challenge),
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
  final VoidCallback onAction;

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
