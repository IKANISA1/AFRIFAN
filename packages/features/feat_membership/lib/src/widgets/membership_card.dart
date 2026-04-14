import 'dart:ui';

import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Glassmorphic digital membership card — the fan's identity.
class MembershipCard extends ConsumerWidget {
  const MembershipCard({
    super.key,
    this.tierLabel,
    this.fet,
    this.paymentStatus,
  });

  final String? tierLabel;
  final int? fet;
  final PaymentStatus? paymentStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final profile = ref.watch(currentUserProvider);
    final alias = AliasGenerator.format(profile?.publicUserId ?? '000000');
    final resolvedTier = (tierLabel ?? 'Fan').toUpperCase();
    final resolvedFet = fet ?? 0;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: ShapeTokens.cardRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorTokens.clubSecondary, primary.withValues(alpha: 0.6)],
        ),
        boxShadow: [
          BoxShadow(
            color: ColorTokens.ambientShadow,
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: ShapeTokens.cardRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              border: BorderTokens.ghost(),
              borderRadius: ShapeTokens.cardRadius,
            ),
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      RuntimeBranding.displayHomeTeamName.toUpperCase(),
                      style: TypographyTokens.monolithFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ColorTokens.onSurface.withValues(alpha: 0.7),
                        letterSpacing: 2.0,
                      ),
                    ),
                    if (paymentStatus == PaymentStatus.pendingVerification)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.9),
                          borderRadius: ShapeTokens.chipRadius,
                        ),
                        child: Text(
                          'PENDING VERIFICATION',
                          style: TypographyTokens.editorialFont(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    else ...[
                      const Spacer(),
                      Text(
                        'FAN CARD',
                        style: TypographyTokens.editorialFont(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ColorTokens.onSurface.withValues(alpha: 0.5),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ],
                ),

                const Spacer(),

                // Alias display
                Text(
                  alias,
                  style: TypographyTokens.monolithFont(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: ColorTokens.onSurface,
                    letterSpacing: 4.0,
                  ),
                ),

                const SizedBox(height: SpacingTokens.spacing2),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ColorTokens.onSurface.withValues(alpha: 0.15),
                        borderRadius: ShapeTokens.chipRadius,
                      ),
                      child: Text(
                        resolvedTier,
                        style: TypographyTokens.monolithFont(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ColorTokens.onSurface,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$resolvedFet FET',
                      style: TypographyTokens.monolithFont(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
