import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_button.dart';

/// Standardized empty-state view for screens and lists with no data.
///
/// Provides animated entry with elastic bounce and fade.
/// Supports optional action CTA for guided user recovery.
///
/// ```dart
/// AfriEmptyView(
///   title: 'Matches pending',
///   message: 'Upcoming fixtures appear after publication.',
///   icon: AfriIcons.fanzone,
///   actionLabel: 'Browse Clubs',
///   onAction: () => navigateToClubs(),
/// )
/// ```
class AfriEmptyView extends StatelessWidget {
  const AfriEmptyView({
    this.title,
    this.message,
    this.icon = AfriIcons.statusEmpty,
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
          border: BorderTokens.all(
            color: colors.border,
            width: BorderTokens.standard,
            opacity: 0.55,
          ),
        ),
        child: Icon(icon, size: iconSize, color: colors.tertiaryText),
      ),
    );
    if (!reduceMotion) {
      iconWidget = iconWidget
          .animate()
          .scale(
            begin: const Offset(0.8, 0.8),
            duration: AfriMotion.atmospheric,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: AfriMotion.contentReveal);
    }

    Widget? titleWidget;
    if (title != null) {
      titleWidget = Text(
        title!,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      );
      if (!reduceMotion) {
        titleWidget = titleWidget
            .animate()
            .fadeIn(
              delay: AfriMotion.staggerCompact,
              duration: AfriMotion.contentReveal,
            )
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
          height: TypographyTokens.lineHeightSpacious,
        ),
      );
      if (!reduceMotion) {
        messageWidget = messageWidget
            .animate()
            .fadeIn(
              delay: AfriMotion.staggerStandard,
              duration: AfriMotion.contentReveal,
            )
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
            .fadeIn(
              delay: AfriMotion.emphasized,
              duration: AfriMotion.contentReveal,
            )
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
                  if (!compact) const SizedBox(height: SpacingTokens.spacing2),
                ],
                if (message != null && !compact) messageWidget!,
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
