import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'glass_card.dart';

/// A single stat definition for [AfriStatRow].
class AfriStat {
  const AfriStat({
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;
}

/// Horizontal row of 2–4 compact stat tiles with equal flex distribution.
///
/// Replaces `_HeroMetric`, `_MetricPill`, `StatsRow`, and ad-hoc inline
/// metric layouts spread across screens.
///
/// ```dart
/// AfriStatRow(
///   stats: [
///     AfriStat(label: 'Win rate', value: '72%'),
///     AfriStat(label: 'Streak', value: '5'),
///     AfriStat(label: 'Balance', value: '1,250'),
///   ],
/// )
/// ```
class AfriStatRow extends StatelessWidget {
  const AfriStatRow({super.key, required this.stats, this.compact = false});

  static const double _largeTextMinTileWidth = 160;

  final List<AfriStat> stats;

  /// When true, renders as inline chips instead of cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Wrap(
        spacing: SpacingTokens.inlineGap,
        runSpacing: SpacingTokens.inlineGap,
        children: stats.map((stat) => _CompactStat(stat: stat)).toList(),
      );
    }

    final useLargeTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >= 1.5 && stats.length > 2;
    if (useLargeTextLayout) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final twoColumnWidth =
              (constraints.maxWidth - SpacingTokens.listItemGap) / 2;
          final itemWidth = twoColumnWidth >= _largeTextMinTileWidth
              ? twoColumnWidth
              : constraints.maxWidth;
          return Wrap(
            spacing: SpacingTokens.listItemGap,
            runSpacing: SpacingTokens.listItemGap,
            children: [
              for (final stat in stats)
                SizedBox(
                  width: itemWidth,
                  child: _StatTile(stat: stat, allowTwoLineLabel: true),
                ),
            ],
          );
        },
      );
    }

    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: SpacingTokens.listItemGap),
          Expanded(child: _StatTile(stat: stats[i])),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, this.allowTwoLineLabel = false});

  final AfriStat stat;
  final bool allowTwoLineLabel;

  @override
  Widget build(BuildContext context) {
    final accent = ColorTokens.accessibleMetricColor(
      stat.accentColor ?? ColorTokens.primaryContainer,
    );
    final supporting = ColorTokens.accessibleMetricColor(
      ColorTokens.onSurfaceVariant,
    );
    final child = GlassCard(
      animate: false,
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stat.icon != null) ...[
            Icon(stat.icon, size: SizeTokens.iconXs, color: accent),
            const SizedBox(height: SpacingTokens.spacing2),
          ],
          Text(
            stat.label,
            style: TypographyTokens.metricLabel(supporting),
            maxLines: allowTwoLineLabel ? 2 : 1,
            overflow: allowTwoLineLabel
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            stat.value,
            style: TypographyTokens.metricValue(accent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (stat.onTap == null) return child;

    return GestureDetector(
      onTap: stat.onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({required this.stat});

  final AfriStat stat;

  @override
  Widget build(BuildContext context) {
    final color = ColorTokens.accessibleMetricColor(
      stat.accentColor ?? ColorTokens.primaryContainer,
    );
    final supporting = ColorTokens.accessibleMetricColor(
      ColorTokens.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2,
      ),
      decoration: BoxDecoration(
        borderRadius: ShapeTokens.buttonRadius,
        color: color.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(stat.label, style: TypographyTokens.metricLabel(supporting)),
          const SizedBox(width: SpacingTokens.spacing2),
          Text(
            stat.value,
            style: TypographyTokens.labelMedium(
              color,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
