import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Auth Gate Modal — bottom sheet that intercepts prediction actions
/// for unauthenticated/unverified users.
///
/// Mirrors the fanafrika store `openAuthGate()` interaction — prompts
/// the user to verify their Fan ID before making predictions.
class AuthGateSheet extends StatelessWidget {
  const AuthGateSheet({super.key, this.onVerify, this.onDismiss});

  /// Called when "Verify Now" is tapped.
  final VoidCallback? onVerify;

  /// Called when the sheet is dismissed without action.
  final VoidCallback? onDismiss;

  /// Show the auth gate bottom sheet from any context.
  static Future<bool?> show(BuildContext context, {VoidCallback? onVerify}) {
    return showAfriBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useUniversalSurface: false,
      builder: (sheetContext) => AuthGateSheet(
        onVerify: onVerify,
        onDismiss: () => sheetContext.pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ShapeTokens.radiusXl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.spacing6,
        SpacingTokens.spacing6,
        SpacingTokens.spacing6,
        SpacingTokens.spacing6 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: SpacingTokens.spacing10,
            height: SpacingTokens.spacing1,
            decoration: BoxDecoration(
              color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing6),

          // Lock icon
          Container(
                width: SpacingTokens.spacing16 + SpacingTokens.spacing2,
                height: SpacingTokens.spacing16 + SpacingTokens.spacing2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColorTokens.warning.withValues(alpha: 0.12),
                  border: BorderTokens.all(
                    color: ColorTokens.warning.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  AfriIcons.privacy,
                  size: SpacingTokens.spacing9,
                  color: ColorTokens.warning,
                ),
              )
              .afriAnimate(context)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 300.ms),

          const SizedBox(height: SpacingTokens.spacing5),

          // Title
          Text(
            context.afriL10n.gameVerifyToPredict,
            style: TypographyTokens.headlineSmall().copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: TypographyTokens.trackingNone,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),

          // Message
          Text(
            context.afriL10n.fanIdVerifyPrompt,
            textAlign: TextAlign.center,
            style: TypographyTokens.bodyMedium(),
          ),

          const SizedBox(height: SpacingTokens.spacing6),

          // Benefits list
          _BenefitRow(
            icon: AfriIcons.statusSuccess,
            title: context.afriL10n.gameMakePicks,
            subtitle: context.afriL10n.gameMakePicksDescription,
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          _BenefitRow(
            icon: AfriIcons.earn,
            title: context.afriL10n.gameEarnPoints,
            subtitle: context.afriL10n.gameEarnPointsDescription,
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          _BenefitRow(
            icon: AfriIcons.leaderboard,
            title: context.afriL10n.gameClimbLeaderboards,
            subtitle: context.afriL10n.gameClimbLeaderboardsDescription,
          ),

          const SizedBox(height: SpacingTokens.spacing6),

          // Verify button
          AfriButton(
                label: context.afriL10n.gameVerifyNow,
                onTap: () {
                  context.pop(true);
                  onVerify?.call();
                },
              )
              .afriAnimate(context, delay: 200.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.06, end: 0, duration: 300.ms),

          const SizedBox(height: SpacingTokens.spacing3),

          // Browse button
          AfriButton(
            label: context.afriL10n.gameJustBrowsing,
            variant: AfriButtonVariant.outline,
            onTap: () {
              context.pop(false);
              onDismiss?.call();
            },
          ),

          const SizedBox(height: SpacingTokens.spacing4),

          Text(
            context.afriL10n.fanIdPrivacyTrust,
            textAlign: TextAlign.center,
            style: TypographyTokens.labelSmall(
              ColorTokens.onSurfaceVariant,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: SpacingTokens.spacing10,
          height: SpacingTokens.spacing10,
          decoration: BoxDecoration(
            color: ColorTokens.primaryContainer.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: SpacingTokens.spacing5,
            color: ColorTokens.primaryContainer,
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TypographyTokens.titleSmall()),
              Text(subtitle, style: TypographyTokens.bodySmall()),
            ],
          ),
        ),
      ],
    );
  }
}
