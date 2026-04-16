import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/challenge_models.dart';

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
  });

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final fixture = challenge.fixture;
    if (fixture == null) return const SizedBox.shrink();

    return GlassCard(
      onTap: () => context.push('/challenge/${challenge.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CreatorAvatar(
                name: challenge.creatorName ?? 'Supporter',
                avatarUrl: challenge.creatorAvatar,
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${challenge.creatorName ?? 'Supporter'}''s Challenge',
                      style: TypographyTokens.labelSmall(),
                    ),
                    Text(
                      challenge.fixture?.competitionName.toUpperCase() ?? 'MATCH',
                      style: TypographyTokens.editorialFont(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ColorTokens.onSurfaceVariant,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: challenge.status),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TeamBox(
                name: fixture.homeTeamShort,
                alignment: CrossAxisAlignment.start,
              ),
              _ScoreDisplay(
                status: fixture.status,
                homeScore: fixture.homeScore,
                awayScore: fixture.awayScore,
              ),
              _TeamBox(
                name: fixture.awayTeamShort,
                alignment: CrossAxisAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Divider(color: ColorTokens.ghostBorder, height: 1),
          const SizedBox(height: SpacingTokens.spacing4),
          Row(
            children: [
              _Metric(
                icon: AfriIcons.earn,
                label: 'STAKE',
                value: '${challenge.stakeFet} FET',
                accent: true,
              ),
              const Spacer(),
              _Metric(
                icon: AfriIcons.users,
                label: 'PLAYERS',
                value: '${challenge.totalParticipants}',
              ),
              const Spacer(),
              _Metric(
                icon: AfriIcons.wallet,
                label: 'TOTAL POOL',
                value: '${challenge.totalPoolFet}',
                accent: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreatorAvatar extends StatelessWidget {
  const _CreatorAvatar({required this.name, this.avatarUrl});
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: ColorTokens.primaryTint(0.2),
        shape: BoxShape.circle,
        border: BorderTokens.all(color: ColorTokens.ghostBorder),
      ),
      alignment: Alignment.center,
      child: Text(
        name.substring(0, 1).toUpperCase(),
        style: TypographyTokens.labelSmall().copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TeamBox extends StatelessWidget {
  const _TeamBox({required this.name, required this.alignment});
  final String name;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Text(
            name.toUpperCase(),
            style: TypographyTokens.monolithFont(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreDisplay extends StatelessWidget {
  const _ScoreDisplay({
    required this.status,
    this.homeScore,
    this.awayScore,
  });
  final String status;
  final int? homeScore;
  final int? awayScore;

  @override
  Widget build(BuildContext context) {
    final isLive = status.toLowerCase() == 'live';
    final isFinished = status.toLowerCase() == 'finished';

    if (!isLive && !isFinished) {
      return Text(
        'VS',
        style: TypographyTokens.monolithFont(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: ColorTokens.clubAccent,
        ),
      );
    }

    return Text(
      '${homeScore ?? 0} - ${awayScore ?? 0}',
      style: TypographyTokens.monolithFont(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: isLive ? ColorTokens.error : ColorTokens.onSurface,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ChallengeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ChallengeStatus.open => ColorTokens.success,
      ChallengeStatus.locked => ColorTokens.warning,
      ChallengeStatus.settled => ColorTokens.clubAccent,
      _ => ColorTokens.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TypographyTokens.editorialFont(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: ColorTokens.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TypographyTokens.editorialFont(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: ColorTokens.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TypographyTokens.monolithFont(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: accent ? ColorTokens.clubAccent : ColorTokens.onSurface,
          ),
        ),
      ],
    );
  }
}
