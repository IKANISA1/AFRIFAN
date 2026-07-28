import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';
import 'afri_surface_card.dart';

/// Compact icon-led action tile for grids, shortcuts, and quick-action surfaces.
///
/// Replaces ad-hoc `_QuickActionTile`, `_QuickRoutes` chips, and similar
/// one-off action buttons.
///
/// ```dart
/// AfriActionRow(
///   icon: AfriIcons.predict,
///   label: 'Predict',
///   onTap: () => context.push('/fanzone/fixtures'),
/// )
/// ```
class AfriActionRow extends StatelessWidget {
  const AfriActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.badge,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  /// Optional badge count. Shows a small indicator when > 0.
  final int? badge;

  /// Override accent color for the icon background.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? ColorTokens.primaryContainer;

    return AfriPressFeedback(
      onTap: onTap,
      enabled: enabled,
      semanticsLabel: label,
      builder: (context, state) => Opacity(
        opacity: enabled ? 1 : 0.48,
        child: AfriSurfaceCard(
          enabled: enabled,
          padding: const EdgeInsets.all(SpacingTokens.tapPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: AfriMotion.surfaceResponse,
                    width: AfriComponentSizes.actionTileLeading,
                    height: AfriComponentSizes.actionTileLeading,
                    decoration: BoxDecoration(
                      color: accent.withValues(
                        alpha: state.isPressed ? 0.22 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: SizeTokens.iconSm, color: accent),
                  ),
                  if (badge != null && badge! > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: AfriComponentSizes.actionBadge,
                          minHeight: AfriComponentSizes.actionBadge,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.spacing1,
                        ),
                        decoration: BoxDecoration(
                          color: ColorTokens.error,
                          borderRadius: ShapeTokens.buttonRadius,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badge! > 99 ? '99+' : '$badge',
                          style: TypographyTokens.badgeLabel(
                            ColorTokens.onDark,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              SizedBox(
                height: MediaQuery.textScalerOf(
                  context,
                ).scale(AfriComponentSizes.actionLabelHeight),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TypographyTokens.labelMedium().copyWith(
                      fontWeight: FontWeight.w900,
                      height: TypographyTokens.lineHeightDense,
                      letterSpacing: TypographyTokens.trackingNone,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
