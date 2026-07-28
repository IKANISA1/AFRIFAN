import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_surface_card.dart';

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
    final rawAccent = accentColor ?? ColorTokens.primaryContainer;
    final accent = ColorTokens.accessibleMetricColor(rawAccent);
    final supporting = ColorTokens.accessibleMetricColor(
      ColorTokens.onSurfaceVariant,
    );

    return AfriSurfaceCard(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: SizeTokens.iconBase, color: accent),
                const SizedBox(width: SpacingTokens.spacing2),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TypographyTokens.labelSmall(supporting),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.headlineSmall(accent),
          ),
          if (meta != null) ...[
            const SizedBox(height: SpacingTokens.spacing1),
            Text(meta!, style: TypographyTokens.bodySmall(supporting)),
          ],
        ],
      ),
    );
  }
}
