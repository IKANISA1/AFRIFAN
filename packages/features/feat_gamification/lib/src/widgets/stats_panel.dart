import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A single stat comparison row (e.g. Possession 55% vs 45%).
class MatchStatRow {
  const MatchStatRow({
    required this.label,
    required this.leftValue,
    required this.rightValue,
    required this.leftDisplay,
    required this.rightDisplay,
  });

  final String label;
  final double leftValue;
  final double rightValue;
  final String leftDisplay;
  final String rightDisplay;
}

/// Horizontal comparison bars for match statistics.
///
/// Mirrors the web reference `StatsPanel.tsx` — each row shows
/// left value → animated dual-colour bar → right value.
class StatsPanel extends StatelessWidget {
  const StatsPanel({
    super.key,
    required this.stats,
    this.title = 'MATCH STATS',
    this.homeLabel,
    this.awayLabel,
  });

  final List<MatchStatRow> stats;
  final String title;
  final String? homeLabel;
  final String? awayLabel;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (homeLabel != null && awayLabel != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  homeLabel!.toUpperCase(),
                  style: TypographyTokens.editorialFont(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.clubAccent,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  title,
                  style: TypographyTokens.monolithFont(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  awayLabel!.toUpperCase(),
                  style: TypographyTokens.editorialFont(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ] else ...[
            Text(
              title,
              style: TypographyTokens.monolithFont(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorTokens.onSurfaceVariant,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          ...stats.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key < stats.length - 1
                    ? SpacingTokens.spacing3
                    : 0,
              ),
              child: _StatComparisonRow(
                stat: entry.value,
                delay: entry.key * 80,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatComparisonRow extends StatelessWidget {
  const _StatComparisonRow({required this.stat, required this.delay});

  final MatchStatRow stat;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final total = stat.leftValue + stat.rightValue;
    final leftPct = total > 0 ? stat.leftValue / total : 0.5;
    final rightPct = total > 0 ? stat.rightValue / total : 0.5;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              stat.leftDisplay,
              style: TypographyTokens.monolithFont(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: leftPct >= rightPct
                    ? ColorTokens.onSurface
                    : ColorTokens.onSurfaceVariant,
              ),
            ),
            Text(
              stat.label.toUpperCase(),
              style: TypographyTokens.editorialFont(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: ColorTokens.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              stat.rightDisplay,
              style: TypographyTokens.monolithFont(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: rightPct > leftPct
                    ? ColorTokens.onSurface
                    : ColorTokens.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                Flexible(
                  flex: (leftPct * 1000).round().clamp(1, 999),
                  child: Container(color: ColorTokens.clubAccent)
                      .animate(delay: delay.ms)
                      .scaleX(
                        begin: 0,
                        end: 1,
                        duration: 500.ms,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerLeft,
                      ),
                ),
                const SizedBox(width: 2),
                Flexible(
                  flex: (rightPct * 1000).round().clamp(1, 999),
                  child: Container(
                    color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.35),
                  )
                      .animate(delay: delay.ms)
                      .scaleX(
                        begin: 0,
                        end: 1,
                        duration: 500.ms,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerRight,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
