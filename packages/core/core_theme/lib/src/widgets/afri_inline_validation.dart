import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../tokens/color_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

enum AfriInlineValidationTone { info, success, warning, error }

/// Compact, non-color-only validation feedback for forms and editable rows.
///
/// Error messages are announced as invalid live regions. Other tones remain
/// live status updates so async validation changes are not lost to assistive
/// technology.
class AfriInlineValidation extends StatelessWidget {
  const AfriInlineValidation({
    required this.message,
    this.tone = AfriInlineValidationTone.info,
    super.key,
  });

  final String message;
  final AfriInlineValidationTone tone;

  @override
  Widget build(BuildContext context) {
    final toneLabel = switch (tone) {
      AfriInlineValidationTone.info => 'Information',
      AfriInlineValidationTone.success => 'Success',
      AfriInlineValidationTone.warning => 'Warning',
      AfriInlineValidationTone.error => 'Error',
    };
    final foreground = switch (tone) {
      AfriInlineValidationTone.info => ColorTokens.info,
      AfriInlineValidationTone.success => ColorTokens.success,
      AfriInlineValidationTone.warning => ColorTokens.warning,
      AfriInlineValidationTone.error => ColorTokens.error,
    };
    final icon = switch (tone) {
      AfriInlineValidationTone.info => AfriIcons.statusInfo,
      AfriInlineValidationTone.success => AfriIcons.statusSuccess,
      AfriInlineValidationTone.warning => AfriIcons.statusWarning,
      AfriInlineValidationTone.error => AfriIcons.statusError,
    };

    return Semantics(
      container: true,
      excludeSemantics: true,
      liveRegion: true,
      validationResult: tone == AfriInlineValidationTone.error
          ? SemanticsValidationResult.invalid
          : SemanticsValidationResult.none,
      label: '$toneLabel: $message',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: SizeTokens.iconSm, color: foreground),
          const SizedBox(width: SpacingTokens.spacing2),
          Expanded(
            child: Text(message, style: TypographyTokens.bodySmall(foreground)),
          ),
        ],
      ),
    );
  }
}
