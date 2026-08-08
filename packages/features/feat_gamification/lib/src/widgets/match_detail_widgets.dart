import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fanzone_slip_providers.dart';
import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';
import '../widgets/community_prediction_bar.dart';
import '../widgets/market_option_pill.dart';
import '../widgets/market_selector_sheet.dart';
import '../widgets/stats_panel.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Predict Tab
// ══════════════════════════════════════════════════════════════════════════════

/// The "Predict" tab — shows featured markets + community picks.
class MatchPredictTabBody extends StatelessWidget {
  const MatchPredictTabBody({
    super.key,
    required this.fixture,
    required this.markets,
    required this.communityPicks,
  });

  final FixtureSummary fixture;
  final List<FixtureMarket> markets;
  final Map<String, List<CommunityPick>> communityPicks;

  /// Picks one featured market per category, up to 6.
  List<FixtureMarket> _featuredMarkets() {
    final seen = <String>{};
    final result = <FixtureMarket>[];
    for (final m in markets) {
      if (result.length >= 6) break;
      if (m.marketCategory.isNotEmpty && seen.add(m.marketCategory)) {
        result.add(m);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final featuredMarkets = _featuredMarkets();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        AfriSectionCard(
          title: context.afriL10n.gameMarkets,
          trailingLabel: markets.isEmpty
              ? null
              : context.afriL10n.gameMarketCount(markets.length),
          onTrailingTap: markets.isEmpty
              ? null
              : () {
                  unawaited(
                    showMarketSelectorSheet(
                      context: context,
                      fixture: fixture,
                      markets: markets,
                    ),
                  );
                },
          child: featuredMarkets.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  children: featuredMarkets
                      .asMap()
                      .entries
                      .map((entry) {
                        final market = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key == featuredMarkets.length - 1
                                ? 0
                                : SpacingTokens.spacing3,
                          ),
                          child: MatchMarketCard(
                            fixture: fixture,
                            market: market,
                            communityPicks:
                                communityPicks[market.fixtureMarketId] ??
                                const <CommunityPick>[],
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
        ),
        const SizedBox(
          height: SpacingTokens.spacing20 + SpacingTokens.spacing10,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Stats Tab
// ══════════════════════════════════════════════════════════════════════════════

/// The "Stats" tab — shows match statistics or derived score-based stats.
class MatchStatsTabBody extends StatelessWidget {
  const MatchStatsTabBody({
    super.key,
    required this.fixture,
    required this.stats,
  });

  final FixtureSummary fixture;
  final List<MatchStatRow> stats;

  @override
  Widget build(BuildContext context) {
    final hasScores = fixture.homeScore != null && fixture.awayScore != null;

    if (!hasScores) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          const SizedBox(height: SpacingTokens.spacing8),
          AfriEmptyView(
            compact: true,
            title: context.afriL10n.gameStatsNotAvailableYet,
            message: context.afriL10n.fanZoneStatsEmpty,
            icon: AfriIcons.chart,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriSurfaceCard(
            child: Row(
              children: [
                Icon(
                  AfriIcons.statusInfo,
                  size: SpacingTokens.spacing4,
                  color: ColorTokens.onSurfaceVariant,
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Expanded(
                  child: Text(
                    context.afriL10n.gameLiveStatsUpdating,
                    style: TypographyTokens.bodySmall(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (stats.isNotEmpty) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          StatsPanel(
            stats: stats,
            homeLabel: fixture.homeTeamShort,
            awayLabel: fixture.awayTeamShort,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriSurfaceCard(
            child: Row(
              children: [
                Icon(
                  AfriIcons.statusInfo,
                  size: SpacingTokens.spacing4,
                  color: ColorTokens.onSurfaceVariant,
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Expanded(
                  child: Text(
                    fixture.isLive
                        ? context.afriL10n.gameLiveMatchDataUpdating
                        : context.afriL10n.gameStructuredMatchStats,
                    style: TypographyTokens.bodySmall(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final homeGoals = fixture.homeScore ?? 0;
    final awayGoals = fixture.awayScore ?? 0;
    final totalGoals = homeGoals + awayGoals;

    final liveStats = <MatchStatRow>[
      MatchStatRow(
        label: context.afriL10n.gameGoals,
        leftValue: homeGoals.toDouble(),
        rightValue: awayGoals.toDouble(),
        leftDisplay: homeGoals.toString(),
        rightDisplay: awayGoals.toString(),
      ),
      MatchStatRow(
        label: context.afriL10n.gameTotalGoals,
        leftValue: totalGoals.toDouble(),
        rightValue: totalGoals.toDouble(),
        leftDisplay: totalGoals.toString(),
        rightDisplay: totalGoals.toString(),
      ),
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        StatsPanel(
          stats: liveStats,
          homeLabel: fixture.homeTeamShort,
          awayLabel: fixture.awayTeamShort,
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        AfriSurfaceCard(
          child: Row(
            children: [
              Icon(
                AfriIcons.statusInfo,
                size: SpacingTokens.spacing4,
                color: ColorTokens.onSurfaceVariant,
              ),
              const SizedBox(width: SpacingTokens.spacing2),
              Expanded(
                child: Text(
                  fixture.isLive
                      ? context.afriL10n.gameLiveStatsUpdating
                      : context.afriL10n.gameFinalMatchStats,
                  style: TypographyTokens.bodySmall(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Pick Type Card
// ══════════════════════════════════════════════════════════════════════════════

/// Single pick-type card with outcome pills + community bar.
class MatchMarketCard extends ConsumerWidget {
  const MatchMarketCard({
    super.key,
    required this.fixture,
    required this.market,
    required this.communityPicks,
  });

  final FixtureSummary fixture;
  final FixtureMarket market;
  final List<CommunityPick> communityPicks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slip = ref.watch(fanzoneSlipProvider);
    final selected = slip.items
        .where((item) => item.fixtureMarketId == market.fixtureMarketId)
        .toList(growable: false);
    final selectedOutcomeKey = selected.isEmpty
        ? null
        : selected.first.outcomeKey;

    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category + bet type chip row ──
          if (market.marketCategory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing2,
                      vertical: SpacingTokens.spacing1,
                    ),
                    decoration: BoxDecoration(
                      color: ColorTokens.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(
                        ShapeTokens.radiusFull,
                      ),
                    ),
                    child: Text(
                      _displayCategoryLabel(market.marketCategory),
                      style:
                          TypographyTokens.metricLabel(
                            ColorTokens.onSurfaceVariant,
                          ).copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.afriL10n.gameFixtureMarketTitle(
                        fixture.homeTeamShort,
                        fixture.awayTeamShort,
                        market.marketName,
                      ),
                      style: TypographyTokens.titleMedium(),
                    ),
                    if (market.description.isNotEmpty) ...[
                      const SizedBox(height: SpacingTokens.spacing1),
                      Text(
                        market.description,
                        style: TypographyTokens.bodySmall(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Text(
                context.afriL10n.gamePoints(market.fetValue),
                style: TypographyTokens.labelSmall(ColorTokens.clubAccent),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (market.isLocked)
            Text(
              context.afriL10n.gamePickTypeLocked,
              style: TypographyTokens.bodySmall(),
            )
          else
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: market.outcomes
                  .map((outcome) {
                    return MarketOptionPill(
                      label: outcome.label,
                      isSelected: selectedOutcomeKey == outcome.key,
                      trailing: selectedOutcomeKey == outcome.key
                          ? Icon(
                              AfriIcons.check,
                              size:
                                  SpacingTokens.spacing3 +
                                  SpacingTokens.spacing1 / 2,
                              color: ColorTokens.clubAccent,
                            )
                          : null,
                      onTap: () {
                        ref
                            .read(fanzoneSlipProvider.notifier)
                            .addFromMarket(
                              fixture: fixture,
                              market: market,
                              outcome: outcome,
                            );
                        AfriToast.success(
                          context,
                          context.afriL10n.gameOutcomeAddedToRound(
                            outcome.label,
                          ),
                        );
                      },
                    );
                  })
                  .toList(growable: false),
            ),
          if (communityPicks.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            CommunityPredictionBar(
              picks: communityPicks,
              userSelection:
                  selectedOutcomeKey ?? market.userPrediction?.selectedOutcome,
            ),
          ],
        ],
      ),
    );
  }

  String _displayCategoryLabel(String category) {
    return category
        .replaceAll('Match Prediction', 'Match Picks')
        .replaceAll('Goals Prediction', 'Goal Picks')
        .replaceAll('Handicap Prediction', 'Handicap Picks')
        .replaceAll('Corners Prediction', 'Corner Picks')
        .replaceAll('Cards Prediction', 'Card Picks')
        .replaceAll('Prediction', 'Pick')
        .replaceAll('Markets', 'Pick Types');
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Meta Link
// ══════════════════════════════════════════════════════════════════════════════

/// Mini pill link to league/team profiles from within the hero card.
class MatchMetaLink extends StatelessWidget {
  const MatchMetaLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing3,
          vertical: SpacingTokens.spacing2,
        ),
        decoration: BoxDecoration(
          color: ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
          border: BorderTokens.all(color: ColorTokens.ghostBorder),
        ),
        child: Text(
          label,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
      ),
    );
  }
}
