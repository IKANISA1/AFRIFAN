import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/challenge_detail_controller.dart';
import '../models/challenge_models.dart';
import '../widgets/challenge_card.dart';

class ChallengeDetailScreen extends ConsumerStatefulWidget {
  const ChallengeDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ChallengeDetailScreen> createState() =>
      _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen> {
  int _homeScore = 1;
  int _awayScore = 0;
  bool _joining = false;
  bool _cancelling = false;

  Future<void> _joinChallenge(Challenge challenge) async {
    if (_joining || challenge.hasJoined || !challenge.canJoin) {
      return;
    }

    setState(() => _joining = true);
    final result = await ref
        .read(challengeDetailProvider(widget.id).notifier)
        .join(_homeScore, _awayScore);
    if (!mounted) {
      return;
    }

    setState(() => _joining = false);
    if (!result.isSuccess) {
      AfriToast.error(context, 'Could not join this challenge right now.');
      return;
    }

    AfriToast.success(context, 'Challenge joined successfully.');
  }

  Future<void> _cancelChallenge(Challenge challenge) async {
    if (_cancelling || !challenge.canCancel) {
      return;
    }

    setState(() => _cancelling = true);
    final result = await ref
        .read(challengeDetailProvider(widget.id).notifier)
        .cancel();
    if (!mounted) {
      return;
    }

    setState(() => _cancelling = false);
    if (!result.isSuccess) {
      AfriToast.error(context, 'Could not cancel this challenge.');
      return;
    }

    AfriToast.success(context, 'Challenge cancelled.');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(challengeDetailProvider(widget.id));

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'CHALLENGE DETAIL',
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          tooltip: 'Back',
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/challenge');
            }
          },
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(SpacingTokens.screenPadding),
          child: AfriSkeletonList(),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          child: AfriStateView.offline(
            title: 'Challenge unavailable',
            message: error.toString(),
            actionLabel: 'Retry',
            onAction: () => unawaited(
              ref.read(challengeDetailProvider(widget.id).notifier).load(),
            ),
          ),
        ),
        data: (payload) {
          final challenge = payload.challenge;
          final myEntry = payload.userEntry;
          final settlement = payload.settlement;

          return AfriRefreshIndicator(
            onRefresh: () =>
                ref.read(challengeDetailProvider(widget.id).notifier).load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(SpacingTokens.screenPadding),
              children: [
                IgnorePointer(child: ChallengeCard(challenge: challenge)),
                const SizedBox(height: SpacingTokens.spacing4),
                GlassCard(
                  animate: false,
                  child: Wrap(
                    spacing: SpacingTokens.spacing2,
                    runSpacing: SpacingTokens.spacing2,
                    children: [
                      StakeBadge(stakeFet: challenge.stakeFet),
                      _MetaChip(label: '${challenge.totalParticipants} joined'),
                      _MetaChip(label: '${challenge.totalPoolFet} pts total'),
                      _MetaChip(
                        label: challenge.status.name
                            .replaceAll('_', '')
                            .toUpperCase(),
                      ),
                    ],
                  ),
                ),
                if (myEntry != null) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MY PICK',
                          style: TypographyTokens.labelSmall(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        ScorePredictionPill(
                          homeScore: myEntry.predictedHomeScore,
                          awayScore: myEntry.predictedAwayScore,
                          label: 'My entry',
                          accent: ColorTokens.clubAccent,
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          _entrySummary(myEntry),
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ],
                    ),
                  ),
                ],
                if (challenge.canJoin && !challenge.hasJoined) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JOIN THIS CHALLENGE',
                          style: TypographyTokens.sectionTitle().copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          'Pick the exact score before the fixture locks.',
                          style: TypographyTokens.bodyMedium(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                child: _ScoreAdjuster(
                                  label:
                                      challenge.fixture?.homeTeamShort ??
                                      'HOME',
                                  value: _homeScore,
                                  onChanged: (value) =>
                                      setState(() => _homeScore = value),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpacingTokens.spacing3,
                                vertical: SpacingTokens.spacing4,
                              ),
                              child: Text(
                                ':',
                                style: TypographyTokens.metricValue(
                                  ColorTokens.clubAccent,
                                ).copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                child: _ScoreAdjuster(
                                  label:
                                      challenge.fixture?.awayTeamShort ??
                                      'AWAY',
                                  value: _awayScore,
                                  onChanged: (value) =>
                                      setState(() => _awayScore = value),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        AfriButton(
                          label: _joining
                              ? 'Joining…'
                              : 'JOIN WITH ${challenge.stakeFet} pts',
                          icon: AfriIcons.checkGroup,
                          isLoading: _joining,
                          enabled: !_joining,
                          onTap: () => _joinChallenge(challenge),
                        ),
                      ],
                    ),
                  ),
                ],
                if (challenge.canCancel) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriButton(
                    label: _cancelling ? 'Cancelling…' : 'CANCEL CHALLENGE',
                    variant: AfriButtonVariant.outline,
                    isLoading: _cancelling,
                    enabled: !_cancelling,
                    onTap: () => _cancelChallenge(challenge),
                  ),
                ],
                if (settlement != null) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESULTS',
                          style: TypographyTokens.sectionTitle().copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        _SettlementRow(
                          label: 'Official score',
                          value:
                              '${settlement.officialHomeScore ?? 0}-${settlement.officialAwayScore ?? 0}',
                        ),
                        _SettlementRow(
                          label: 'Winners',
                          value: '${settlement.winnersCount}',
                        ),
                        _SettlementRow(
                          label: 'Losers',
                          value: '${settlement.losersCount}',
                        ),
                        _SettlementRow(
                          label: 'Points / winner',
                          value: '${settlement.payoutPerWinnerFet} pts',
                        ),
                      ],
                    ),
                  ),
                ],
                if (payload.entries.isNotEmpty) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    'ENTRIES',
                    style: TypographyTokens.sectionTitle().copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  ...payload.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: SpacingTokens.spacing2,
                      ),
                      child: GlassCard(
                        animate: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.displayName,
                                    style: TypographyTokens.titleSmall(),
                                  ),
                                  const SizedBox(
                                    height: SpacingTokens.spacing1 / 2,
                                  ),
                                  Text(
                                    entry.status.name.toUpperCase(),
                                    style: TypographyTokens.labelSmall(
                                      ColorTokens.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ScorePredictionPill(
                              homeScore: entry.predictedHomeScore,
                              awayScore: entry.predictedAwayScore,
                              label: '${entry.stakeFet} pts',
                              accent: entry.isWinner
                                  ? ColorTokens.success
                                  : entry.isLoser
                                  ? ColorTokens.error
                                  : ColorTokens.clubAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _entrySummary(ChallengeEntry entry) {
    return switch (entry.status) {
      ChallengeEntryStatus.winner => 'Earned ${entry.payoutFet} pts',
      ChallengeEntryStatus.loser => 'No result credit',
      ChallengeEntryStatus.refunded => 'Returned ${entry.payoutFet} pts',
      ChallengeEntryStatus.cancelled => 'Entry cancelled',
      ChallengeEntryStatus.active => 'Waiting for official result review.',
    };
  }
}

class _ScoreAdjuster extends StatelessWidget {
  const _ScoreAdjuster({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AfriIconButton(
              icon: AfriIcons.remove,
              onTap: value > 0 ? () => onChanged(value - 1) : null,
              tooltip: 'Decrease $label',
            ),
            Text(
              '$value',
              style: TypographyTokens.headlineMedium().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            AfriIconButton(
              icon: AfriIcons.add,
              onTap: value < 20 ? () => onChanged(value + 1) : null,
              tooltip: 'Increase $label',
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2 - SpacingTokens.spacing1 / 2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
      ),
      child: Text(
        label,
        style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TypographyTokens.bodyMedium())),
          Text(value, style: TypographyTokens.titleSmall()),
        ],
      ),
    );
  }
}
