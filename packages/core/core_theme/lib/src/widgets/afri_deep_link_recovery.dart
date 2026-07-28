import 'package:flutter/material.dart';

import '../tokens/icon_tokens.dart';
import 'afri_state_view.dart';

enum AfriDeepLinkRecoveryState { unavailable, error, offline }

/// Consistent recovery surface for unavailable, malformed, and offline links.
class AfriDeepLinkRecovery extends StatelessWidget {
  const AfriDeepLinkRecovery({
    required this.state,
    required this.onAction,
    this.title,
    this.message,
    this.actionLabel,
    this.compact = true,
    super.key,
  });

  final AfriDeepLinkRecoveryState state;
  final VoidCallback onAction;
  final String? title;
  final String? message;
  final String? actionLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AfriDeepLinkRecoveryState.unavailable => AfriStateView.empty(
        title: title ?? 'This feature is currently unavailable.',
        message:
            message ?? 'The club has hidden or disabled this section for now.',
        icon: AfriIcons.statusBlocked,
        actionLabel: actionLabel ?? 'Go back',
        onAction: onAction,
        compact: compact,
      ),
      AfriDeepLinkRecoveryState.error => AfriStateView.error(
        title: title ?? 'We could not open that page.',
        message: message ?? 'The requested route is unavailable.',
        actionLabel: actionLabel ?? 'Go home',
        onAction: onAction,
        compact: compact,
      ),
      AfriDeepLinkRecoveryState.offline => AfriStateView.offline(
        title: title ?? 'This link needs a connection.',
        message: message ?? 'Reconnect and try opening the destination again.',
        actionLabel: actionLabel ?? 'Retry',
        onAction: onAction,
        compact: compact,
      ),
    };
  }
}
