import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/color_tokens.dart';
import 'afri_press_feedback.dart';

/// Universal compact switch for inline settings rows.
class AfriSwitch extends StatelessWidget {
  const AfriSwitch({
    required this.value,
    required this.onChanged,
    required this.semanticsLabel,
    this.activeThumbColor,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticsLabel;
  final Color? activeThumbColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    return AfriPressFeedback(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      enabled: onChanged != null,
      button: false,
      selected: value,
      toggled: value,
      semanticsLabel: semanticsLabel,
      excludeChildSemantics: true,
      child: IgnorePointer(
        child: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: activeThumbColor ?? ColorTokens.switchThumb,
          activeTrackColor: colors.accent,
          inactiveThumbColor: ColorTokens.switchThumb,
          inactiveTrackColor: ColorTokens.switchInactiveTrack,
        ),
      ),
    );
  }
}
