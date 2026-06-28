import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Post-MoMo dial confirmation bottom sheet.
///
/// Mirrors the fanafrika `ContributionConfirmModal.tsx` — shows tier + status,
/// asks "Did you complete the MoMo USSD payment?", and triggers a callback on confirmation.
class ContributionConfirmSheet extends StatefulWidget {
  const ContributionConfirmSheet({
    super.key,
    required this.tierLabel,
    required this.onConfirm,
  });

  final String tierLabel;
  final VoidCallback onConfirm;

  /// Show the sheet from any context.
  static Future<bool?> show(
    BuildContext context, {
    required String tierLabel,
    required VoidCallback onConfirm,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorTokens.transparent,
      builder: (_) =>
          ContributionConfirmSheet(tierLabel: tierLabel, onConfirm: onConfirm),
    );
  }

  @override
  State<ContributionConfirmSheet> createState() =>
      _ContributionConfirmSheetState();
}

class _ContributionConfirmSheetState extends State<ContributionConfirmSheet> {
  bool _isConfirming = false;

  void _handleConfirm() {
    setState(() => _isConfirming = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _isConfirming = false);
        widget.onConfirm();
        context.pop(true);
      }
    });
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

          // Icon
          Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColorTokens.clubAccent.withValues(alpha: 0.14),
                  border: BorderTokens.all(
                    color: ColorTokens.clubAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  AfriIcons.checkGroup,
                  size: 32,
                  color: ColorTokens.clubAccent,
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

          const SizedBox(height: SpacingTokens.spacing4),

          Text(
            'CONFIRM CONTRIBUTION',
            style: TypographyTokens.headlineSmall().copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            'Did you complete the MoMo USSD payment for the ${widget.tierLabel} tier?',
            textAlign: TextAlign.center,
            style: TypographyTokens.bodyMedium(),
          ),

          const SizedBox(height: SpacingTokens.spacing5),

          // Tier + Status summary
          GlassCard(
            animate: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECTED TIER',
                      style: TypographyTokens.labelSmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      widget.tierLabel.toUpperCase(),
                      style: TypographyTokens.titleMedium().copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing3,
                    vertical: SpacingTokens.spacing2,
                  ),
                  decoration: BoxDecoration(
                    color: ColorTokens.clubAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'PENDING VERIFICATION',
                    style: TypographyTokens.labelSmall(
                      ColorTokens.clubAccent,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: SpacingTokens.spacing5),

          // Buttons
          Row(
            children: [
              Expanded(
                child: AfriButton(
                  label: 'Not yet',
                  variant: AfriButtonVariant.outline,
                  onTap: () => context.pop(false),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: AfriButton(
                  label: _isConfirming ? 'Confirming…' : 'Yes, I paid',
                  onTap: _handleConfirm,
                  isLoading: _isConfirming,
                  enabled: !_isConfirming,
                ),
              ),
            ],
          ),

          const SizedBox(height: SpacingTokens.spacing4),

          Text(
            'CONTRIBUTIONS ARE VERIFIED ANONYMOUSLY VIA FAN ID.',
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
