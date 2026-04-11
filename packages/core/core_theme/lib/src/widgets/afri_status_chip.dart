import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

enum AfriStatusTone { neutral, info, success, warning, error, live }

/// Compact status chip for inline state, filters, and micro metadata.
class AfriStatusChip extends StatelessWidget {
  const AfriStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = AfriStatusTone.neutral,
  });

  final String label;
  final IconData? icon;
  final AfriStatusTone tone;

  Color get _color => switch (tone) {
    AfriStatusTone.neutral => ColorTokens.onSurfaceVariant,
    AfriStatusTone.info => ColorTokens.info,
    AfriStatusTone.success => ColorTokens.success,
    AfriStatusTone.warning => ColorTokens.warning,
    AfriStatusTone.error => ColorTokens.error,
    AfriStatusTone.live => ColorTokens.primaryContainer,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
        border: BorderTokens.all(color: color, width: BorderTokens.standard),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: SpacingTokens.spacing1),
          ],
          Text(
            label,
            style: TypographyTokens.labelSmall(color).copyWith(height: 1.0),
          ),
        ],
      ),
    );
  }
}
