import 'dart:ui';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Glassmorphic Digital Membership Card — enhanced version with club crest,
/// tier badge, Fan ID, member-since date, and FANZONE watermark.
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.35),
            ColorTokens.surfaceContainer,
          ],
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
              // FANZONE watermark
              Positioned(
                bottom: -20,
                right: -8,
                child: Text(
                  'FANZONE',
                  style: TypographyTokens.monolithFont(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: ColorTokens.onSurface.withValues(alpha: 0.04),
                    letterSpacing: 6,
                  ),
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
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: SpacingTokens.spacing2),
                        ],
                        Expanded(
                          child: Text(
                            clubName.toUpperCase(),
                            style: TypographyTokens.monolithFont(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ColorTokens.onSurface
                                  .withValues(alpha: 0.7),
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        if (onShare != null)
                          GestureDetector(
                            onTap: onShare,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpacingTokens.spacing3,
                                vertical: SpacingTokens.spacing2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AfriIcons.share,
                                    size: 12,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'SHARE',
                                    style:
                                        TypographyTokens.editorialFont(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                      letterSpacing: 1,
                                    ),
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
                      style: TypographyTokens.monolithFont(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: ColorTokens.onSurface,
                        letterSpacing: 4,
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
                            style: TypographyTokens.monolithFont(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (memberSince != null)
                          Text(
                            'Since $memberSince',
                            style: TypographyTokens.editorialFont(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: ColorTokens.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
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
