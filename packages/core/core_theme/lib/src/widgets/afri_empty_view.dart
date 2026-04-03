import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../extensions.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_button.dart';

/// Standardized empty-state view for screens and lists with no data.
///
/// Provides animated entry with elastic bounce and fade.
/// Supports optional action CTA for guided user recovery.
///
/// ```dart
/// AfriEmptyView(
///   title: 'No Matches Yet',
///   message: 'Check back soon for upcoming fixtures.',
///   icon: Icons.sports_soccer_rounded,
///   actionLabel: 'Browse Clubs',
///   onAction: () => navigateToClubs(),
/// )
/// ```
class AfriEmptyView extends StatelessWidget {
  const AfriEmptyView({
    this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.onAction,
    this.actionLabel,
    this.compact = false,
    super.key,
  });

  final String? title;
  final String? message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final iconSize = compact ? 32.0 : 44.0;
    final spacing = compact ? SpacingTokens.spacing3 : SpacingTokens.spacing6;
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion =
        mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true;

    Widget iconWidget = ExcludeSemantics(
      child: Container(
        width: iconSize + 32,
        height: iconSize + 32,
        decoration: BoxDecoration(
          color: colors.cardSurface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.border, width: 1.5),
        ),
        child: Icon(icon, size: iconSize, color: colors.tertiaryText),
      ),
    );
    if (!reduceMotion) {
      iconWidget = iconWidget
          .animate()
          .scale(
            begin: const Offset(0.8, 0.8),
            duration: 600.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 400.ms);
    }

    Widget? titleWidget;
    if (title != null) {
      titleWidget = Text(
        title!,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      );
      if (!reduceMotion) {
        titleWidget = titleWidget
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: 0.2, end: 0);
      }
    }

    Widget? messageWidget;
    if (message != null) {
      messageWidget = Text(
        message!,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: colors.tertiaryText,
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
      );
      if (!reduceMotion) {
        messageWidget = messageWidget
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.1, end: 0);
      }
    }

    Widget? actionWidget;
    if (onAction != null && actionLabel != null) {
      actionWidget = SizedBox(
        width: compact ? null : 200,
        child: AfriButton(
          label: actionLabel!,
          onTap: onAction!,
          variant: compact
              ? AfriButtonVariant.secondary
              : AfriButtonVariant.primary,
        ),
      );
      if (!reduceMotion) {
        actionWidget = actionWidget
            .animate()
            .fadeIn(delay: 350.ms, duration: 400.ms)
            .scale(begin: const Offset(0.9, 0.9));
      }
    }

    return Semantics(
      container: true,
      label: '${title ?? ''} ${message ?? ''}',
      liveRegion: true,
      child: Center(
        child: SingleChildScrollView(
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
                if (title != null) ...[
                  titleWidget!,
                  const SizedBox(height: SpacingTokens.spacing2),
                ],
                if (message != null) messageWidget!,
                if (actionWidget != null) ...[
                  SizedBox(height: spacing + 8),
                  actionWidget,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
