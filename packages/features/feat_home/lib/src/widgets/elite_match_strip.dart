import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import 'match_card.dart'; // To reuse MatchSlide

class EliteMatchStrip extends StatelessWidget {
  final MatchSlide slide;
  final VoidCallback? onTap;

  const EliteMatchStrip({super.key, required this.slide, this.onTap});

  @override
  Widget build(BuildContext context) {
    return EliteCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.screenPadding,
      ),
      backgroundColor: Colors.white,
      borderColor: Colors.transparent,
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
                        style: const TextStyle(
                          color: ColorTokens.error,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      slide.dateInfo,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.4),
                        fontSize: 10,
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
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontFamily: TypographyTokens.borrowedFontFamily,
                          package: 'core_theme',
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
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.3),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 48,
            width: 1,
            color: Colors.black.withValues(alpha: 0.05),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.black26,
            size: 24,
          ),
        ],
      ),
    );
  }
}
