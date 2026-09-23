import 'package:flutter/material.dart';

import '../tokens/icon_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_button.dart';
import 'afri_selection_controls.dart';
import 'afri_state_banner.dart';
import 'afri_surface_card.dart';

enum AfriSessionTimeoutState { warning, expired, offline }

class AfriSessionTimeoutPrompt extends StatelessWidget {
  const AfriSessionTimeoutPrompt({
    required this.state,
    required this.onReauthenticate,
    this.remaining,
    this.onDismiss,
    super.key,
  });

  final AfriSessionTimeoutState state;
  final Duration? remaining;
  final VoidCallback onReauthenticate;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final expired = state == AfriSessionTimeoutState.expired;
    final title = switch (state) {
      AfriSessionTimeoutState.warning => 'Session ending soon',
      AfriSessionTimeoutState.expired => 'Session ended',
      AfriSessionTimeoutState.offline => 'Session check unavailable',
    };
    final message = switch (state) {
      AfriSessionTimeoutState.warning =>
        remaining == null
            ? 'Reauthenticate to continue securely.'
            : 'Reauthenticate within ${_durationLabel(remaining!)} to keep your work.',
      AfriSessionTimeoutState.expired =>
        'Sign in again to continue. Your intended destination will be preserved.',
      AfriSessionTimeoutState.offline =>
        'Reconnect before continuing with protected actions.',
    };
    return AfriSurfaceCard(
      semanticsLabel: '$title. $message',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AfriStateBanner(
            icon: state == AfriSessionTimeoutState.offline
                ? AfriIcons.offline
                : AfriIcons.timer,
            title: title,
            subtitle: message,
            tone: expired
                ? AfriStateBannerTone.danger
                : AfriStateBannerTone.warning,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            label: expired ? 'Sign in again' : 'Reauthenticate',
            icon: AfriIcons.lock,
            enabled: state != AfriSessionTimeoutState.offline,
            onTap: onReauthenticate,
          ),
          if (!expired && onDismiss != null) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            AfriButton(
              label: 'Not now',
              variant: AfriButtonVariant.ghost,
              onTap: onDismiss!,
            ),
          ],
        ],
      ),
    );
  }

  static String _durationLabel(Duration duration) {
    if (duration.inMinutes >= 1) return '${duration.inMinutes} minutes';
    return '${duration.inSeconds.clamp(0, 59)} seconds';
  }
}

enum AfriPermissionState { education, denied, permanentlyDenied, unavailable }

/// Permission education surface. The caller must initiate the OS prompt only
/// from [onContinue], preserving a user-triggered permission boundary.
class AfriPermissionPrompt extends StatelessWidget {
  const AfriPermissionPrompt({
    required this.title,
    required this.reason,
    required this.state,
    required this.onContinue,
    this.onDecline,
    this.onOpenSettings,
    super.key,
  });

  final String title;
  final String reason;
  final AfriPermissionState state;
  final VoidCallback onContinue;
  final VoidCallback? onDecline;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final denied = state != AfriPermissionState.education;
    final actionLabel = switch (state) {
      AfriPermissionState.education => 'Continue',
      AfriPermissionState.denied => 'Try again',
      AfriPermissionState.permanentlyDenied => 'Open settings',
      AfriPermissionState.unavailable => 'Unavailable',
    };
    final action = state == AfriPermissionState.permanentlyDenied
        ? onOpenSettings
        : state == AfriPermissionState.unavailable
        ? null
        : onContinue;
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AfriStateBanner(
            icon: denied ? AfriIcons.lock : AfriIcons.privacy,
            title: title,
            subtitle: reason,
            tone: denied
                ? AfriStateBannerTone.warning
                : AfriStateBannerTone.info,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            label: actionLabel,
            enabled: action != null,
            onTap: action ?? () {},
          ),
          if (onDecline != null) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            AfriButton(
              label: 'Not now',
              variant: AfriButtonVariant.ghost,
              onTap: onDecline!,
            ),
          ],
        ],
      ),
    );
  }
}

class AfriConsentItem {
  const AfriConsentItem({
    required this.id,
    required this.title,
    required this.description,
    required this.accepted,
    this.required = false,
  });

  final String id;
  final String title;
  final String description;
  final bool accepted;
  final bool required;
}

class AfriConsentReview extends StatelessWidget {
  const AfriConsentReview({
    required this.title,
    required this.items,
    required this.onChanged,
    required this.onConfirm,
    this.confirmLabel = 'Confirm choices',
    this.errorText,
    super.key,
  });

  final String title;
  final List<AfriConsentItem> items;
  final void Function(String id, bool accepted) onChanged;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final missingRequired = items.any(
      (item) => item.required && !item.accepted,
    );
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TypographyTokens.titleLarge()),
          const SizedBox(height: SpacingTokens.spacing3),
          for (final item in items)
            AfriCheckbox(
              label: item.required ? '${item.title} (required)' : item.title,
              subtitle: item.description,
              value: item.accepted,
              onChanged: item.required && item.accepted
                  ? null
                  : (value) => onChanged(item.id, value ?? false),
            ),
          if (errorText?.trim().isNotEmpty == true) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            AfriStateBanner(
              icon: AfriIcons.statusError,
              title: errorText!.trim(),
              tone: AfriStateBannerTone.danger,
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing4),
          AfriButton(
            label: confirmLabel,
            icon: AfriIcons.check,
            enabled: !missingRequired && onConfirm != null,
            onTap: onConfirm ?? () {},
          ),
        ],
      ),
    );
  }
}
