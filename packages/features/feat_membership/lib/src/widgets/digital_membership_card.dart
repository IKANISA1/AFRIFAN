import 'dart:ui';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Glassmorphic Digital Membership Card — enhanced version with club crest,
/// tier badge, Fan ID, member-since date, and Gikundiro watermark.
///
/// Mirrors the fanafrika `DigitalMembershipCard.tsx`.
class DigitalMembershipCardFull extends StatelessWidget {
  const DigitalMembershipCardFull({
    super.key,
    required this.clubName,
    required this.tier,
    required this.fanId,
    this.crest,
    this.memberSince,
    this.accentColor,
    this.onShare,
  });

  final String clubName;
  final String tier;
  final String fanId;
  final String? crest;
  final String? memberSince;
  final Color? accentColor;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? ColorTokens.clubAccent;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: ShapeTokens.cardRadius,
        gradient: ColorTokens.borrowedSurfaceGradient(
          from: accent.withValues(alpha: 0.35),
          to: ColorTokens.surfaceContainer,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: ShapeTokens.cardRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Stack(
            children: [
              // Gikundiro watermark
              Positioned(
                bottom: -20,
                right: -8,
                child: Text(
                  'GIKUNDIRO',
                  style: TypographyTokens.displayLarge(
                    ColorTokens.onSurface.withValues(alpha: 0.04),
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ),

              // Content
              Container(
                decoration: BoxDecoration(
                  borderRadius: ShapeTokens.cardRadius,
                  border: BorderTokens.ghost(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Club name + Share button
                    Row(
                      children: [
                        if (crest != null) ...[
                          Text(
                            crest!,
                            style: TypographyTokens.headlineMedium(),
                          ),
                          const SizedBox(width: SpacingTokens.spacing2),
                        ],
                        Expanded(
                          child: Text(
                            clubName.toUpperCase(),
                            style: TypographyTokens.labelLarge(
                              ColorTokens.onSurface.withValues(alpha: 0.7),
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (onShare != null)
                          AfriPressFeedback(
                            onTap: onShare,
                            tooltip: 'Share membership card',
                            semanticsLabel: 'Share membership card',
                            semanticsHint: 'Share your digital membership card',
                            excludeChildSemantics: true,
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight:
                                    SpacingTokens.spacing10 +
                                    SpacingTokens.spacing1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpacingTokens.spacing3,
                                vertical: SpacingTokens.spacing2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(
                                  ShapeTokens.radiusFull,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AfriIcons.share,
                                    size: 12,
                                    color: accent,
                                  ),
                                  const SizedBox(width: SpacingTokens.spacing1),
                                  Text(
                                    'SHARE',
                                    style: TypographyTokens.labelSmall(
                                      accent,
                                    ).copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    const Spacer(),

                    // Fan ID — large prominent display
                    Text(
                          fanId,
                          style: TypographyTokens.displaySmall().copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: -0.03, end: 0, duration: 400.ms),

                    const SizedBox(height: SpacingTokens.spacing2),

                    // Bottom row: Tier badge + Member Since
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.2),
                            borderRadius: ShapeTokens.chipRadius,
                            border: BorderTokens.all(
                              color: accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            tier.toUpperCase(),
                            style: TypographyTokens.labelMedium(
                              accent,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Spacer(),
                        if (memberSince != null)
                          Text(
                            'Since $memberSince',
                            style: TypographyTokens.bodySmall(
                              ColorTokens.onSurfaceVariant,
                            ).copyWith(fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
