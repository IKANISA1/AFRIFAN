import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fanzone_slip_providers.dart';
import '../models/prediction_models.dart';
import 'market_option_pill.dart';

Future<void> showMarketSelectorSheet({
  required BuildContext context,
  required FixtureSummary fixture,
  required List<FixtureMarket> markets,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColorTokens.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) => _MarketSelectorContent(
        fixture: fixture,
        markets: markets,
        scrollController: scrollController,
      ),
    ),
  );
}

class _MarketSelectorContent extends ConsumerStatefulWidget {
  const _MarketSelectorContent({
    required this.fixture,
    required this.markets,
    required this.scrollController,
  });

  final FixtureSummary fixture;
  final List<FixtureMarket> markets;
  final ScrollController scrollController;

  @override
  ConsumerState<_MarketSelectorContent> createState() =>
      _MarketSelectorContentState();
}

class _MarketSelectorContentState
    extends ConsumerState<_MarketSelectorContent> {
  static const List<(MarketGroup, String)> _groupOrder =
      <(MarketGroup, String)>[
        (MarketGroup.matchResult, 'MATCH'),
        (MarketGroup.goals, 'GOALS'),
        (MarketGroup.scorers, 'PLAYERS'),
        (MarketGroup.specials, 'SPECIALS'),
      ];

  String _query = '';
  MarketGroup _activeGroup = MarketGroup.matchResult;

  @override
  Widget build(BuildContext context) {
    final slip = ref.watch(fanzoneSlipProvider);
    final allMarkets = widget.markets
        .where((market) {
          final q = _query.trim().toLowerCase();
          if (q.isEmpty) return true;
          return market.marketName.toLowerCase().contains(q) ||
              market.description.toLowerCase().contains(q) ||
              market.marketShortName.toLowerCase().contains(q);
        })
        .toList(growable: false);
    final markets = allMarkets
        .where((market) => market.marketGroup == _activeGroup)
        .toList(growable: false);

    return Column(
      children: [
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
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.fixture.fixtureLabel,
                  style: TypographyTokens.monolithFont(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurface,
                  ),
                ),
              ),
              Text('Markets', style: TypographyTokens.bodySmall()),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search markets',
              prefixIcon: const Icon(AfriIcons.search),
              filled: true,
              fillColor: ColorTokens.surfaceContainerHigh,
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: _groupOrder.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: SpacingTokens.spacing2),
            itemBuilder: (context, index) {
              final group = _groupOrder[index].$1;
              final label = _groupOrder[index].$2;
              final isSelected = _activeGroup == group;
              return AfriPressFeedback(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeGroup = group);
                },
                builder: (context, state) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing3,
                    vertical: SpacingTokens.spacing2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ColorTokens.clubAccent.withValues(alpha: 0.18)
                        : ColorTokens.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                    border: isSelected
                        ? BorderTokens.all(color: ColorTokens.clubAccent)
                        : BorderTokens.ghost(),
                  ),
                  child: Text(
                    label,
                    style: TypographyTokens.labelSmall(
                      isSelected
                          ? ColorTokens.clubAccent
                          : ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        Expanded(
          child: ListView.separated(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.spacing6,
              0,
              SpacingTokens.spacing6,
              SpacingTokens.spacing6,
            ),
            itemBuilder: (context, index) => _SheetMarketCard(
              fixture: widget.fixture,
              market: markets[index],
            ),
            separatorBuilder: (_, __) =>
                const SizedBox(height: SpacingTokens.spacing3),
            itemCount: markets.length,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.spacing6,
            0,
            SpacingTokens.spacing6,
            SpacingTokens.spacing6,
          ),
          child: AfriButton(
            label: slip.items.isEmpty
                ? 'Add predictions to unlock slip'
                : 'Open Slip · ${slip.items.length} picks · ${slip.totalPotential} FET',
            icon: Icons.receipt_long_rounded,
            enabled: slip.items.isNotEmpty,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _SheetMarketCard extends ConsumerWidget {
  const _SheetMarketCard({required this.fixture, required this.market});

  final FixtureSummary fixture;
  final FixtureMarket market;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slip = ref.watch(fanzoneSlipProvider);
    final selected = slip.items
        .where((item) => item.fixtureMarketId == market.fixtureMarketId)
        .cast()
        .firstOrNull;

    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      market.marketName,
                      style: TypographyTokens.titleSmall(),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing2,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+${market.fetValue} FET',
                  style: TypographyTokens.labelSmall(ColorTokens.clubAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (market.isLocked)
            Text(
              'Live only',
              style: TypographyTokens.labelMedium(ColorTokens.warning),
            )
          else
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: market.outcomes
                  .map((outcome) {
                    final isSelected = selected?.outcomeKey == outcome.key;
                    return MarketOptionPill(
                      label: outcome.label,
                      isSelected: isSelected,
                      trailing: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: ColorTokens.clubAccent,
                            )
                          : null,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(fanzoneSlipProvider.notifier)
                            .addFromMarket(
                              fixture: fixture,
                              market: market,
                              outcome: outcome,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${outcome.label} added to your slip.',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}
