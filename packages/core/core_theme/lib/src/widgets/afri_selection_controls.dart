import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

class AfriCheckbox extends StatelessWidget {
  const AfriCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.errorText,
    this.tristate = false,
    super.key,
  });

  final String label;
  final String? subtitle;
  final String? errorText;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      container: true,
      excludeSemantics: true,
      checked: value,
      enabled: enabled,
      label: _semanticsLabel,
      onTap: enabled ? () => onChanged!(_nextValue) : null,
      child: Material(
        type: MaterialType.transparency,
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: value,
          tristate: tristate,
          onChanged: onChanged,
          title: Text(label, style: TypographyTokens.bodyLarge()),
          subtitle: _supportingText,
        ),
      ),
    );
  }

  bool? get _nextValue {
    if (!tristate) return value != true;
    return switch (value) {
      false => true,
      true => null,
      null => false,
    };
  }

  String get _semanticsLabel {
    final parts = <String>[label];
    if (subtitle?.trim().isNotEmpty == true) parts.add(subtitle!.trim());
    if (errorText?.trim().isNotEmpty == true) {
      parts.add('Error: ${errorText!.trim()}');
    }
    return parts.join('. ');
  }

  Widget? get _supportingText {
    final error = errorText?.trim();
    final subtitleText = subtitle?.trim();
    if (error?.isNotEmpty == true) {
      return Padding(
        padding: const EdgeInsets.only(top: SpacingTokens.spacing1),
        child: Text(
          error!,
          style: TypographyTokens.bodySmall(ColorTokens.error),
        ),
      );
    }
    if (subtitleText?.isNotEmpty == true) {
      return Text(subtitleText!, style: TypographyTokens.bodySmall());
    }
    return null;
  }
}

class AfriRadio<T> extends StatelessWidget {
  const AfriRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.subtitle,
    this.errorText,
    super.key,
  });

  final String label;
  final String? subtitle;
  final String? errorText;
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final enabled = onChanged != null;
    final supporting = errorText?.trim().isNotEmpty == true
        ? errorText!.trim()
        : subtitle?.trim();
    return Semantics(
      container: true,
      excludeSemantics: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      checked: selected,
      enabled: enabled,
      label: [
        label,
        if (supporting?.isNotEmpty == true)
          errorText?.trim().isNotEmpty == true
              ? 'Error: $supporting'
              : supporting!,
      ].join('. '),
      onTap: enabled ? () => onChanged!(value) : null,
      child: Material(
        type: MaterialType.transparency,
        child: RadioGroup<T>(
          groupValue: groupValue,
          onChanged: onChanged ?? (_) {},
          child: RadioListTile<T>(
            contentPadding: EdgeInsets.zero,
            value: value,
            enabled: enabled,
            title: Text(label, style: TypographyTokens.bodyLarge()),
            subtitle: supporting?.isNotEmpty == true
                ? Text(
                    supporting!,
                    style: TypographyTokens.bodySmall(
                      errorText?.trim().isNotEmpty == true
                          ? ColorTokens.error
                          : null,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
