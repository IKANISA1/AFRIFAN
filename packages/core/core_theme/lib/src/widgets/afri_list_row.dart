import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';
import 'clay_card.dart';

/// Reusable icon-led list row for settings and menu-style screens.
class AfriListRow extends StatelessWidget {
  const AfriListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      semanticsLabel: title,
      tooltip: title,
      excludeChildSemantics: true,
      builder: (context, state) => ClayCard(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing4,
          vertical: SpacingTokens.spacing4,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ColorTokens.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: ColorTokens.onSurface),
            ),
            const SizedBox(width: SpacingTokens.spacing4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TypographyTokens.titleMedium()),
                  if (subtitle != null) ...[
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      subtitle!,
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: state.isFocused
                      ? ColorTokens.primaryContainer
                      : ColorTokens.onSurfaceVariant,
                ),
          ],
        ),
      ),
    );
  }
}
