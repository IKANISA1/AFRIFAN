import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

enum AfriSnackbarTone { info, success, warning, error }

class AfriSnackbar {
  AfriSnackbar._();

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    AfriSnackbarTone tone = AfriSnackbarTone.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = AfriMotion.toastExtended,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        showCloseIcon: actionLabel == null,
        content: Semantics(
          liveRegion: true,
          excludeSemantics: true,
          label: '${_toneLabel(tone)}: $message',
          child: Row(
            children: [
              Icon(_icon(tone), color: _foreground),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Text(
                  message,
                  style: TypographyTokens.bodyMedium(_foreground),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: _background(tone),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
  }

  static String _toneLabel(AfriSnackbarTone tone) => switch (tone) {
    AfriSnackbarTone.info => 'Information',
    AfriSnackbarTone.success => 'Success',
    AfriSnackbarTone.warning => 'Warning',
    AfriSnackbarTone.error => 'Error',
  };

  static IconData _icon(AfriSnackbarTone tone) => switch (tone) {
    AfriSnackbarTone.info => AfriIcons.statusInfo,
    AfriSnackbarTone.success => AfriIcons.statusSuccess,
    AfriSnackbarTone.warning => AfriIcons.statusWarning,
    AfriSnackbarTone.error => AfriIcons.statusError,
  };

  static Color get _foreground =>
      ColorTokens.isDark ? ColorTokens.inkBase : ColorTokens.onDark;

  static Color _background(AfriSnackbarTone tone) => switch (tone) {
    AfriSnackbarTone.info => ColorTokens.info,
    AfriSnackbarTone.success => ColorTokens.success,
    AfriSnackbarTone.warning => ColorTokens.warning,
    AfriSnackbarTone.error => ColorTokens.error,
  };
}
