import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions.dart';
import '../tokens/afri_semantic_colors.dart';
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
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.minLines,
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
    this.style,
    this.helperText,
    this.contentPadding,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? prefixText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final int maxLines;
  final int? minLines;
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
  final TextStyle? style;
  final String? helperText;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      maxLines: maxLines,
      minLines: minLines,
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
      style: style ?? TypographyTokens.bodyLarge(colors.primaryText),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixText: prefixText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: colors.secondaryText)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: colors.inputSurface,
        labelStyle: TypographyTokens.bodyMedium(colors.secondaryText),
        hintStyle: TypographyTokens.bodyMedium(colors.tertiaryText),
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(
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

/// Form-backed universal text input.
class AfriTextFormField extends StatelessWidget {
  const AfriTextFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.prefixText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.maxLengthEnforcement,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    this.style,
    this.helperText,
    this.contentPadding,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hint;
  final String? prefixText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final String? helperText;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;

    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      enabled: enabled,
      obscureText: obscureText,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
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
      style: style ?? TypographyTokens.bodyLarge(colors.primaryText),
      decoration: _universalInputDecoration(
        colors: colors,
        label: label,
        hint: hint,
        helperText: helperText,
        prefixText: prefixText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: contentPadding,
      ),
    );
  }
}

InputDecoration _universalInputDecoration({
  required AfriSemanticColors colors,
  required String? label,
  required String? hint,
  required String? helperText,
  required String? prefixText,
  required IconData? prefixIcon,
  required Widget? suffixIcon,
  required EdgeInsetsGeometry? contentPadding,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helperText,
    prefixText: prefixText,
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, size: 20, color: colors.secondaryText)
        : null,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: colors.inputSurface,
    labelStyle: TypographyTokens.bodyMedium(colors.secondaryText),
    hintStyle: TypographyTokens.bodyMedium(colors.tertiaryText),
    contentPadding:
        contentPadding ??
        const EdgeInsets.symmetric(
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
  );
}
