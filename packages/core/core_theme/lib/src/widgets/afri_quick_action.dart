import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

/// Circular, icon-led command used for the first quick-action group.
///
/// Labels remain outside the circular control so the command target stays
/// stable as text scaling changes. Use at most four in one primary group.
class AfriQuickAction extends StatelessWidget {
  const AfriQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.tooltip,
    this.semanticsHint,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final String? tooltip;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;

    return AfriPressFeedback(
      onTap: onTap,
      enabled: enabled,
      tooltip: tooltip ?? label,
      semanticsLabel: label,
      semanticsHint: semanticsHint,
      excludeChildSemantics: true,
      builder: (context, state) => Opacity(
        opacity: enabled ? 1 : 0.48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              key: const ValueKey<String>('afri-quick-action-circle'),
              duration: AfriMotion.resolve(context, AfriMotion.quick),
              width: AfriComponentSizes.quickActionDiameter,
              height: AfriComponentSizes.quickActionDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state.isPressed
                    ? colors.cardSurfaceStrong
                    : ColorTokens.onSurface.withValues(alpha: 0.16),
                border: state.isFocused
                    ? BorderTokens.focusAll(
                        color: ColorTokens.primaryContainer,
                        width: context.afriDesignTokens.focusRingWidth,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: AfriComponentSizes.quickActionIcon,
                color: state.isFocused
                    ? ColorTokens.primaryContainer
                    : colors.primaryText,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TypographyTokens.labelMedium().copyWith(
                fontWeight: FontWeight.w500,
                height: TypographyTokens.lineHeightTight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
