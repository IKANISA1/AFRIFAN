import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Lineups tab content — shows starting XI and substitutes for both teams.
///
/// Uses the borrowed match-detail system for compact team comparison.
class LineupsTabBody extends StatelessWidget {
  const LineupsTabBody({
    super.key,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeTeamShort,
    required this.awayTeamShort,
    this.homeLineup = const <LineupPlayer>[],
    this.awayLineup = const <LineupPlayer>[],
    this.homeFormation,
    this.awayFormation,
  });

  final String homeTeamName;
  final String awayTeamName;
  final String homeTeamShort;
  final String awayTeamShort;
  final List<LineupPlayer> homeLineup;
  final List<LineupPlayer> awayLineup;
  final String? homeFormation;
  final String? awayFormation;

  @override
  Widget build(BuildContext context) {
    if (homeLineup.isEmpty && awayLineup.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: SpacingTokens.spacing16 + SpacingTokens.spacing2,
                height: SpacingTokens.spacing16 + SpacingTokens.spacing2,
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusXl),
                ),
                alignment: Alignment.center,
                child: Icon(
                  AfriIcons.groups,
                  size: SpacingTokens.spacing9,
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                'LINEUPS',
                style: TypographyTokens.titleLarge(
                  ColorTokens.onSurfaceVariant,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.5),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                'Starting lineups will be available closer to kickoff.',
                textAlign: TextAlign.center,
                style: TypographyTokens.bodySmall(),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        // ── Formation display ──
        if (homeFormation != null || awayFormation != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (homeFormation != null)
                _FormationChip(team: homeTeamShort, formation: homeFormation!),
              if (homeFormation != null && awayFormation != null)
                const SizedBox(width: SpacingTokens.spacing4),
              if (awayFormation != null)
                _FormationChip(team: awayTeamShort, formation: awayFormation!),
            ],
          ).animate().fadeIn(duration: 300.ms),

        if (homeFormation != null || awayFormation != null)
          const SizedBox(height: SpacingTokens.spacing5),

        // ── Side-by-side lineups ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TeamLineup(
                teamName: homeTeamShort,
                players: homeLineup,
                isHome: true,
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            Expanded(
              child: _TeamLineup(
                teamName: awayTeamShort,
                players: awayLineup,
                isHome: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormationChip extends StatelessWidget {
  const _FormationChip({required this.team, required this.formation});

  final String team;
  final String formation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            team,
            style: TypographyTokens.metricLabel(
              ColorTokens.onSurfaceVariant,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(width: SpacingTokens.spacing2),
          Text(
            formation,
            style: TypographyTokens.titleSmall(
              ColorTokens.onSurface,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TeamLineup extends StatelessWidget {
  const _TeamLineup({
    required this.teamName,
    required this.players,
    required this.isHome,
  });

  final String teamName;
  final List<LineupPlayer> players;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final starters = players.where((p) => p.isStarter).toList();
    final subs = players.where((p) => !p.isStarter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
          style: TypographyTokens.titleSmall(
            isHome ? ColorTokens.clubAccent : ColorTokens.onSurface,
          ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        const SizedBox(height: SpacingTokens.spacing3),

        // Starters
        ...starters.asMap().entries.map((entry) {
          return _PlayerRow(player: entry.value, delay: (entry.key * 40));
        }),

        if (subs.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            'SUBS',
            style: TypographyTokens.labelSmall(
              ColorTokens.onSurfaceVariant,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          ...subs.asMap().entries.map((entry) {
            return _PlayerRow(
              player: entry.value,
              delay: ((starters.length + entry.key) * 40),
              isSub: true,
            );
          }),
        ],
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, this.delay = 0, this.isSub = false});

  final LineupPlayer player;
  final int delay;
  final bool isSub;

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
          child: Row(
            children: [
              SizedBox(
                width: SpacingTokens.spacing6,
                child: Text(
                  player.number != null ? '${player.number}' : '',
                  style: TypographyTokens.labelMedium(
                    isSub
                        ? ColorTokens.onSurfaceVariant
                        : ColorTokens.clubAccent,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing2),
              Expanded(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypographyTokens.bodyMedium().copyWith(
                    color: isSub ? ColorTokens.onSurfaceVariant : null,
                  ),
                ),
              ),
              if (player.position != null)
                Text(
                  player.position!,
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
            ],
          ),
        )
        .animate(delay: delay.ms)
        .fadeIn(duration: 200.ms)
        .slideX(begin: 0.03, end: 0, duration: 200.ms);
  }
}

/// Model for a lineup player.
class LineupPlayer {
  const LineupPlayer({
    required this.name,
    this.number,
    this.position,
    this.isStarter = true,
  });

  final String name;
  final int? number;
  final String? position;
  final bool isStarter;
}
