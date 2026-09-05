import 'dart:async';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fanzone_slip_providers.dart';
import '../models/prediction_models.dart';
import 'market_option_pill.dart';

Future<void> showMarketSelectorSheet({
  required BuildContext context,
  required FixtureSummary fixture,
  required List<FixtureMarket> markets,
}) {
  return showAfriBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useUniversalSurface: false,
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
  final _searchController = TextEditingController();
  String _query = '';
  String? _activeCategory;

  /// Dynamically computed categories from actual market data.
  late final List<String> _categories;

  @override
  void initState() {
    super.initState();
    // Build category list from the actual markets, preserving preferred order.
    final seen = <String>{};
    final orderedCats = <String>[];
    for (final market in widget.markets) {
      final cat = market.marketCategory;
      if (cat.isNotEmpty && seen.add(cat)) {
        orderedCats.add(cat);
      }
    }
    final preferredOrder =
        ref
            .read(featureConfigProvider)
            .valueOrNull
            ?.stringOptions('prediction_market_category_order') ??
        const <String>[];
    // Sort: admin-managed order first, then alphabetical for any new ones.
    orderedCats.sort((a, b) {
      final ai = preferredOrder.indexOf(a);
      final bi = preferredOrder.indexOf(b);
      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      if (ai != -1) return -1;
      if (bi != -1) return 1;
      return a.compareTo(b);
    });

    _categories = orderedCats;
    _activeCategory = _categories.isNotEmpty ? _categories.first : null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Short label for chip display.
  String _chipLabel(String category) {
    // Shorten common suffixes for chip UI
    return _displayCategoryLabel(category)
        .replaceAll(' Prediction', '')
        .replaceAll(' Picks', '')
        .replaceAll(' Markets', '')
        .replaceAll('In-Play/Live', 'LIVE')
        .toUpperCase();
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

  @override
  Widget build(BuildContext context) {
    final slip = ref.watch(fanzoneSlipProvider);
    final allMarkets = widget.markets
        .where((market) {
          final q = _query.trim().toLowerCase();
          if (q.isEmpty) return true;
          return market.marketName.toLowerCase().contains(q) ||
              market.description.toLowerCase().contains(q) ||
              market.marketShortName.toLowerCase().contains(q) ||
              market.marketCategory.toLowerCase().contains(q);
        })
        .toList(growable: false);

    final markets = _activeCategory == null
        ? allMarkets
        : allMarkets
              .where((m) => m.marketCategory == _activeCategory)
              .toList(growable: false);

    // Market count per category for badges.
    final countByCategory = <String, int>{};
    for (final m in allMarkets) {
      countByCategory[m.marketCategory] =
          (countByCategory[m.marketCategory] ?? 0) + 1;
    }

    return Column(
      children: [
        const SizedBox(height: SpacingTokens.spacing3),
        Container(
          width: SpacingTokens.spacing9,
          height: SpacingTokens.spacing1,
          decoration: BoxDecoration(
            color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
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
                  style: TypographyTokens.titleLarge().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                context.afriL10n.gamePickTypeCount(allMarkets.length),
                style: TypographyTokens.labelSmall(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          child: AfriInputField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            hint: context.afriL10n.gameSearchPickTypes,
            prefixIcon: AfriIcons.search,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        // ── Dynamic category chip rail ──
        SizedBox(
          height: SpacingTokens.spacing9 + SpacingTokens.spacing1 / 2,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: SpacingTokens.spacing2),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _activeCategory == cat;
              final count = countByCategory[cat] ?? 0;
              return AfriPressFeedback(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  setState(() => _activeCategory = cat);
                },
                builder: (context, state) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing3,
                    vertical: SpacingTokens.spacing2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ColorTokens.primaryContainer.withValues(alpha: 0.18)
                        : ColorTokens.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
                    border: isSelected
                        ? BorderTokens.all(color: ColorTokens.primaryContainer)
                        : BorderTokens.ghost(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _chipLabel(cat),
                        style: TypographyTokens.labelSmall(
                          isSelected
                              ? ColorTokens.primaryContainer
                              : ColorTokens.onSurfaceVariant,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: SpacingTokens.spacing1),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.spacing2,
                            vertical: SpacingTokens.spacing1 / 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ColorTokens.primaryContainer.withValues(
                                    alpha: 0.25,
                                  )
                                : ColorTokens.onSurfaceVariant.withValues(
                                    alpha: 0.12,
                                  ),
                            borderRadius: BorderRadius.circular(
                              ShapeTokens.radiusFull,
                            ),
                          ),
                          child: Text(
                            count.toString(),
                            style: TypographyTokens.metricLabel(
                              isSelected
                                  ? ColorTokens.primaryContainer
                                  : ColorTokens.onSurfaceVariant,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        // ── Category label ──
        if (_activeCategory != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.spacing6,
              0,
              SpacingTokens.spacing6,
              SpacingTokens.spacing3,
            ),
            child: Row(
              children: [
                Container(
                  width: SpacingTokens.spacing1,
                  height: SpacingTokens.spacing4 - SpacingTokens.spacing1 / 2,
                  decoration: BoxDecoration(
                    color: ColorTokens.primaryContainer,
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Expanded(
                  child: Text(
                    _displayCategoryLabel(_activeCategory!),
                    style:
                        TypographyTokens.metricLabel(
                          ColorTokens.onSurfaceVariant,
                        ).copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: TypographyTokens.trackingNone,
                        ),
                  ),
                ),
                Text(
                  context.afriL10n.gamePickTypeCount(markets.length),
                  style: TypographyTokens.bodySmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: markets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    child: _query.isEmpty
                        ? const SizedBox.shrink()
                        : AfriButton(
                            label: context.afriL10n.gameClearSearch,
                            icon: AfriIcons.filter,
                            variant: AfriButtonVariant.secondary,
                            onTap: () {
                              setState(() {
                                _query = '';
                                _searchController.clear();
                              });
                            },
                          ),
                  ),
                )
              : ListView.separated(
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
                ? context.afriL10n.gameAddPicksToUnlock
                : context.afriL10n.gameOpenRoundSummary(
                    slip.items.length,
                    slip.totalPotential,
                  ),
            icon: AfriIcons.myPicks,
            enabled: slip.items.isNotEmpty,
            onTap: () => context.pop(),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing2,
                      vertical: SpacingTokens.spacing1,
                    ),
                    decoration: BoxDecoration(
                      color: ColorTokens.primaryContainer.withValues(
                        alpha: 0.18,
                      ),
                      borderRadius: BorderRadius.circular(
                        ShapeTokens.radiusFull,
                      ),
                    ),
                    child: Text(
                      context.afriL10n.gamePoints(market.fetValue),
                      style: TypographyTokens.labelSmall(
                        ColorTokens.primaryContainer,
                      ),
                    ),
                  ),
                  if (market.betType.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      market.betType,
                      style:
                          TypographyTokens.metricLabel(
                            ColorTokens.onSurfaceVariant,
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: TypographyTokens.trackingNone,
                          ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (market.isLocked)
            Text(
              context.afriL10n.gameLiveOnly,
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
                              AfriIcons.check,
                              size:
                                  SpacingTokens.spacing3 +
                                  SpacingTokens.spacing1 / 2,
                              color: ColorTokens.primaryContainer,
                            )
                          : null,
                      onTap: () {
                        unawaited(HapticFeedback.lightImpact());
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
        ],
      ),
    );
  }
}
