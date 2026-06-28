import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
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
    this.badge,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Optional badge count. Shows a small indicator when > 0.
  final int? badge;

  /// Override accent color for the icon background.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? ColorTokens.primaryContainer;

    return AfriPressFeedback(
      onTap: onTap,
      semanticsLabel: label,
      builder: (context, state) => AfriSurfaceCard(
        padding: const EdgeInsets.all(SpacingTokens.tapPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(
                      alpha: state.isPressed ? 0.22 : 0.14,
                    ),
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: accent),
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: ColorTokens.error,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
                        style: TypographyTokens.labelSmall(
                          Colors.white,
                        ).copyWith(fontSize: 10, height: 1.0),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypographyTokens.titleSmall().copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
