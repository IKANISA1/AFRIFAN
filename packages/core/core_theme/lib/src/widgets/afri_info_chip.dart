import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Lightweight inline metadata chip — no border, just tinted background + text.
///
/// For compact contextual info: "LIVE 3", "125 FET", "TIER GOLD", etc.
/// Lighter than [AfriStatusChip] which has a border and is semantically
/// for status states.
///
/// ```dart
/// AfriInfoChip(label: 'LIVE 3', color: ColorTokens.success)
/// AfriInfoChip(label: '125 FET', color: ColorTokens.clubAccent)
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

    final child = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: chipColor),
            const SizedBox(width: SpacingTokens.spacing1),
          ],
          Text(
            label,
            style: TypographyTokens.labelSmall(chipColor)
                .copyWith(height: 1.0),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }

    return child;
  }
}
