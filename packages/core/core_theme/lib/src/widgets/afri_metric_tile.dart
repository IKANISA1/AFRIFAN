import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'clay_card.dart';

/// Compact metric tile for summary values.
class AfriMetricTile extends StatelessWidget {
  const AfriMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.meta,
    this.icon,
    this.accentColor,
  });

  final String label;
  final String value;
  final String? meta;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? ColorTokens.primaryContainer;

    return ClayCard(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: SpacingTokens.spacing2),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.headlineSmall(),
          ),
          if (meta != null) ...[
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              meta!,
              style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
