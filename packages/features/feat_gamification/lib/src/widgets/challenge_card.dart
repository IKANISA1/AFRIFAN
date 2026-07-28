import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/challenge_models.dart';

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    this.compact = false,
    this.enabled = true,
  });

  final Challenge challenge;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fixture = challenge.fixture;
    if (fixture == null) {
      return const SizedBox.shrink();
    }

    final countdown = challenge.timeUntilLock;
    final hasCountdown =
        challenge.status == ChallengeStatus.open && countdown.inSeconds > 0;

    return GlassCard(
      onTap: enabled ? () => context.push('/challenge/${challenge.id}') : null,
      animate: false,
      child: Opacity(
        opacity: enabled ? 1 : 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarBadge(
                  label: challenge.creatorDisplayName,
                  avatarUrl: challenge.creatorAvatarUrl,
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.creatorDisplayName,
                        style: TypographyTokens.titleSmall(),
                      ),
                      const SizedBox(height: SpacingTokens.spacing1 / 2),
                      Text(
                        fixture.competitionName,
                        style: TypographyTokens.labelSmall(
                          ColorTokens.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ChallengeStatusChip(status: challenge.status),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Row(
              children: [
                Expanded(
                  child: _TeamColumn(
                    name: fixture.homeTeamShort,
                    alignment: CrossAxisAlignment.start,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      fixture.status == 'finished' || fixture.status == 'live'
                          ? '${fixture.homeScore ?? 0}-${fixture.awayScore ?? 0}'
                          : 'VS',
                      style: TypographyTokens.titleLarge(
                        fixture.status == 'live'
                            ? ColorTokens.error
                            : ColorTokens.clubAccent,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    if (hasCountdown)
                      Text(
                        _formatCountdown(countdown),
                        style: TypographyTokens.labelSmall(ColorTokens.warning),
                      )
                    else
                      Text(
                        compact
                            ? fixture.kickoffAt
                                      ?.toLocal()
                                      .toString()
                                      .split('.')
                                      .first ??
                                  'Kickoff soon'
                            : _formatKickoff(fixture.kickoffAt),
                        style: TypographyTokens.labelSmall(
                          ColorTokens.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: _TeamColumn(
                    name: fixture.awayTeamShort,
                    alignment: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: [
                StakeBadge(stakeFet: challenge.stakeFet),
                _InfoChip(
                  icon: AfriIcons.users,
                  label: '${challenge.totalParticipants} joined',
                ),
                _InfoChip(
                  icon: AfriIcons.rewards,
                  label: '${challenge.totalPoolFet} pts total',
                ),
                if (challenge.creatorPrediction != null)
                  ScorePredictionPill(
                    homeScore: challenge.creatorPrediction!.homeScore,
                    awayScore: challenge.creatorPrediction!.awayScore,
                    label: 'Creator',
                  ),
                if (challenge.myEntry != null)
                  ScorePredictionPill(
                    homeScore: challenge.myEntry!.predictedHomeScore,
                    awayScore: challenge.myEntry!.predictedAwayScore,
                    label: 'My pick',
                    accent: ColorTokens.clubAccent,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatKickoff(DateTime? value) {
    if (value == null) {
      return 'Kickoff soon';
    }
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} $hour:$minute';
  }

  String _formatCountdown(Duration duration) {
    if (duration.inHours >= 24) {
      return '${duration.inDays}d left';
    }
    if (duration.inHours >= 1) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    return '${duration.inMinutes}m left';
  }
}

class ChallengeStatusChip extends StatelessWidget {
  const ChallengeStatusChip({super.key, required this.status});

  final ChallengeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ChallengeStatus.open => ColorTokens.success,
      ChallengeStatus.locked => ColorTokens.warning,
      ChallengeStatus.settled => ColorTokens.clubAccent,
      ChallengeStatus.void_ => ColorTokens.onSurfaceVariant,
      ChallengeStatus.cancelled => ColorTokens.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing3 / 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
      ),
      child: Text(
        status.name.replaceAll('_', '').toUpperCase(),
        style: TypographyTokens.metricLabel(
          color,
        ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
    );
  }
}

class StakeBadge extends StatelessWidget {
  const StakeBadge({super.key, required this.stakeFet});

  final int stakeFet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing3 / 2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.clubAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
      ),
      child: Text(
        '$stakeFet pts',
        style: TypographyTokens.metricLabel(
          ColorTokens.clubAccent,
        ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
    );
  }
}

class ScorePredictionPill extends StatelessWidget {
  const ScorePredictionPill({
    super.key,
    required this.homeScore,
    required this.awayScore,
    required this.label,
    this.accent,
  });

  final int homeScore;
  final int awayScore;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? ColorTokens.success;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing3 / 2,
      ),
      decoration: BoxDecoration(
        color: effectiveAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
      ),
      child: Text(
        '$label  $homeScore-$awayScore',
        style: TypographyTokens.metricLabel(
          effectiveAccent,
        ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.7),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing3 / 2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
        border: BorderTokens.all(color: ColorTokens.ghostBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: SpacingTokens.spacing3,
            color: ColorTokens.onSurfaceVariant,
          ),
          const SizedBox(width: SpacingTokens.spacing3 / 2),
          Text(label, style: TypographyTokens.labelSmall()),
        ],
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.label, this.avatarUrl});

  final String label;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    return Container(
      width: SpacingTokens.spacing9,
      height: SpacingTokens.spacing9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ColorTokens.primaryTint(0.16),
        border: BorderTokens.all(color: ColorTokens.ghostBorder),
      ),
      alignment: Alignment.center,
      child: Text(
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase(),
        style: TypographyTokens.labelSmall().copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.name, required this.alignment});

  final String name;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          name.toUpperCase(),
          style: TypographyTokens.titleMedium().copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
