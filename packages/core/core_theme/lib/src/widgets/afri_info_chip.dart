import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

/// Lightweight inline metadata chip — no border, just tinted background + text.
///
/// For compact contextual info: "LIVE 3", "125 FET", "TIER GOLD", etc.
/// Lighter than [AfriStatusChip] which has a border and is semantically
/// for status states.
///
/// ```dart
/// AfriInfoChip(label: 'LIVE 3', color: ColorTokens.success)
/// AfriInfoChip(label: '125 FET', color: ColorTokens.primaryContainer)
/// ```
class AfriInfoChip extends StatelessWidget {
  const AfriInfoChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? ColorTokens.primaryContainer;
    // The tint conveys status. Text must remain readable on the route canvas
    // beneath the translucent chip, including the membership gradient.
    final foreground = context.afriSemanticColors.primaryText;

    final child = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: AfriComponentSizes.infoChipVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.14),
        borderRadius: ShapeTokens.buttonRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: SizeTokens.iconXxs, color: foreground),
            const SizedBox(width: SpacingTokens.spacing1),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TypographyTokens.labelSmall(
                foreground,
              ).copyWith(height: TypographyTokens.lineHeightSolid),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return AfriPressFeedback(
        onTap: onTap,
        haptic: false,
        semanticsLabel: label,
        child: child,
      );
    }

    return child;
  }
}
