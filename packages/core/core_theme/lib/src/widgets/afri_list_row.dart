import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';
import 'afri_surface_card.dart';

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
      builder: (context, state) => AfriSurfaceCard(
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
                borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
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
                  AfriIcons.chevronRight,
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

/// Borrowed-system wrapper for compact text-first rows.
class AfriListTile extends StatelessWidget {
  const AfriListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.contentPadding,
    this.dense,
    this.enabled = true,
    this.selected = false,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final bool enabled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: leading,
        title: title == null
            ? null
            : DefaultTextStyle.merge(
                style: TypographyTokens.titleSmall(),
                child: title!,
              ),
        subtitle: subtitle == null
            ? null
            : DefaultTextStyle.merge(
                style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
                child: subtitle!,
              ),
        trailing: trailing,
        onTap: onTap,
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing4),
        dense: dense,
        enabled: enabled,
        selected: selected,
        textColor: ColorTokens.onSurface,
        iconColor: ColorTokens.onSurfaceVariant,
        selectedColor: ColorTokens.primaryContainer,
        titleTextStyle: TypographyTokens.titleSmall(),
        subtitleTextStyle: TypographyTokens.bodySmall(
          ColorTokens.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
        ),
        tileColor: ColorTokens.transparent,
        selectedTileColor: ColorTokens.primaryTint(0.12),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Borrowed-system wrapper for settings and permission toggles.
class AfriSwitchListTile extends StatelessWidget {
  const AfriSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.secondary,
    this.activeThumbColor,
    this.contentPadding,
    this.dense,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final Widget? secondary;
  final Color? activeThumbColor;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        activeThumbColor: activeThumbColor ?? ColorTokens.primaryContainer,
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing2),
        dense: dense,
        tileColor: ColorTokens.transparent,
        selectedTileColor: ColorTokens.primaryTint(0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
        ),
      ),
    );
  }
}
