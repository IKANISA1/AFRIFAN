import 'dart:async';

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
  String _query = '';
  String? _activeCategory;

  /// Dynamically computed categories from actual market data.
  late final List<String> _categories;

  /// Preferred display order — categories appearing here will be placed first.
  static const _preferredOrder = <String>[
    'Match Prediction',
    'Match Betting',
    'Goals Prediction',
    'Goals Betting',
    'Goalscorer Markets',
    'Handicap Prediction',
    'Handicap Betting',
    'Corners Prediction',
    'Corners Betting',
    'Cards Prediction',
    'Cards Betting',
    'Player Props',
    'Match Props',
    'Match Events',
    'In-Play/Live',
    'Combo Markets',
  ];

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
    // Sort: preferred order first, then alphabetical for any new ones.
    orderedCats.sort((a, b) {
      final ai = _preferredOrder.indexOf(a);
      final bi = _preferredOrder.indexOf(b);
      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      if (ai != -1) return -1;
      if (bi != -1) return 1;
      return a.compareTo(b);
    });

    _categories = orderedCats;
    _activeCategory = _categories.isNotEmpty ? _categories.first : null;
  }

  /// Short label for chip display.
  String _chipLabel(String category) {
    // Shorten common suffixes for chip UI
    return category
        .replaceAll(' Prediction', '')
        .replaceAll(' Betting', '')
        .replaceAll(' Markets', '')
        .replaceAll('In-Play/Live', 'LIVE')
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final slip = ref.watch(fanzoneSlipProvider);
    final allMarkets = widget.markets.where((market) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return market.marketName.toLowerCase().contains(q) ||
          market.description.toLowerCase().contains(q) ||
          market.marketShortName.toLowerCase().contains(q) ||
          market.marketCategory.toLowerCase().contains(q);
    }).toList(growable: false);

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
              Text(
                '${allMarkets.length} markets',
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
        // ── Dynamic category chip rail ──
        SizedBox(
          height: 38,
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
                        ? ColorTokens.clubAccent.withValues(alpha: 0.18)
                        : ColorTokens.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                    border: isSelected
                        ? BorderTokens.all(color: ColorTokens.clubAccent)
                        : BorderTokens.ghost(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _chipLabel(cat),
                        style: TypographyTokens.labelSmall(
                          isSelected
                              ? ColorTokens.clubAccent
                              : ColorTokens.onSurfaceVariant,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ColorTokens.clubAccent
                                    .withValues(alpha: 0.25)
                                : ColorTokens.onSurfaceVariant
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: TypographyTokens.editorialFont(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? ColorTokens.clubAccent
                                  : ColorTokens.onSurfaceVariant,
                            ),
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
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: ColorTokens.clubAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Expanded(
                  child: Text(
                    _activeCategory!,
                    style: TypographyTokens.editorialFont(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ColorTokens.onSurfaceVariant,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Text(
                  '${markets.length} ${markets.length == 1 ? 'market' : 'markets'}',
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
                    child: AfriEmptyView(
                      compact: true,
                      title: _query.isNotEmpty
                          ? 'No markets match "$_query"'
                          : 'No markets in this category',
                      icon: AfriIcons.grid,
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
                ? 'Add predictions to unlock slip'
                : 'Open Slip · ${slip.items.length} picks · ${slip.totalPotential} FET',
            icon: AfriIcons.myPicks,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                      style:
                          TypographyTokens.labelSmall(ColorTokens.clubAccent),
                    ),
                  ),
                  if (market.betType.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      market.betType,
                      style: TypographyTokens.editorialFont(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: ColorTokens.onSurfaceVariant,
                        letterSpacing: 0.5,
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
                              AfriIcons.check,
                              size: 14,
                              color: ColorTokens.clubAccent,
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
