import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/game_operations_models.dart';

AfriAppBar gameOperationsAppBar(
  BuildContext context,
  String title, {
  String fallbackPath = '/game-operations',
  String? titleRevision,
}) {
  return AfriAppBar(
    title: KeyedSubtree(
      key: ValueKey<String>(
        'game-operations-app-bar-title-revision-${titleRevision ?? title}',
      ),
      child: Text(
        key: const ValueKey<String>('game-operations-app-bar-title'),
        title,
        style: TypographyTokens.headlineSmall().copyWith(
          color: ColorTokens.chromeForeground,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    leading: AfriIconButton(
      icon: AfriIcons.back,
      tooltip: context.afriL10n.gameBack,
      onTap: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackPath);
        }
      },
    ),
  );
}

Widget gameOperationsFailureView(
  BuildContext context,
  GameOperationsFailure? failure,
  VoidCallback onRetry, {
  String? offlineDescription,
}) {
  final l10n = context.afriL10n;
  final permission =
      failure?.kind == GameOperationsFailureKind.permissionDenied;
  final offline = failure?.kind == GameOperationsFailureKind.offline;
  final conflict = failure?.kind == GameOperationsFailureKind.conflict;
  final timeout = failure?.kind == GameOperationsFailureKind.timeout;
  return AfriStateView.error(
    title: offline
        ? l10n.gameOperationsOffline
        : permission
        ? l10n.gameOperationsAccessDenied
        : conflict
        ? l10n.gameOperationConflict
        : timeout
        ? l10n.gameOperationTimeout
        : l10n.gameOperationsUnavailable,
    message: offline
        ? offlineDescription ?? l10n.gameOperationsOfflineDescription
        : permission
        ? l10n.gameOperationsAccessDeniedDescription
        : conflict
        ? l10n.gameOperationConflictDescription
        : timeout
        ? l10n.gameOperationTimeoutDescription
        : l10n.gameOperationsUnavailableDescription,
    actionLabel: l10n.gameTryAgainUpper,
    onAction: onRetry,
  );
}

String gameOperationsFailureDescription(
  AfriLocalizations l10n,
  GameOperationsFailure failure, {
  String? offlineDescription,
}) {
  return switch (failure.kind) {
    GameOperationsFailureKind.offline =>
      offlineDescription ?? l10n.gameOperationsOfflineDescription,
    GameOperationsFailureKind.permissionDenied =>
      l10n.gameOperationsAccessDeniedDescription,
    GameOperationsFailureKind.conflict => l10n.gameOperationConflictDescription,
    GameOperationsFailureKind.timeout => l10n.gameOperationTimeoutDescription,
    _ => l10n.gameOperationsUnavailableDescription,
  };
}

String localizedGamePhase(AfriLocalizations l10n, String phase) {
  return switch (phase) {
    'draft' => l10n.gamePhaseDraft,
    'validated' => l10n.gamePhaseValidated,
    'published' => l10n.gamePhasePublished,
    'scheduled' => l10n.gamePhaseScheduled,
    'activated_lobby' => l10n.gamePhaseLobby,
    'question_open' => l10n.gamePhaseQuestionOpen,
    'reveal' => l10n.gamePhaseReveal,
    'paused' => l10n.gamePhasePaused,
    'completed' => l10n.gamePhaseCompleted,
    'cancelled' => l10n.gamePhaseCancelled,
    _ => l10n.gameOperationsUnavailable,
  };
}

String localizedEligibility(AfriLocalizations l10n, String scope) {
  return switch (scope) {
    'club_membership' => l10n.gameEligibilityClubMembership,
    'invitation_only' => l10n.gameEligibilityInvitationOnly,
    'home_owner' => l10n.gameEligibilityHomeOwner,
    'venue' => l10n.gameEligibilityVenue,
    _ => l10n.gameOperationsUnavailable,
  };
}

String localizedDisplayScope(AfriLocalizations l10n, String scope) {
  return switch (scope) {
    'home' => l10n.gameTvScopeHome,
    'venue' => l10n.gameTvScopeVenue,
    _ => l10n.gameOperationsUnavailable,
  };
}

String localizedDisplayHealth(AfriLocalizations l10n, String health) {
  return switch (health) {
    'online' => l10n.gameTvHealthOnline,
    'offline' => l10n.gameTvHealthOffline,
    'revoked' => l10n.gameTvHealthRevoked,
    _ => l10n.gameTvHealthUnknown,
  };
}

String localizedPairingStatus(AfriLocalizations l10n, String status) {
  return switch (status) {
    'paired' => l10n.gameTvStatusPaired,
    'pending' => l10n.gameTvStatusPending,
    'disabled' => l10n.gameTvStatusDisabled,
    _ => l10n.gameTvHealthUnknown,
  };
}

String formattedDisplayLastSeen(BuildContext context, DateTime? value) {
  if (value == null) return context.afriL10n.gameTvNotReported;
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} · '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

String formattedDisplayCapabilities(
  BuildContext context,
  Map<String, Object?> capabilities,
) {
  if (capabilities.isEmpty) return context.afriL10n.gameTvNotReported;
  final entries = capabilities.entries.toList(growable: false)
    ..sort((left, right) => left.key.compareTo(right.key));
  return entries
      .map((entry) {
        final label = _humanizeCapability(entry.key);
        final value = entry.value;
        if (value is bool) {
          final state = value
              ? context.afriL10n.gameTvCapabilityEnabled
              : context.afriL10n.gameTvCapabilityDisabled;
          return '$label: $state';
        }
        final displayedValue = value is String
            ? _humanizeCapability(value)
            : value ?? context.afriL10n.gameTvNotReported;
        return '$label: $displayedValue';
      })
      .join(' · ');
}

String _humanizeCapability(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String formattedAssignedSession(BuildContext context, OwnedDisplay display) {
  final session = display.assignedSession;
  if (session == null) {
    return display.assignedSessionId ?? context.afriL10n.gameTvUnassigned;
  }
  return context.afriL10n.gameTvAssignedSessionValue(
    session.title,
    localizedGamePhase(context.afriL10n, session.phase),
  );
}

class GameOperationsInfoRow extends StatelessWidget {
  const GameOperationsInfoRow({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TypographyTokens.bodyMedium(colors.secondaryText),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TypographyTokens.bodyMedium(
                colors.primaryText,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
