import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_surface_card.dart';

enum AfriStateBannerTone { neutral, brand, info, success, warning, danger }

/// Compact inline status treatment for non-fatal route and section states.
///
/// Use for degraded data, pending review, disabled features, permission
/// education, and other states where the user can continue.
class AfriStateBanner extends StatelessWidget {
  const AfriStateBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.tone = AfriStateBannerTone.neutral,
    this.compact = false,
    this.semanticsLabel,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final AfriStateBannerTone tone;
  final bool compact;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = _AfriStateBannerColors.fromTone(tone);
    final resolvedSubtitle = subtitle?.trim();
    final showSubtitle =
        resolvedSubtitle != null && resolvedSubtitle.isNotEmpty;
    final toneLabel = switch (tone) {
      AfriStateBannerTone.neutral => 'Status',
      AfriStateBannerTone.brand => 'Highlighted',
      AfriStateBannerTone.info => 'Information',
      AfriStateBannerTone.success => 'Success',
      AfriStateBannerTone.warning => 'Warning',
      AfriStateBannerTone.danger => 'Danger',
    };
    final contentLabel = showSubtitle ? '$title. $resolvedSubtitle' : title;
    final label = semanticsLabel ?? '$toneLabel status: $contentLabel';

    final card = AfriSurfaceCard(
      onTap: onTap,
      semanticsLabel: onTap == null ? null : label,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? SpacingTokens.spacing3 : SpacingTokens.spacing4,
        vertical: compact ? SpacingTokens.spacing3 : SpacingTokens.spacing4,
      ),
      backgroundColor: ColorTokens.surfaceContainerLow.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(ShapeTokens.radiusXl),
      child: Row(
        children: [
          Container(
            width: compact
                ? AfriComponentSizes.stateBannerCompact
                : AfriComponentSizes.stateBannerRegular,
            height: compact
                ? AfriComponentSizes.stateBannerCompact
                : AfriComponentSizes.stateBannerRegular,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
            ),
            child: Icon(
              icon,
              size: compact ? AfriIcons.sizeInline : SizeTokens.iconMd,
              color: colors.foreground,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TypographyTokens.titleSmall(
                    ColorTokens.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                if (showSubtitle) ...[
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    resolvedSubtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TypographyTokens.bodySmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: SpacingTokens.spacing3),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: SpacingTokens.spacing2),
            Icon(
              AfriIcons.chevronRight,
              size: AfriIcons.sizeInline,
              color: colors.foreground,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return card;
    }

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      child: card,
    );
  }
}

class _AfriStateBannerColors {
  const _AfriStateBannerColors({
    required this.foreground,
    required this.background,
  });

  final Color foreground;
  final Color background;

  static _AfriStateBannerColors fromTone(AfriStateBannerTone tone) {
    final foreground = switch (tone) {
      AfriStateBannerTone.neutral => ColorTokens.onSurfaceVariant,
      AfriStateBannerTone.brand => ColorTokens.primaryContainer,
      AfriStateBannerTone.info => ColorTokens.info,
      AfriStateBannerTone.success => ColorTokens.success,
      AfriStateBannerTone.warning => ColorTokens.warning,
      AfriStateBannerTone.danger => ColorTokens.error,
    };

    return _AfriStateBannerColors(
      foreground: foreground,
      background: foreground.withValues(alpha: 0.14),
    );
  }
}
