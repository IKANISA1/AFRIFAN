import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_button.dart';

/// Tone-based state indicator for inline feedback.
enum AfriStateTone { loading, empty, offline, error, success }

/// A multi-tone state card for inline status feedback.
///
/// Use instead of full-screen error/empty views when the state
/// is contextual to a section (e.g. a card that failed to load).
///
/// ```dart
/// AfriStateView.error(
///   title: 'Failed to load',
///   message: 'Check your connection.',
///   actionLabel: 'Retry',
///   onAction: () => retry(),
/// )
/// ```
class AfriStateView extends StatelessWidget {
  const AfriStateView({
    required this.tone,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.center = true,
    super.key,
  });

  factory AfriStateView.loading({
    String title = 'Loading',
    String message = 'Please wait while this section loads.',
    bool compact = false,
    Key? key,
  }) {
    return AfriStateView(
      key: key,
      tone: AfriStateTone.loading,
      title: title,
      message: message,
      icon: AfriIcons.statusLoading,
      compact: compact,
    );
  }

  factory AfriStateView.empty({
    required String title,
    required String message,
    IconData icon = AfriIcons.statusEmpty,
    String? actionLabel,
    VoidCallback? onAction,
    bool compact = false,
    Key? key,
  }) {
    return AfriStateView(
      key: key,
      tone: AfriStateTone.empty,
      title: title,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      compact: compact,
    );
  }

  factory AfriStateView.offline({
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    bool compact = false,
    Key? key,
  }) {
    return AfriStateView(
      key: key,
      tone: AfriStateTone.offline,
      title: title,
      message: message,
      icon: AfriIcons.offline,
      actionLabel: actionLabel,
      onAction: onAction,
      compact: compact,
    );
  }

  factory AfriStateView.error({
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    bool compact = false,
    Key? key,
  }) {
    return AfriStateView(
      key: key,
      tone: AfriStateTone.error,
      title: title,
      message: message,
      icon: AfriIcons.statusError,
      actionLabel: actionLabel,
      onAction: onAction,
      compact: compact,
    );
  }

  factory AfriStateView.success({
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    bool compact = false,
    Key? key,
  }) {
    return AfriStateView(
      key: key,
      tone: AfriStateTone.success,
      title: title,
      message: message,
      icon: AfriIcons.statusSuccess,
      actionLabel: actionLabel,
      onAction: onAction,
      compact: compact,
    );
  }

  final AfriStateTone tone;
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;
  final bool center;

  Color _accentColor(colors) => switch (tone) {
    AfriStateTone.loading => colors.accent,
    AfriStateTone.empty => colors.tertiaryText,
    AfriStateTone.offline => colors.warning,
    AfriStateTone.error => colors.danger,
    AfriStateTone.success => colors.accent,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final theme = Theme.of(context);
    final accentColor = _accentColor(colors);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    final content = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? SpacingTokens.spacing4 : SpacingTokens.spacing5,
        vertical: compact ? SpacingTokens.spacing4 : SpacingTokens.spacing6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact
                ? AfriComponentSizes.stateViewIconCompact
                : AfriComponentSizes.stateViewIconRegular,
            color: accentColor,
          ),
          SizedBox(
            height: compact
                ? AfriComponentSizes.stateViewGapCompact
                : AfriComponentSizes.stateViewGapRegular,
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style:
                (compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.primaryText,
                    ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            message,
            textAlign: TextAlign.center,
            style:
                (compact
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.secondaryText,
                      height: TypographyTokens.lineHeightBody,
                    ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(
              height: compact
                  ? AfriComponentSizes.stateViewActionGapCompact
                  : AfriComponentSizes.stateViewActionGapRegular,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: SizeTokens.touchTargetMin,
              ),
              child: AfriButton(
                label: actionLabel!,
                onTap: onAction!,
                variant:
                    tone == AfriStateTone.error || tone == AfriStateTone.offline
                    ? AfriButtonVariant.secondary
                    : AfriButtonVariant.primary,
                fullWidth: false,
              ),
            ),
          ],
        ],
      ),
    );

    final centeredContent = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 4,
        vertical: compact ? 0 : 12,
      ),
      child: content,
    );

    return Semantics(
      label: '$title. $message',
      liveRegion: tone == AfriStateTone.error || tone == AfriStateTone.offline,
      child: center
          ? largeText
                ? SingleChildScrollView(
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    child: centeredContent,
                  )
                : Center(child: centeredContent)
          : content,
    );
  }
}
