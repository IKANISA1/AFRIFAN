import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Universal choice chip for filters and compact option groups.
class AfriChoiceChip extends StatelessWidget {
  const AfriChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.avatar,
    this.tooltip,
    this.labelStyle,
    this.backgroundColor,
    this.selectedColor,
    this.disabledColor,
    this.side,
    this.shape,
    this.padding,
    this.labelPadding,
    this.visualDensity,
    this.materialTapTargetSize,
    this.showCheckmark,
    this.checkmarkColor,
  });

  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;
  final String? tooltip;
  final TextStyle? labelStyle;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? disabledColor;
  final BorderSide? side;
  final OutlinedBorder? shape;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? labelPadding;
  final VisualDensity? visualDensity;
  final MaterialTapTargetSize? materialTapTargetSize;
  final bool? showCheckmark;
  final Color? checkmarkColor;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? ColorTokens.onDark
        : ColorTokens.onSurfaceVariant;
    final accent = ColorTokens.primaryContainer;

    return ChoiceChip(
      avatar: avatar,
      label: label,
      selected: selected,
      onSelected: onSelected,
      tooltip: tooltip,
      labelStyle: labelStyle ?? TypographyTokens.labelMedium(foreground),
      backgroundColor: backgroundColor ?? ColorTokens.surfaceContainerLow,
      selectedColor: selectedColor ?? accent,
      disabledColor: disabledColor ?? ColorTokens.surfaceContainer,
      side:
          side ??
          BorderTokens.side(
            color: selected ? accent : ColorTokens.ghostBorder,
            opacity: selected ? 0.42 : 1,
          ),
      shape:
          shape ?? RoundedRectangleBorder(borderRadius: ShapeTokens.chipRadius),
      padding:
          padding ??
          const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing1),
      labelPadding:
          labelPadding ??
          const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing2),
      visualDensity: visualDensity ?? VisualDensity.compact,
      materialTapTargetSize:
          materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
      showCheckmark: showCheckmark ?? false,
      checkmarkColor: checkmarkColor ?? foreground,
    );
  }
}

/// Static universal chip for status and compact metadata.
class AfriChip extends StatelessWidget {
  const AfriChip({
    super.key,
    required this.label,
    this.avatar,
    this.labelStyle,
    this.backgroundColor,
    this.side,
    this.shape,
    this.padding,
    this.labelPadding,
    this.visualDensity,
    this.materialTapTargetSize,
  });

  final Widget label;
  final Widget? avatar;
  final TextStyle? labelStyle;
  final Color? backgroundColor;
  final BorderSide? side;
  final OutlinedBorder? shape;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? labelPadding;
  final VisualDensity? visualDensity;
  final MaterialTapTargetSize? materialTapTargetSize;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: avatar,
      label: label,
      labelStyle:
          labelStyle ?? TypographyTokens.labelMedium(ColorTokens.onSurface),
      backgroundColor: backgroundColor ?? ColorTokens.surfaceContainerLow,
      side: side ?? BorderTokens.side(color: ColorTokens.ghostBorder),
      shape:
          shape ?? RoundedRectangleBorder(borderRadius: ShapeTokens.chipRadius),
      padding:
          padding ??
          const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing1),
      labelPadding:
          labelPadding ??
          const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing2),
      visualDensity: visualDensity ?? VisualDensity.compact,
      materialTapTargetSize:
          materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
    );
  }
}
