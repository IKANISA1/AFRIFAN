import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import 'match_card.dart'; // To reuse MatchSlide

class BorrowedMatchStrip extends StatelessWidget {
  final MatchSlide slide;
  final VoidCallback? onTap;

  const BorrowedMatchStrip({super.key, required this.slide, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AfriPanelCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.screenPadding,
      ),
      backgroundColor: ColorTokens.borrowedPaper,
      borderColor: ColorTokens.transparent,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ColorTokens.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        slide.status.toUpperCase(),
                        style: TypographyTokens.metricLabel(ColorTokens.error)
                            .copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      slide.dateInfo,
                      style:
                          TypographyTokens.metricLabel(
                            ColorTokens.borrowedInkSubtle,
                          ).copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${slide.homeTeam} vs ${slide.awayTeam}'.toUpperCase(),
                        style:
                            TypographyTokens.titleLarge(
                              ColorTokens.borrowedInk,
                            ).copyWith(
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              height: 0.9,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  slide.venue.toUpperCase(),
                  style: TypographyTokens.metricLabel(
                    ColorTokens.borrowedInkFaint,
                  ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ],
            ),
          ),
          Container(
            height: 48,
            width: 1,
            color: ColorTokens.borrowedHairline,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const Icon(
            AfriIcons.chevronRight,
            color: ColorTokens.borrowedInkFaint,
            size: 24,
          ),
        ],
      ),
    );
  }
}
