import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Styled dropdown field with the same borrowed input treatment as
/// [AfriInputField].
class AfriDropdownField<T> extends StatelessWidget {
  const AfriDropdownField({
    super.key,
    required this.items,
    this.initialValue,
    this.label,
    this.hint,
    this.onChanged,
    this.enabled = true,
    this.isExpanded = true,
  });

  final T? initialValue;
  final String? label;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;

    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      items: items,
      onChanged: enabled ? onChanged : null,
      isExpanded: isExpanded,
      style: TypographyTokens.bodyLarge(colors.primaryText),
      dropdownColor: colors.overlaySurface,
      iconEnabledColor: colors.secondaryText,
      iconDisabledColor: colors.tertiaryText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: colors.inputSurface,
        labelStyle: TypographyTokens.bodyMedium(colors.secondaryText),
        hintStyle: TypographyTokens.bodyMedium(colors.tertiaryText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.tapPadding,
          vertical: SpacingTokens.spacing4,
        ),
        border: BorderTokens.input(
          borderRadius: ShapeTokens.inputRadius,
          color: colors.border,
        ),
        enabledBorder: BorderTokens.input(
          borderRadius: ShapeTokens.inputRadius,
          color: colors.border,
        ),
        focusedBorder: BorderTokens.input(
          borderRadius: ShapeTokens.inputRadius,
          color: colors.accent,
          width: BorderTokens.focus,
        ),
      ),
    );
  }
}
