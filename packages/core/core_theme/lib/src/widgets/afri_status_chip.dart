import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
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
    final toneLabel = switch (tone) {
      AfriStatusTone.neutral => 'Status',
      AfriStatusTone.info => 'Information',
      AfriStatusTone.success => 'Success',
      AfriStatusTone.warning => 'Warning',
      AfriStatusTone.error => 'Error',
      AfriStatusTone.live => 'Live',
    };

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$toneLabel status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing3,
          vertical: AfriComponentSizes.compactVerticalPadding,
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
              Icon(icon, size: SizeTokens.iconXxs, color: color),
              const SizedBox(width: SpacingTokens.spacing1),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypographyTokens.labelSmall(
                  color,
                ).copyWith(height: TypographyTokens.lineHeightSolid),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
