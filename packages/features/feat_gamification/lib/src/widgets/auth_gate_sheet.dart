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
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorTokens.transparent,
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
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing6),

          // Lock icon
          Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColorTokens.warning.withValues(alpha: 0.12),
                  border: BorderTokens.all(
                    color: ColorTokens.warning.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  AfriIcons.privacy,
                  size: 36,
                  color: ColorTokens.warning,
                ),
              )
              .animate()
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
            'VERIFY TO PREDICT',
            style: TypographyTokens.headlineSmall().copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),

          // Message
          Text(
            'Verify your Fan ID to predict and earn FET.',
            textAlign: TextAlign.center,
            style: TypographyTokens.bodyMedium(),
          ),

          const SizedBox(height: SpacingTokens.spacing6),

          // Benefits list
          const _BenefitRow(
            icon: AfriIcons.statusSuccess,
            title: 'Make Predictions',
            subtitle: 'Predict matches across all leagues',
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          const _BenefitRow(
            icon: AfriIcons.earn,
            title: 'Earn FET',
            subtitle: 'Earn tokens for correct picks',
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          const _BenefitRow(
            icon: AfriIcons.leaderboard,
            title: 'Climb Leaderboards',
            subtitle: 'Compete against friends and fans',
          ),

          const SizedBox(height: SpacingTokens.spacing6),

          // Verify button
          AfriButton(
                label: 'Verify now',
                onTap: () {
                  context.pop(true);
                  onVerify?.call();
                },
              )
              .animate(delay: 200.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.06, end: 0, duration: 300.ms),

          const SizedBox(height: SpacingTokens.spacing3),

          // Browse button
          AfriButton(
            label: 'Just browsing',
            variant: AfriButtonVariant.outline,
            onTap: () {
              context.pop(false);
              onDismiss?.call();
            },
          ),

          const SizedBox(height: SpacingTokens.spacing4),

          Text(
            'VERIFICATION IS ANONYMOUS — NO PERSONAL DATA IS SHARED.',
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ColorTokens.clubAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: ColorTokens.clubAccent),
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
