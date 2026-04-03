import 'package:core_theme/src/tokens/color_tokens.dart';
import 'package:core_theme/src/tokens/spacing_tokens.dart';
import 'package:core_theme/src/widgets/afri_press_feedback.dart';
import 'package:flutter/material.dart';

/// A universal icon button with the "Soft Liquid Glass" claymorphic feel.
class AfriIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const AfriIconButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      builder: (context, state) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(SpacingTokens.spacing2),
        decoration: BoxDecoration(
          color: ColorTokens.surface,
          shape: BoxShape.circle,
          border: Border.all(color: ColorTokens.ghostBorder),
          boxShadow: state.isPressed
              ? []
              : [
                  BoxShadow(
                    color: ColorTokens.onSurface.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Icon(
          icon,
          color: onTap == null
              ? ColorTokens.onSurfaceVariant
              : ColorTokens.onSurface,
        ),
      ),
    );
  }
}
