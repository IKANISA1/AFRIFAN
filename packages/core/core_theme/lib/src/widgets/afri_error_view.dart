import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../extensions.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_button.dart';

/// Standardized error view with animated icon and retry action.
///
/// ```dart
/// AfriErrorView(
///   message: 'Failed to load match data.',
///   onRetry: () => ref.invalidate(matchProvider),
/// )
/// ```
class AfriErrorView extends StatelessWidget {
  const AfriErrorView({
    this.message,
    this.onRetry,
    this.actionLabel,
    this.icon = AfriIcons.statusError,
    this.compact = false,
    super.key,
  });

  final String? message;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final IconData icon;
  final bool compact;

  String get _effectiveMessage => message ?? 'An error occurred';

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final theme = Theme.of(context);
    final iconSize = compact ? 36.0 : 52.0;
    final spacing = compact ? SpacingTokens.spacing3 : SpacingTokens.spacing5;
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion =
        mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true;

    Widget iconWidget = ExcludeSemantics(
      child: Container(
        width: iconSize + 20,
        height: iconSize + 20,
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: iconSize, color: colors.danger),
      ),
    );
    if (!reduceMotion) {
      iconWidget = iconWidget
          .animate()
          .shake(duration: 500.ms, hz: 4)
          .scale(begin: const Offset(0.8, 0.8), duration: 400.ms);
    }

    Widget messageWidget = Text(
      _effectiveMessage,
      textAlign: TextAlign.center,
      style: (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
          ?.copyWith(color: colors.secondaryText, height: 1.5),
    );
    if (!reduceMotion) {
      messageWidget = messageWidget.animate().fadeIn(
        delay: 200.ms,
        duration: 400.ms,
      );
    }

    Widget? retryWidget;
    if (onRetry != null) {
      retryWidget = AfriButton(
        label: actionLabel ?? 'Try Again',
        onTap: onRetry!,
        variant: AfriButtonVariant.secondary,
        fullWidth: false,
      );
      if (!reduceMotion) {
        retryWidget = retryWidget
            .animate()
            .fadeIn(delay: 400.ms)
            .scale(begin: const Offset(0.95, 0.95));
      }
    }

    return Semantics(
      label: 'Error: $_effectiveMessage',
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing8,
            vertical: compact
                ? SpacingTokens.spacing4
                : SpacingTokens.spacing10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              SizedBox(height: spacing),
              messageWidget,
              if (retryWidget != null) ...[
                SizedBox(height: spacing + 4),
                retryWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
