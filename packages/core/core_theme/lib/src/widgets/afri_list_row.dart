import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/responsive_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

/// A single rounded tonal group, shared by settings and task menus.
/// Rows inside it keep one continuous surface without nested cards.
class AfriListGroup extends StatelessWidget {
  const AfriListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: ShapeTokens.cardRadius,
    child: ColoredBox(
      color: context.afriSemanticColors.cardSurface,
      child: _AfriListGroupScope(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );
}

class _AfriListGroupScope extends InheritedWidget {
  const _AfriListGroupScope({required super.child});

  @override
  bool updateShouldNotify(_AfriListGroupScope oldWidget) => false;
}

/// Native icon-led row: 56 minimum height, plain icon, normal-weight title.
/// Additional lines and enlarged text expand naturally beyond that minimum.
class AfriListRow extends StatelessWidget {
  const AfriListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final grouped =
        context.dependOnInheritedWidgetOfExactType<_AfriListGroupScope>() !=
        null;
    final foreground = enabled
        ? colors.primaryText
        : ColorTokens.accessibleDisabledColor(colors.secondaryText);
    final secondary = enabled
        ? colors.secondaryText
        : ColorTokens.accessibleDisabledColor(colors.secondaryText);
    final textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TypographyTokens.bodyLarge(
            foreground,
          ).copyWith(height: TypographyTokens.lineHeightRow),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: SpacingTokens.spacing1),
          Text(subtitle!, style: TypographyTokens.bodySmall(secondary)),
        ],
      ],
    );
    final leadingIcon = Icon(
      icon,
      size: AfriComponentSizes.listIcon,
      color: foreground,
    );
    final trailingControl =
        trailing ??
        (onTap == null
            ? null
            : Icon(
                AfriIcons.chevronRight,
                size: AfriComponentSizes.listChevron,
                color: secondary,
              ));
    return AfriPressFeedback(
      enabled: enabled,
      onTap: onTap,
      semanticsLabel: [title, if (subtitle != null) subtitle!].join(', '),
      tooltip: title,
      // A custom trailing control may have its own accessible action.
      excludeChildSemantics: trailing == null,
      builder: (context, state) => Container(
        constraints: const BoxConstraints(
          minHeight: AfriComponentSizes.listRowHeight,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing4,
          vertical: SpacingTokens.spacing3,
        ),
        decoration: BoxDecoration(
          color: state.isPressed
              ? colors.cardSurfaceStrong
              : colors.cardSurface,
          borderRadius: grouped ? null : ShapeTokens.cardRadius,
          border: state.isFocused || MediaQuery.highContrastOf(context)
              ? BorderTokens.all(
                  color: colors.primaryText,
                  width: context.afriDesignTokens.focusRingWidth,
                )
              : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Keep the selected row anatomy at ordinary text sizes. At narrow
            // enlarged text, give labels the whole row width so icon/chevron
            // gutters do not split words. This is an accessibility adaptation;
            // current native reference captures do not show enlarged text.
            final expandedLabels =
                constraints.maxWidth < AfriResponsive.mobileContentMax &&
                MediaQuery.textScalerOf(context).scale(1) >= 1.5;
            if (expandedLabels) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      leadingIcon,
                      if (trailingControl != null) ...[
                        const Spacer(),
                        trailingControl,
                      ],
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  textContent,
                ],
              );
            }
            return Row(
              children: [
                leadingIcon,
                const SizedBox(width: SpacingTokens.spacing4),
                Expanded(child: textContent),
                if (trailingControl != null) ...[
                  const SizedBox(width: SpacingTokens.spacing3),
                  trailingControl,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Universal wrapper for compact text-first rows.
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

/// Universal wrapper for settings and permission toggles.
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
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.5) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AfriResponsive.mobileContentMax) {
            return _standardTile(context);
          }
          return MergeSemantics(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onChanged == null ? null : () => onChanged!(!value),
                borderRadius: ShapeTokens.cardRadius,
                child: Padding(
                  padding:
                      contentPadding ??
                      const EdgeInsets.all(SpacingTokens.spacing2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (secondary != null) ...[
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: secondary!,
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                      ],
                      DefaultTextStyle.merge(
                        style: TypographyTokens.bodyLarge(),
                        child: title,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: SpacingTokens.spacing1),
                        DefaultTextStyle.merge(
                          style: TypographyTokens.bodySmall(
                            ColorTokens.onSurfaceVariant,
                          ),
                          child: subtitle!,
                        ),
                      ],
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: ExcludeFocus(
                          child: Switch.adaptive(
                            value: value,
                            onChanged: onChanged,
                            activeThumbColor:
                                activeThumbColor ?? ColorTokens.switchThumb,
                            activeTrackColor: context.afriSemanticColors.accent,
                            inactiveThumbColor: ColorTokens.switchThumb,
                            inactiveTrackColor: ColorTokens.switchInactiveTrack,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
    return _standardTile(context);
  }

  Widget _standardTile(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        activeThumbColor: activeThumbColor ?? ColorTokens.switchThumb,
        activeTrackColor: context.afriSemanticColors.accent,
        inactiveThumbColor: ColorTokens.switchThumb,
        inactiveTrackColor: ColorTokens.switchInactiveTrack,
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
