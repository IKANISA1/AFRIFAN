import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import 'match_card.dart'; // To reuse MatchSlide

class MatchStrip extends StatelessWidget {
  final MatchSlide slide;
  final VoidCallback? onTap;

  const MatchStrip({super.key, required this.slide, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;

    return AfriPanelCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing5,
        vertical: SpacingTokens.spacing4,
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.screenPadding,
      ),
      backgroundColor: ColorTokens.paperSurface,
      borderColor: ColorTokens.transparent,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: SpacingTokens.spacing2,
                  runSpacing: SpacingTokens.spacing1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing2,
                        vertical: SpacingTokens.spacing1 / 2,
                      ),
                      decoration: BoxDecoration(
                        color: ColorTokens.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          SpacingTokens.spacing1,
                        ),
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
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLargeText ? 180 : double.infinity,
                      ),
                      child: Text(
                        slide.dateInfo,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TypographyTokens.metricLabel(
                              ColorTokens.inkSubtle,
                            ).copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.afriL10n
                            .homeMatchTitle(slide.homeTeam, slide.awayTeam)
                            .toUpperCase(),
                        style: TypographyTokens.titleLarge(ColorTokens.inkBase)
                            .copyWith(
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              height: TypographyTokens.lineHeightHero,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  slide.venue.toUpperCase(),
                  style: TypographyTokens.metricLabel(
                    ColorTokens.inkFaint,
                  ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ],
            ),
          ),
          Container(
            height: SpacingTokens.spacing12,
            width: BorderTokens.standard,
            color: ColorTokens.inkHairline,
            margin: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing4,
            ),
          ),
          const Icon(
            AfriIcons.chevronRight,
            color: ColorTokens.inkFaint,
            size: SpacingTokens.spacing6,
          ),
        ],
      ),
    );
  }
}
