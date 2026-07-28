import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Themed snackbar system for the AFRICLUB platform.
///
/// Provides four themed variants (success/warning/error/info) with consistent
/// styling, haptic feedback, and auto-dismiss. Replaces raw
/// `ScaffoldMessenger.showSnackBar` usage.
///
/// ```dart
/// AfriToast.success(context, 'Membership confirmed!');
/// AfriToast.error(context, 'Payment failed. Please retry.');
/// AfriToast.info(context, 'Your profile was updated.');
/// ```
abstract final class AfriToast {
  /// Green accent toast for successful operations.
  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message: message,
      variant: _Variant.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Red toast for errors that need user attention.
  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message: message,
      variant: _Variant.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Amber toast for recoverable states that need review.
  static void warning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message: message,
      variant: _Variant.warning,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Blue toast for informational messages.
  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message: message,
      variant: _Variant.info,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required _Variant variant,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final theme = Theme.of(context);
    final colors = context.afriSemanticColors;
    final config = _config(variant, colors);

    if (variant == _Variant.success ||
        variant == _Variant.warning ||
        variant == _Variant.error) {
      unawaited(HapticFeedback.lightImpact());
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Semantics(
          container: true,
          liveRegion: true,
          label: message,
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(config.icon, color: config.color, size: SizeTokens.iconMd),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: colors.cardSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShapeTokens.radiusControl),
          side: BorderTokens.side(
            color: config.color,
            width: BorderTokens.standard,
            opacity: 0.3,
          ),
        ),
        margin: const EdgeInsets.fromLTRB(
          SpacingTokens.spacing4,
          0,
          SpacingTokens.spacing4,
          SpacingTokens.spacing4,
        ),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: config.color,
                onPressed: onAction,
              ),
        duration: variant == _Variant.error
            ? AfriMotion.toastExtended
            : AfriMotion.toastStandard,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static _VariantConfig _config(_Variant variant, colors) {
    return switch (variant) {
      _Variant.success => _VariantConfig(
        icon: AfriIcons.statusSuccess,
        color: colors.success,
      ),
      _Variant.error => _VariantConfig(
        icon: AfriIcons.statusError,
        color: colors.danger,
      ),
      _Variant.warning => _VariantConfig(
        icon: AfriIcons.statusWarning,
        color: colors.warning,
      ),
      _Variant.info => _VariantConfig(
        icon: AfriIcons.statusInfo,
        color: colors.info,
      ),
    };
  }
}

enum _Variant { success, warning, error, info }

class _VariantConfig {
  const _VariantConfig({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}
