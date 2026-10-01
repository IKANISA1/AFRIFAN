import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
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
    final accent = selectedColor ?? ColorTokens.primaryContainer;
    final foreground = onSelected == null
        ? ColorTokens.contrastForeground(
            disabledColor ?? ColorTokens.surfaceContainer,
          )
        : selected
        ? ColorTokens.contrastForeground(accent)
        : ColorTokens.onSurfaceVariant;

    if (onSelected == null) {
      // Material ChoiceChip fades the entire disabled label to 38%, even
      // when a readable foreground is supplied. Render the same passive chip
      // without that paint opacity and expose an actually disabled control.
      final disabledSurface = disabledColor ?? ColorTokens.surfaceContainer;
      return ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: SizeTokens.touchTargetMin,
          minHeight: SizeTokens.touchTargetMin,
        ),
        child: MergeSemantics(
          child: Semantics(
            button: true,
            enabled: false,
            selected: selected,
            child: ExcludeFocus(
              child: RawChip(
                avatar: avatar,
                label: label,
                selected: selected,
                tapEnabled: false,
                tooltip: tooltip,
                labelStyle:
                    labelStyle ?? TypographyTokens.labelMedium(foreground),
                backgroundColor: disabledSurface,
                selectedColor: disabledSurface,
                side:
                    side ??
                    BorderTokens.side(
                      color: selected ? accent : ColorTokens.ghostBorder,
                      opacity: selected ? 0.42 : 1,
                    ),
                shape:
                    shape ??
                    RoundedRectangleBorder(
                      borderRadius: ShapeTokens.chipRadius,
                    ),
                padding:
                    padding ??
                    const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing1,
                    ),
                labelPadding:
                    labelPadding ??
                    const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing2,
                    ),
                visualDensity: visualDensity ?? VisualDensity.compact,
                materialTapTargetSize:
                    materialTapTargetSize ?? MaterialTapTargetSize.padded,
                showCheckmark: showCheckmark ?? false,
                checkmarkColor: checkmarkColor ?? foreground,
              ),
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: SizeTokens.touchTargetMin,
        minHeight: SizeTokens.touchTargetMin,
      ),
      child: ChoiceChip(
        avatar: avatar,
        label: label,
        selected: selected,
        onSelected: onSelected,
        tooltip: tooltip,
        labelStyle: labelStyle ?? TypographyTokens.labelMedium(foreground),
        backgroundColor: backgroundColor ?? ColorTokens.surfaceContainerLow,
        selectedColor: accent,
        disabledColor: disabledColor ?? ColorTokens.surfaceContainer,
        side:
            side ??
            BorderTokens.side(
              color: selected ? accent : ColorTokens.ghostBorder,
              opacity: selected ? 0.42 : 1,
            ),
        shape:
            shape ??
            RoundedRectangleBorder(borderRadius: ShapeTokens.chipRadius),
        padding:
            padding ??
            const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing1),
        labelPadding:
            labelPadding ??
            const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing2),
        visualDensity: visualDensity ?? VisualDensity.compact,
        materialTapTargetSize:
            materialTapTargetSize ?? MaterialTapTargetSize.padded,
        showCheckmark: showCheckmark ?? false,
        checkmarkColor: checkmarkColor ?? foreground,
      ),
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
