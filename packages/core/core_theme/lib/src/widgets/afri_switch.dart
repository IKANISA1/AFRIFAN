import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';

/// Borrowed-system compact switch for inline settings rows.
class AfriSwitch extends StatelessWidget {
  const AfriSwitch({
    required this.value,
    required this.onChanged,
    this.activeThumbColor,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeThumbColor;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeThumbColor ?? ColorTokens.clubAccent,
      activeTrackColor: (activeThumbColor ?? ColorTokens.clubAccent).withValues(
        alpha: 0.32,
      ),
      inactiveThumbColor: ColorTokens.onSurfaceVariant,
      inactiveTrackColor: ColorTokens.surfaceContainerHigh,
    );
  }
}
