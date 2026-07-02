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
    final profile = ref.watch(currentUserProvider);
    final alias = AliasGenerator.format(profile?.publicUserId ?? '000000');
    final resolvedTier = (tierLabel ?? 'Fan').toUpperCase();
    final resolvedFet = fet ?? 0;
    final isLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;

    return Container(
      height: isLargeText ? 420 : 200,
      decoration: BoxDecoration(
        borderRadius: ShapeTokens.cardRadius,
        gradient: ColorTokens.borrowedSurfaceGradient(
          from: ColorTokens.clubSecondary,
          to: ColorTokens.clubAccent.withValues(alpha: 0.6),
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
                Wrap(
                  spacing: SpacingTokens.spacing3,
                  runSpacing: SpacingTokens.spacing2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 210),
                      child: Text(
                        RuntimeBranding.displayHomeTeamName.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TypographyTokens.labelLarge(
                          ColorTokens.onSurface.withValues(alpha: 0.7),
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (paymentStatus == PaymentStatus.pendingVerification)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ColorTokens.warning.withValues(alpha: 0.9),
                          borderRadius: ShapeTokens.chipRadius,
                        ),
                        child: Text(
                          'PENDING VERIFICATION',
                          style: TypographyTokens.labelSmall(
                            ColorTokens.borrowedInk,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      )
                    else
                      Text(
                        'FAN CARD',
                        style: TypographyTokens.labelLarge(
                          ColorTokens.onSurface.withValues(alpha: 0.5),
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                  ],
                ),

                const Spacer(),

                // Alias display
                Text(
                  alias,
                  style: TypographyTokens.displayMedium().copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: SpacingTokens.spacing2),

                Wrap(
                  spacing: SpacingTokens.spacing3,
                  runSpacing: SpacingTokens.spacing2,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                        style: TypographyTokens.labelLarge().copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      resolvedFet <= 0
                          ? 'REVIEW PENDING'
                          : '$resolvedFet ACTIVITY',
                      style: TypographyTokens.titleLarge(
                        ColorTokens.clubAccent,
                      ).copyWith(fontWeight: FontWeight.w700),
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
