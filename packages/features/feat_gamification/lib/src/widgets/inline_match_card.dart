import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fanzone_slip_providers.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';

/// Inline Match Card with 1X2 pick buttons.
///
/// Mirrors the fanafrika `MatchCard.tsx` — shows team names, score/VS,
/// league/time, and a 3-column pick grid for 1X2 with points.
/// Tapping a pick button adds it to the current round.
///
/// If the user is not verified, triggers [onAuthRequired] instead.
class InlineMatchCard extends ConsumerWidget {
  const InlineMatchCard({
    super.key,
    required this.fixture,
    this.market,
    this.onTap,
    this.onAuthRequired,
  });

  final FixtureSummary fixture;

  /// Optional 1X2 pick type with outcomes + point values.
  /// If null, only the teams/score are shown.
  final FixtureMarket? market;

  /// Called when the card is tapped and navigates to detail.
  final VoidCallback? onTap;

  /// Called when user taps a pick button but is not authenticated.
  final VoidCallback? onAuthRequired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLive = fixture.isLive;
    final hasScore = fixture.homeScore != null && fixture.awayScore != null;

    return AfriPressFeedback(
      onTap: onTap,
      semanticsLabel: '${fixture.homeTeamName} vs ${fixture.awayTeamName}',
      builder: (context, state) => Container(
        decoration: BoxDecoration(
          color: ColorTokens.surfaceContainerLow,
          borderRadius: ShapeTokens.cardRadius,
          border: isLive
              ? BorderTokens.all(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.4),
                )
              : BorderTokens.ghost(),
          boxShadow: [
            BoxShadow(
              color: ColorTokens.ambientShadow.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Accent bar ──
            Container(
              height: SpacingTokens.spacing1,
              decoration: BoxDecoration(
                color: isLive
                    ? ColorTokens.clubAccent
                    : ColorTokens.clubAccent.withValues(alpha: 0.35),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(ShapeTokens.radiusXl),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing5,
                SpacingTokens.spacing4,
                SpacingTokens.spacing5,
                SpacingTokens.spacing4,
              ),
              child: Column(
                children: [
                  // ── League + kickoff row ──
                  Row(
                    children: [
                      Text(
                        fixture.competitionName.toUpperCase(),
                        style:
                            TypographyTokens.labelSmall(
                              ColorTokens.onSurfaceVariant,
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing1),
                      Text(
                        '·',
                        style: TypographyTokens.labelSmall(
                          ColorTokens.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing1),
                      Text(
                        _formatKickoff(),
                        style:
                            TypographyTokens.labelSmall(
                              ColorTokens.onSurfaceVariant,
                            ).copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                      ),
                      const Spacer(),
                      if (isLive) ...[
                        AfriInfoChip(
                          label: 'LIVE',
                          color: ColorTokens.clubAccent,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: SpacingTokens.spacing5),

                  // ── Teams + Score/VS ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TeamColumn(name: fixture.homeTeamShort),
                      Text(
                        hasScore
                            ? '${fixture.homeScore} - ${fixture.awayScore}'
                            : 'VS',
                        style:
                            (hasScore
                                    ? TypographyTokens.headlineLarge()
                                    : TypographyTokens.headlineMedium())
                                .copyWith(fontWeight: FontWeight.w900),
                      ),
                      _TeamColumn(name: fixture.awayTeamShort),
                    ],
                  ),

                  // ── Inline 1X2 Picks ──
                  if (market != null &&
                      market!.outcomes.length >= 3 &&
                      !market!.isLocked) ...[
                    const SizedBox(height: SpacingTokens.spacing5),
                    _InlinePredictionGrid(
                      fixture: fixture,
                      market: market!,
                      onAuthRequired: onAuthRequired,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatKickoff() {
    final kickoff = fixture.kickoffAt;
    if (kickoff == null) return 'TBD';
    final local = kickoff.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _TeamAvatar(),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          name.toUpperCase(),
          style: TypographyTokens.titleSmall().copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TeamAvatar extends StatelessWidget {
  const _TeamAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SpacingTokens.spacing12,
      height: SpacingTokens.spacing12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ColorTokens.surfaceContainerHigh,
      ),
      alignment: Alignment.center,
      child: Text('⚽', style: TypographyTokens.headlineMedium()),
    );
  }
}

class _InlinePredictionGrid extends ConsumerWidget {
  const _InlinePredictionGrid({
    required this.fixture,
    required this.market,
    this.onAuthRequired,
  });

  final FixtureSummary fixture;
  final FixtureMarket market;
  final VoidCallback? onAuthRequired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slip = ref.watch(fanzoneSlipProvider);
    final isAuthenticated = ref
        .read(predictionRepositoryProvider)
        .isAuthenticated;
    final selectedOutcome = slip.items
        .where((item) => item.fixtureMarketId == market.fixtureMarketId)
        .map((item) => item.outcomeKey)
        .firstOrNull;

    return Row(
      children: market.outcomes.take(3).map((outcome) {
        final isSelected = selectedOutcome == outcome.key;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: outcome != market.outcomes.take(3).last
                  ? SpacingTokens.spacing2
                  : 0,
            ),
            child: AfriPressFeedback(
              onTap: () {
                // Auth gate: intercept unauthenticated users.
                if (!isAuthenticated) {
                  onAuthRequired?.call();
                  return;
                }

                ref
                    .read(fanzoneSlipProvider.notifier)
                    .addFromMarket(
                      fixture: fixture,
                      market: market,
                      outcome: outcome,
                    );
              },
              selected: isSelected,
              tooltip: '${outcome.label} pick',
              semanticsLabel:
                  '${outcome.label} pick for ${fixture.homeTeamShort} versus ${fixture.awayTeamShort}',
              semanticsHint: isSelected ? 'Selected pick' : 'Add pick to round',
              excludeChildSemantics: true,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                constraints: const BoxConstraints(
                  minHeight: SpacingTokens.spacing12,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: SpacingTokens.spacing3,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ColorTokens.clubAccent.withValues(alpha: 0.2)
                      : ColorTokens.surfaceContainerHigh,
                  borderRadius: ShapeTokens.aliasPillRadius,
                  border: isSelected
                      ? BorderTokens.all(color: ColorTokens.clubAccent)
                      : BorderTokens.ghost(),
                ),
                child: Column(
                  children: [
                    Text(
                      outcome.label,
                      style: TypographyTokens.labelSmall(
                        isSelected
                            ? ColorTokens.clubAccent
                            : ColorTokens.onSurfaceVariant,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      outcome.label, // Display mapped label
                      style: TypographyTokens.titleSmall().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      '+${market.fetValue} pts',
                      style: TypographyTokens.labelSmall(
                        ColorTokens.clubAccent,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
