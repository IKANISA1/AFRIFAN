import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/icon_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_button.dart';
import 'afri_icon_button.dart';
import 'afri_input_field.dart';
import 'afri_press_feedback.dart';
import 'afri_state_banner.dart';

/// Governed numeric input with bounded sign and decimal behavior.
class AfriNumberInputField extends StatelessWidget {
  const AfriNumberInputField({
    required this.controller,
    this.label = 'Number',
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.allowDecimal = false,
    this.allowNegative = false,
    this.decimalDigits = 2,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final bool allowDecimal;
  final bool allowNegative;
  final int decimalDigits;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AfriInputField(
      controller: controller,
      label: label,
      helperText: helperText,
      errorText: errorText,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(
        decimal: allowDecimal,
        signed: allowNegative,
      ),
      inputFormatters: [
        AfriNumericInputFormatter(
          allowDecimal: allowDecimal,
          allowNegative: allowNegative,
          decimalDigits: decimalDigits,
        ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Currency-aware input that keeps the currency outside the editable value.
class AfriMoneyInputField extends StatelessWidget {
  const AfriMoneyInputField({
    required this.controller,
    required this.currencySymbol,
    this.label = 'Amount',
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.decimalDigits = 0,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String currencySymbol;
  final String label;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final int decimalDigits;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AfriInputField(
      controller: controller,
      label: label,
      prefixText: '${currencySymbol.trim()} ',
      helperText: helperText,
      errorText: errorText,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: decimalDigits > 0),
      inputFormatters: [
        AfriNumericInputFormatter(
          allowDecimal: decimalDigits > 0,
          decimalDigits: decimalDigits,
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class AfriPhoneInputField extends StatelessWidget {
  const AfriPhoneInputField({
    required this.controller,
    this.label = 'Phone number',
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AfriInputField(
      controller: controller,
      label: label,
      prefixIcon: AfriIcons.phone,
      helperText: helperText,
      errorText: errorText,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
        LengthLimitingTextInputFormatter(24),
      ],
      onChanged: onChanged,
    );
  }
}

class AfriEmailInputField extends StatelessWidget {
  const AfriEmailInputField({
    required this.controller,
    this.label = 'Email',
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AfriInputField(
      controller: controller,
      label: label,
      helperText: helperText,
      errorText: errorText,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      textCapitalization: TextCapitalization.none,
      enableSuggestions: false,
      autocorrect: false,
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        LengthLimitingTextInputFormatter(254),
      ],
      onChanged: onChanged,
    );
  }
}

/// Password input with an explicit, keyboard-accessible reveal control.
class AfriPasswordInputField extends StatefulWidget {
  const AfriPasswordInputField({
    required this.controller,
    this.label = 'Password',
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.strengthLabel,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final String? strengthLabel;
  final ValueChanged<String>? onChanged;

  @override
  State<AfriPasswordInputField> createState() => _AfriPasswordInputFieldState();
}

class _AfriPasswordInputFieldState extends State<AfriPasswordInputField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final strength = widget.strengthLabel?.trim();
    final helper = [
      if (widget.helperText?.trim().isNotEmpty == true)
        widget.helperText!.trim(),
      if (strength?.isNotEmpty == true) 'Strength: $strength',
    ].join(' • ');
    return AfriInputField(
      controller: widget.controller,
      label: widget.label,
      helperText: helper.isEmpty ? null : helper,
      errorText: widget.errorText,
      enabled: widget.enabled,
      obscureText: !_revealed,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      enableSuggestions: false,
      autocorrect: false,
      onChanged: widget.onChanged,
      suffixIcon: AfriIconButton(
        icon: _revealed ? AfriIcons.visibilityOff : AfriIcons.visibility,
        tooltip: _revealed ? 'Hide password' : 'Show password',
        onTap: widget.enabled
            ? () => setState(() => _revealed = !_revealed)
            : null,
      ),
    );
  }
}

typedef AfriDatePicker =
    Future<DateTime?> Function(
      BuildContext context,
      DateTime initialDate,
      DateTime firstDate,
      DateTime lastDate,
    );

class AfriDateInputField extends StatelessWidget {
  const AfriDateInputField({
    required this.controller,
    required this.onSelected,
    this.label = 'Date',
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.errorText,
    this.picker,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<DateTime> onSelected;
  final String label;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;
  final String? errorText;
  final AfriDatePicker? picker;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      enabled: enabled,
      onTap: enabled ? () => _select(context) : null,
      semanticsLabel: label,
      child: AfriInputField(
        controller: controller,
        label: label,
        errorText: errorText,
        enabled: enabled,
        readOnly: true,
        prefixIcon: AfriIcons.calendar,
        suffixIcon: const Icon(AfriIcons.chevronDown),
        onTap: enabled ? () => _select(context) : null,
      ),
    );
  }

  Future<void> _select(BuildContext context) async {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 100);
    final last = lastDate ?? DateTime(now.year + 20);
    final initial = initialDate ?? now;
    final result = await (picker ?? _defaultDatePicker)(
      context,
      initial.isBefore(first)
          ? first
          : initial.isAfter(last)
          ? last
          : initial,
      first,
      last,
    );
    if (result != null) onSelected(result);
  }

  static Future<DateTime?> _defaultDatePicker(
    BuildContext context,
    DateTime initialDate,
    DateTime firstDate,
    DateTime lastDate,
  ) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
}

typedef AfriTimePicker =
    Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initialTime);

class AfriTimeInputField extends StatelessWidget {
  const AfriTimeInputField({
    required this.controller,
    required this.onSelected,
    this.label = 'Time',
    this.initialTime,
    this.enabled = true,
    this.errorText,
    this.picker,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<TimeOfDay> onSelected;
  final String label;
  final TimeOfDay? initialTime;
  final bool enabled;
  final String? errorText;
  final AfriTimePicker? picker;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      enabled: enabled,
      onTap: enabled ? () => _select(context) : null,
      semanticsLabel: label,
      child: AfriInputField(
        controller: controller,
        label: label,
        errorText: errorText,
        enabled: enabled,
        readOnly: true,
        prefixIcon: AfriIcons.timer,
        suffixIcon: const Icon(AfriIcons.chevronDown),
        onTap: enabled ? () => _select(context) : null,
      ),
    );
  }

  Future<void> _select(BuildContext context) async {
    final result = await (picker ?? _defaultTimePicker)(
      context,
      initialTime ?? TimeOfDay.now(),
    );
    if (result != null) onSelected(result);
  }

  static Future<TimeOfDay?> _defaultTimePicker(
    BuildContext context,
    TimeOfDay initialTime,
  ) {
    return showTimePicker(context: context, initialTime: initialTime);
  }
}

class AfriOtpInputField extends StatelessWidget {
  const AfriOtpInputField({
    required this.controller,
    this.length = 6,
    this.label = 'One-time code',
    this.errorText,
    this.enabled = true,
    this.onCompleted,
    super.key,
  }) : assert(length > 0);

  final TextEditingController controller;
  final int length;
  final String label;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onCompleted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: '$label, $length digits',
      child: AfriInputField(
        controller: controller,
        label: label,
        errorText: errorText,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: length,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(length),
        ],
        onChanged: (value) {
          if (value.length == length) onCompleted?.call(value);
        },
      ),
    );
  }
}

enum AfriPickerState {
  empty,
  selected,
  loading,
  success,
  warning,
  error,
  offline,
  permissionDenied,
}

/// Shared query input for discovery, command, and scoped-list search.
class AfriSearchInputField extends StatelessWidget {
  const AfriSearchInputField({
    required this.controller,
    this.focusNode,
    this.label = 'Search',
    this.hint,
    this.enabled = true,
    this.errorText,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final bool enabled;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => AfriInputField(
        controller: controller,
        focusNode: focusNode,
        label: label,
        hint: hint,
        prefixIcon: AfriIcons.search,
        enabled: enabled,
        errorText: errorText,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        enableSuggestions: true,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        suffixIcon: controller.text.isEmpty
            ? null
            : AfriIconButton(
                icon: AfriIcons.close,
                tooltip: 'Clear $label',
                onTap: enabled
                    ? () {
                        controller.clear();
                        onClear?.call();
                        onChanged?.call('');
                      }
                    : null,
              ),
      ),
    );
  }
}

/// Shared picker surface. Platform file selection and permission requests stay
/// caller-owned so the component cannot silently broaden data access.
class AfriFileMediaPicker extends StatelessWidget {
  const AfriFileMediaPicker({
    required this.label,
    required this.onPick,
    this.state = AfriPickerState.empty,
    this.fileName,
    this.provenanceLabel,
    this.message,
    this.enabled = true,
    this.onClear,
    super.key,
  });

  final String label;
  final VoidCallback onPick;
  final AfriPickerState state;
  final String? fileName;
  final String? provenanceLabel;
  final String? message;
  final bool enabled;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final normalizedName = fileName?.trim();
    final hasSelection = normalizedName != null && normalizedName.isNotEmpty;
    final stateMessage = message ?? _defaultMessage(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AfriButton(
          label: hasSelection ? 'Replace $label' : 'Choose $label',
          icon: AfriIcons.cloud,
          isLoading: state == AfriPickerState.loading,
          enabled: enabled && state != AfriPickerState.loading,
          onTap: onPick,
        ),
        if (hasSelection) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          AfriStateBanner(
            icon: AfriIcons.verified,
            title: normalizedName,
            subtitle: provenanceLabel?.trim().isNotEmpty == true
                ? 'Source: ${provenanceLabel!.trim()}'
                : 'Source approval not recorded',
            tone: provenanceLabel?.trim().isNotEmpty == true
                ? AfriStateBannerTone.success
                : AfriStateBannerTone.warning,
            trailing: onClear == null
                ? null
                : AfriIconButton(
                    icon: AfriIcons.delete,
                    tooltip: 'Remove selected $label',
                    onTap: onClear,
                  ),
          ),
        ],
        if (stateMessage != null) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          AfriStateBanner(
            icon: _iconFor(state),
            title: stateMessage,
            tone: _toneFor(state),
          ),
        ],
      ],
    );
  }

  static String? _defaultMessage(AfriPickerState state) => switch (state) {
    AfriPickerState.empty || AfriPickerState.selected => null,
    AfriPickerState.loading => 'Opening protected file selection',
    AfriPickerState.success => 'Selection is ready for review',
    AfriPickerState.warning => 'Review source and usage rights',
    AfriPickerState.error => 'The file could not be selected',
    AfriPickerState.offline => 'File selection is unavailable offline',
    AfriPickerState.permissionDenied =>
      'Permission is required before selecting media',
  };

  static IconData _iconFor(AfriPickerState state) => switch (state) {
    AfriPickerState.empty || AfriPickerState.selected => AfriIcons.statusInfo,
    AfriPickerState.loading => AfriIcons.statusLoading,
    AfriPickerState.success => AfriIcons.statusSuccess,
    AfriPickerState.warning => AfriIcons.statusWarning,
    AfriPickerState.error => AfriIcons.statusError,
    AfriPickerState.offline => AfriIcons.offline,
    AfriPickerState.permissionDenied => AfriIcons.lock,
  };

  static AfriStateBannerTone _toneFor(AfriPickerState state) => switch (state) {
    AfriPickerState.empty ||
    AfriPickerState.selected ||
    AfriPickerState.loading => AfriStateBannerTone.info,
    AfriPickerState.success => AfriStateBannerTone.success,
    AfriPickerState.warning => AfriStateBannerTone.warning,
    AfriPickerState.error => AfriStateBannerTone.danger,
    AfriPickerState.offline ||
    AfriPickerState.permissionDenied => AfriStateBannerTone.warning,
  };
}

class AfriNumericInputFormatter extends TextInputFormatter {
  AfriNumericInputFormatter({
    this.allowDecimal = false,
    this.allowNegative = false,
    this.decimalDigits = 2,
  }) : assert(decimalDigits >= 0);

  final bool allowDecimal;
  final bool allowNegative;
  final int decimalDigits;

  late final RegExp _pattern = RegExp(
    '^${allowNegative ? '-?' : ''}'
    r'\d*'
    '${allowDecimal && decimalDigits > 0 ? r'(?:\.\d{0,'
              '$decimalDigits})?' : ''}'
    r'$',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
