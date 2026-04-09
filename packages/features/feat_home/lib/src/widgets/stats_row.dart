import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Side-by-side stat cards — "Global XP" + "Fan Rank"
///
/// Massive Barlow Condensed display numbers with
/// claymorphic containers per the Kinetic Football Authority design system.
class StatsRow extends StatelessWidget {
  final int globalXp;
  final int fanRank;

  const StatsRow({super.key, this.globalXp = 42880, this.fanRank = 12});

  String _formatXp(int xp) {
    if (xp >= 1000) {
      final formatted = xp.toString();
      final buffer = StringBuffer();
      for (var i = 0; i < formatted.length; i++) {
        if (i > 0 && (formatted.length - i) % 3 == 0) {
          buffer.write(',');
        }
        buffer.write(formatted[i]);
      }
      return buffer.toString();
    }
    return xp.toString();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        // Global XP card
        Expanded(
          child: ClayCard(
            backgroundColor: ColorTokens.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing4,
              vertical: SpacingTokens.spacing4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GLOBAL XP',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.onSurface.withValues(alpha: 0.76),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  _formatXp(globalXp),
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: ColorTokens.onSurface,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        // Fan Rank card
        Expanded(
          child: ClayCard(
            backgroundColor: ColorTokens.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing4,
              vertical: SpacingTokens.spacing4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FAN RANK',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.onSurface.withValues(alpha: 0.76),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  '#${fanRank.toString().padLeft(3, '0')}',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Color.alphaBlend(
                      primaryColor.withValues(alpha: 0.6),
                      ColorTokens.onSurface,
                    ),
                    height: 1.0,
                    letterSpacing: -0.5,
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
