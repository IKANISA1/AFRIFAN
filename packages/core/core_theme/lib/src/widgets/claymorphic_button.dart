import 'package:flutter/material.dart';

import 'afri_button.dart';

/// Legacy CTA button — now a thin wrapper delegating to [AfriButton].
///
/// All new code should use [AfriButton] directly. This wrapper exists only
/// for backward compat until all call sites are migrated.
@Deprecated('Use AfriButton directly')
class ClaymorphicButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final bool preserveCase;
  final double? letterSpacing;

  const ClaymorphicButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.icon,
    this.isLoading = false,
    this.width,
    this.preserveCase = false,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return AfriButton(
      label: preserveCase ? label : _sentenceCase(label),
      onTap: onPressed ?? () {},
      icon: icon,
      isLoading: isLoading,
      fullWidth: width == double.infinity || width != null,
      enabled: onPressed != null && !isLoading,
    );
  }

  /// Convert "SOME LABEL" → "Some label" for sentence case.
  static String _sentenceCase(String input) {
    if (input.isEmpty) return input;
    // If already mixed case, keep as-is
    if (input != input.toUpperCase()) return input;
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }
}
