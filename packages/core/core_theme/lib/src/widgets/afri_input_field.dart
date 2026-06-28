import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Styled text input with consistent surface, border, and label treatment.
///
/// Built on [TextField] with preconfigured decoration matching theme tokens.
/// Replaces raw `TextField` usage across the app.
///
/// ```dart
/// AfriInputField(
///   label: 'Amount',
///   controller: _amountController,
///   keyboardType: TextInputType.number,
///   prefixText: 'FET ',
/// )
/// ```
class AfriInputField extends StatelessWidget {
  const AfriInputField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.prefixText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.maxLength,
    this.maxLengthEnforcement,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? prefixText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      readOnly: readOnly,
      enabled: enabled,
      obscureText: obscureText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: textInputAction,
      maxLength: maxLength,
      maxLengthEnforcement:
          maxLengthEnforcement ?? MaxLengthEnforcement.enforced,
      buildCounter: maxLength != null
          ? (
              context, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => null
          : null,
      style: TypographyTokens.bodyLarge(colors.primaryText),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: colors.secondaryText)
            : null,
        suffixIcon: suffixIcon,
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
