import '../tokens/border_tokens.dart';
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
        padding: const EdgeInsets.all(SpacingTokens.spacing3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ColorTokens.surfaceBright.withValues(alpha: 0.78),
              ColorTokens.surfaceContainerHigh.withValues(alpha: 0.78),
            ],
          ),
          shape: BoxShape.circle,
          border: state.isFocused
              ? BorderTokens.focusAll(
                  color: ColorTokens.primaryContainer,
                  opacity: 0.45,
                  width: BorderTokens.standard,
                )
              : BorderTokens.ghost(),
          boxShadow: state.isPressed
              ? [
                  BoxShadow(
                    color: ColorTokens.ambientShadow.withValues(alpha: 0.18),
                    blurRadius: 14,
                    spreadRadius: -10,
                    offset: const Offset(4, 4),
                    blurStyle: BlurStyle.inner,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.10),
                    blurRadius: 14,
                    spreadRadius: -10,
                    offset: const Offset(-6, -6),
                    blurStyle: BlurStyle.inner,
                  ),
                  BoxShadow(
                    color: ColorTokens.ambientShadow.withValues(alpha: 0.20),
                    blurRadius: 24,
                    spreadRadius: -8,
                    offset: const Offset(0, 10),
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
