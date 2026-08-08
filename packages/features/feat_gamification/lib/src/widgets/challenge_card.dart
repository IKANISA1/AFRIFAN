import 'package:core_l10n/core_l10n.dart';
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
    this.focusNode,
  });

  final Challenge challenge;
  final bool compact;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final fixture = challenge.fixture;
    if (fixture == null) {
      return const SizedBox.shrink();
    }

    final countdown = challenge.timeUntilLock;
    final hasCountdown =
        challenge.status == ChallengeStatus.open && countdown.inSeconds > 0;
    final accentTextColor = ColorTokens.isDark
        ? ColorTokens.clubAccent
        : ColorTokens.onSurface;
    final countdownTextColor = ColorTokens.isDark
        ? ColorTokens.warning
        : ColorTokens.onSurfaceVariant;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final matchSummary = Column(
      children: [
        Text(
          fixture.status == 'finished' || fixture.status == 'live'
              ? '${fixture.homeScore ?? 0}-${fixture.awayScore ?? 0}'
              : context.afriL10n.gameVersus,
          style: TypographyTokens.titleLarge(
            fixture.status == 'live' ? ColorTokens.error : accentTextColor,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: SpacingTokens.spacing1),
        if (hasCountdown)
          Text(
            _formatCountdown(context, countdown),
            textAlign: TextAlign.center,
            style: TypographyTokens.labelSmall(countdownTextColor),
          )
        else
          Text(
            _formatKickoff(context, fixture.kickoffAt),
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.fade,
            softWrap: compact,
            textAlign: TextAlign.center,
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
      ],
    );

    return GlassCard(
      onTap: enabled ? () => context.push('/challenge/${challenge.id}') : null,
      focusNode: focusNode,
      animate: false,
      child: Opacity(
        opacity: enabled ? 1 : 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (largeText)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChallengeCreatorIdentity(
                    challenge: challenge,
                    competitionName: fixture.competitionName,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ChallengeStatusChip(status: challenge.status),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ChallengeCreatorIdentity(
                      challenge: challenge,
                      competitionName: fixture.competitionName,
                    ),
                  ),
                  ChallengeStatusChip(status: challenge.status),
                ],
              ),
            const SizedBox(height: SpacingTokens.spacing4),
            if (largeText)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TeamColumn(
                    name: fixture.homeTeamShort,
                    alignment: CrossAxisAlignment.start,
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  matchSummary,
                  const SizedBox(height: SpacingTokens.spacing2),
                  _TeamColumn(
                    name: fixture.awayTeamShort,
                    alignment: CrossAxisAlignment.end,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _TeamColumn(
                      name: fixture.homeTeamShort,
                      alignment: CrossAxisAlignment.start,
                    ),
                  ),
                  if (compact)
                    Expanded(flex: 2, child: matchSummary)
                  else
                    matchSummary,
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
                  label: context.afriL10n.gameJoinedCount(
                    challenge.totalParticipants,
                  ),
                ),
                _InfoChip(
                  icon: AfriIcons.rewards,
                  label: context.afriL10n.gameTotalPoolPoints(
                    challenge.totalPoolFet,
                  ),
                ),
                if (challenge.creatorPrediction != null)
                  ScorePredictionPill(
                    homeScore: challenge.creatorPrediction!.homeScore,
                    awayScore: challenge.creatorPrediction!.awayScore,
                    label: context.afriL10n.gameCreator,
                  ),
                if (challenge.myEntry != null)
                  ScorePredictionPill(
                    homeScore: challenge.myEntry!.predictedHomeScore,
                    awayScore: challenge.myEntry!.predictedAwayScore,
                    label: context.afriL10n.gameMyPick,
                    accent: ColorTokens.clubAccent,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatKickoff(BuildContext context, DateTime? value) {
    if (value == null) {
      return context.afriL10n.gameKickoffSoon;
    }
    final local = value.toLocal();
    final materialL10n = MaterialLocalizations.of(context);
    return '${materialL10n.formatShortDate(local)} • '
        '${materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  String _formatCountdown(BuildContext context, Duration duration) {
    if (duration.inHours >= 24) {
      return context.afriL10n.gameDaysLeft(duration.inDays);
    }
    if (duration.inHours >= 1) {
      return context.afriL10n.gameHoursMinutes(
        duration.inHours,
        duration.inMinutes.remainder(60),
      );
    }
    return context.afriL10n.gameMinutesLeft(duration.inMinutes);
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
    final textColor = ColorTokens.isDark ? color : ColorTokens.onSurface;
    final label = switch (status) {
      ChallengeStatus.open => context.afriL10n.gameOpenUpper,
      ChallengeStatus.locked => context.afriL10n.gameLockedUpper,
      ChallengeStatus.settled => context.afriL10n.gameSettledUpper,
      ChallengeStatus.void_ => context.afriL10n.gameVoid,
      ChallengeStatus.cancelled => context.afriL10n.gameCancelled,
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
        label,
        style: TypographyTokens.metricLabel(
          textColor,
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
    final textColor = ColorTokens.isDark
        ? ColorTokens.clubAccent
        : ColorTokens.onSurface;
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
        context.afriL10n.gamePointBalance(stakeFet),
        style: TypographyTokens.metricLabel(
          textColor,
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
    final textColor = ColorTokens.isDark
        ? effectiveAccent
        : ColorTokens.onSurface;
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
        context.afriL10n.gameScorePrediction(label, homeScore, awayScore),
        style: TypographyTokens.metricLabel(
          textColor,
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
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: TypographyTokens.labelSmall(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCreatorIdentity extends StatelessWidget {
  const _ChallengeCreatorIdentity({
    required this.challenge,
    required this.competitionName,
  });

  final Challenge challenge;
  final String competitionName;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                competitionName,
                style: TypographyTokens.labelSmall(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
