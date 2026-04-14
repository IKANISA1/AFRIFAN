import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/prediction_models.dart';
import 'market_option_pill.dart';

/// Bottom sheet for browsing all available markets on a fixture.
///
/// Groups markets by category (Match Result, Goals, Scorers, Specials)
/// with progressive disclosure and FET value display.
Future<void> showMarketSelectorSheet({
  required BuildContext context,
  required List<FixtureMarket> markets,
  required Map<String, String> selections,
  required void Function(FixtureMarket market, MarketOutcomeOption outcome)
      onOutcomeSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColorTokens.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => _MarketSelectorContent(
        markets: markets,
        selections: selections,
        onOutcomeSelected: onOutcomeSelected,
        scrollController: scrollController,
      ),
    ),
  );
}

class _MarketSelectorContent extends StatelessWidget {
  const _MarketSelectorContent({
    required this.markets,
    required this.selections,
    required this.onOutcomeSelected,
    required this.scrollController,
  });

  final List<FixtureMarket> markets;
  final Map<String, String> selections;
  final void Function(FixtureMarket market, MarketOutcomeOption outcome)
      onOutcomeSelected;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    // Group markets by category
    final groups = <MarketGroup, List<FixtureMarket>>{};
    for (final market in markets) {
      groups.putIfAbsent(market.marketGroup, () => []).add(market);
    }

    final groupOrder = [
      MarketGroup.matchResult,
      MarketGroup.goals,
      MarketGroup.scorers,
      MarketGroup.specials,
    ];

    return Column(
      children: [
        // ── Handle ──
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        Text(
          'ALL MARKETS',
          style: TypographyTokens.monolithFont(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurface,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),

        // ── Market groups ──
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
            ),
            children: [
              for (final group in groupOrder)
                if (groups.containsKey(group)) ...[
                  _GroupHeader(group: group),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ...groups[group]!.map(
                    (market) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: SpacingTokens.spacing3,
                      ),
                      child: _SheetMarketCard(
                        market: market,
                        selectedKey: selections[market.fixtureMarketId],
                        onOutcomeSelected: (outcome) {
                          HapticFeedback.lightImpact();
                          onOutcomeSelected(market, outcome);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                ],
              const SizedBox(height: SpacingTokens.spacing8),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final MarketGroup group;

  String _label() {
    return switch (group) {
      MarketGroup.matchResult => 'MATCH RESULT',
      MarketGroup.goals => 'GOALS',
      MarketGroup.scorers => 'GOALSCORERS',
      MarketGroup.specials => 'SPECIALS',
    };
  }

  IconData _icon() {
    return switch (group) {
      MarketGroup.matchResult => Icons.emoji_events_outlined,
      MarketGroup.goals => Icons.sports_score_rounded,
      MarketGroup.scorers => Icons.person_outline_rounded,
      MarketGroup.specials => Icons.auto_awesome_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_icon(), size: 16, color: ColorTokens.clubAccent),
        const SizedBox(width: 8),
        Text(
          _label(),
          style: TypographyTokens.monolithFont(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SheetMarketCard extends StatelessWidget {
  const _SheetMarketCard({
    required this.market,
    required this.selectedKey,
    required this.onOutcomeSelected,
  });

  final FixtureMarket market;
  final String? selectedKey;
  final void Function(MarketOutcomeOption outcome) onOutcomeSelected;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  market.marketName,
                  style: TypographyTokens.titleSmall(),
                ),
              ),
              Text(
                '+${market.fetValue} FET',
                style: TypographyTokens.monolithFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ColorTokens.clubAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (market.isLocked)
            Text(
              'MARKET LOCKED',
              style: TypographyTokens.bodySmall(),
            )
          else
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: market.outcomes.map((outcome) {
                return MarketOptionPill(
                  label: outcome.label,
                  isSelected: selectedKey == outcome.key,
                  onTap: () => onOutcomeSelected(outcome),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }
}
