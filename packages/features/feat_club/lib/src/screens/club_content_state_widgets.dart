import 'package:club_data/club_data.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

class ClubContentStatusBanner extends StatelessWidget {
  const ClubContentStatusBanner({
    required this.refreshing,
    required this.failure,
    super.key,
  });

  final bool refreshing;
  final ClubContentFailure? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    if (refreshing) {
      return AfriStateBanner(
        icon: AfriIcons.refresh,
        title: l10n.clubRefreshingTitle,
        subtitle: l10n.clubRefreshingMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    final resolved = failure!;
    final content = ClubContentFailureCopy.fromFailure(l10n, resolved);
    return AfriStateBanner(
      icon: resolved.kind == ClubContentFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: content.title,
      subtitle: content.message,
      tone: resolved.kind == ClubContentFailureKind.offline
          ? AfriStateBannerTone.warning
          : AfriStateBannerTone.danger,
    );
  }
}

class ClubContentFailureView extends StatelessWidget {
  const ClubContentFailureView({
    required this.failure,
    this.onRetry,
    this.linkedRecord = false,
    this.compact = false,
    super.key,
  });

  final ClubContentFailure failure;
  final VoidCallback? onRetry;
  final bool linkedRecord;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final content = ClubContentFailureCopy.fromFailure(
      l10n,
      failure,
      linkedRecord: linkedRecord,
    );
    if (failure.kind == ClubContentFailureKind.offline) {
      return AfriStateView.offline(
        compact: compact,
        title: content.title,
        message: content.message,
        actionLabel: onRetry == null ? null : l10n.retry,
        onAction: onRetry,
      );
    }
    return AfriStateView.error(
      compact: compact,
      title: content.title,
      message: content.message,
      actionLabel: failure.kind == ClubContentFailureKind.permissionDenied
          ? null
          : l10n.retry,
      onAction: failure.kind == ClubContentFailureKind.permissionDenied
          ? null
          : onRetry,
    );
  }
}

class ClubContentFailureCopy {
  const ClubContentFailureCopy(this.title, this.message);

  final String title;
  final String message;

  factory ClubContentFailureCopy.fromFailure(
    AfriLocalizations l10n,
    ClubContentFailure failure, {
    bool linkedRecord = false,
  }) {
    return switch (failure.kind) {
      ClubContentFailureKind.offline => ClubContentFailureCopy(
        l10n.clubOfflineTitle,
        l10n.clubOfflineMessage,
      ),
      ClubContentFailureKind.permissionDenied => ClubContentFailureCopy(
        l10n.clubAccessDeniedTitle,
        l10n.clubAccessDeniedMessage,
      ),
      ClubContentFailureKind.conflict => ClubContentFailureCopy(
        l10n.clubChangedTitle,
        l10n.clubChangedMessage,
      ),
      ClubContentFailureKind.securityTimeout => ClubContentFailureCopy(
        l10n.clubSecurityTimeoutTitle,
        l10n.clubSecurityTimeoutMessage,
      ),
      ClubContentFailureKind.unknown => ClubContentFailureCopy(
        l10n.clubInformationUnavailable,
        linkedRecord
            ? l10n.clubLinkedRecordLoadMessage
            : l10n.clubInformationLoadMessage,
      ),
    };
  }
}
