import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_challenges_controller.dart';

class ChallengeOpsScreen extends ConsumerWidget {
  const ChallengeOpsScreen({this.firstRetryFocusNode, super.key});

  final FocusNode? firstRetryFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(adminChallengesEnabledProvider);
    final challenges = ref.watch(adminChallengesProvider);
    final permissionDenied =
        challenges.valueOrNull?.failure?.kind ==
        AdminChallengesFailureKind.permissionDenied;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.adminChallengesTitle,
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.adminBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _disabled(context)
          : permissionDenied
          ? _unavailable(
              context,
              ref,
              const AdminChallengesFailure(
                AdminChallengesFailureKind.permissionDenied,
              ),
            )
          : challenges.isLoading && challenges.valueOrNull == null
          ? Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-challenges-state-loading'),
                title: context.afriL10n.adminChallengesLoadingTitle,
                message: context.afriL10n.adminChallengesLoadingMessage,
              ),
            )
          : challenges.hasError && challenges.valueOrNull == null
          ? _unavailable(
              context,
              ref,
              AdminChallengesFailure.fromError(challenges.error!),
            )
          : _content(context, ref, challenges),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<AdminChallengesSnapshot> challenges,
  ) {
    final snapshot = challenges.valueOrNull!;
    final controlsEnabled = snapshot.actionsEnabled && !challenges.isLoading;
    return AfriRefreshIndicator(
      onRefresh: ref.read(adminChallengesProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          if (_statusBanner(context, challenges) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Semantics(
            container: true,
            label: context.afriL10n.adminChallengesFilterLabel,
            child: Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: AdminChallengeFilter.values
                  .map(
                    (filter) => AfriChoiceChip(
                      selected: snapshot.filter == filter,
                      label: Text(_filterLabel(context, filter)),
                      onSelected: controlsEnabled
                          ? (_) => unawaited(
                              ref
                                  .read(adminChallengesProvider.notifier)
                                  .selectFilter(filter),
                            )
                          : null,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (snapshot.items.isEmpty)
            AfriStateView.empty(
              key: const ValueKey<String>('admin-challenges-state-empty'),
              title: context.afriL10n.adminChallengesEmptyTitle,
              message: snapshot.filter == AdminChallengeFilter.all
                  ? context.afriL10n.adminChallengesEmptyAllMessage
                  : context.afriL10n.adminChallengesEmptyFilteredMessage(
                      _filterLabel(context, snapshot.filter).toLowerCase(),
                    ),
              compact: true,
            )
          else
            ...snapshot.items.indexed.map(
              (entry) => _ChallengeCard(
                item: entry.$2,
                enabled: controlsEnabled,
                isMutating: snapshot.mutationChallengeId == entry.$2.id,
                retryFocusNode: entry.$1 == 0 ? firstRetryFocusNode : null,
                onRetry: () => _confirmRetry(context, ref, entry.$2),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRetry(
    BuildContext context,
    WidgetRef ref,
    AdminChallengeItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.afriL10n;
        return AfriAlertDialog(
          title: Text(l10n.adminChallengesRetryTitle),
          content: Text(
            l10n.adminChallengesRetryMessage(item.homeTeam, item.awayTeam),
          ),
          actions: [
            AfriTextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.adminCancelUpper),
            ),
            AfriTextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.adminRetryUpper),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(adminChallengesProvider.notifier)
        .retrySettlement(item.id);
    if (!context.mounted || result == null) return;
    if (result.status == 'pending') {
      AfriToast.info(
        context,
        context.afriL10n.adminChallengesSettlementPending,
      );
    } else {
      AfriToast.success(
        context,
        context.afriL10n.adminChallengesSettlementRefreshed,
      );
    }
  }

  Widget _disabled(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-challenges-state-disabled'),
        title: context.afriL10n.adminChallengesUnavailable,
        message: context.afriL10n.adminChallengesDisabledMessage,
        icon: AfriIcons.lock,
        actionLabel: context.afriL10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(
    BuildContext context,
    WidgetRef ref,
    AdminChallengesFailure failure,
  ) {
    final l10n = context.afriL10n;
    final view = switch (failure.kind) {
      AdminChallengesFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-challenges-state-offline'),
        title: l10n.adminChallengesOffline,
        message: l10n.adminChallengesOfflineMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: () =>
            unawaited(ref.read(adminChallengesProvider.notifier).refresh()),
      ),
      AdminChallengesFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-challenges-state-permission-denied'),
        title: l10n.adminChallengesAccessUnavailable,
        message: l10n.adminChallengesAccessUnavailableMessage,
        actionLabel: l10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
      AdminChallengesFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-challenges-state-conflict'),
        title: l10n.adminChallengesStatusChanged,
        message: l10n.adminChallengesStatusChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: () =>
            unawaited(ref.read(adminChallengesProvider.notifier).refresh()),
      ),
      AdminChallengesFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-challenges-state-security-timeout'),
        title: l10n.adminSecurityTimeout,
        message: l10n.adminChallengesSecurityTimeoutMessage,
        actionLabel: l10n.retry,
        onAction: () =>
            unawaited(ref.read(adminChallengesProvider.notifier).refresh()),
      ),
      AdminChallengesFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-challenges-state-error'),
        title: l10n.adminChallengesUnavailable,
        message: l10n.adminChallengesPrivateDataHidden,
        actionLabel: l10n.editProfileTryAgain,
        onAction: () =>
            unawaited(ref.read(adminChallengesProvider.notifier).refresh()),
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: view,
    );
  }

  Widget? _statusBanner(
    BuildContext context,
    AsyncValue<AdminChallengesSnapshot> challenges,
  ) {
    final l10n = context.afriL10n;
    final snapshot = challenges.valueOrNull;
    if (snapshot == null) return null;
    if (snapshot.mutationChallengeId != null) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-challenges-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.adminChallengesRetryingTitle,
        subtitle: l10n.adminChallengesRetryingMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    if (challenges.isLoading) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-challenges-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.adminChallengesRefreshingTitle,
        subtitle: l10n.adminChallengesRefreshingMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = snapshot.failure;
    if (snapshot.phase != AdminChallengesPhase.degraded || failure == null) {
      return null;
    }
    final uncertain = snapshot.mutationOutcomeUnconfirmed;
    return AfriStateBanner(
      key: ValueKey<String>('admin-challenges-state-${failure.kind.name}'),
      icon: failure.kind == AdminChallengesFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: failure.kind == AdminChallengesFailureKind.conflict
          ? l10n.adminChallengesStatusChanged
          : failure.kind == AdminChallengesFailureKind.securityTimeout
          ? l10n.adminSecurityTimeout
          : failure.kind == AdminChallengesFailureKind.offline
          ? l10n.adminChallengesOffline
          : l10n.adminCurrentRefreshUnavailable,
      subtitle: uncertain
          ? l10n.adminChallengesOutcomeUnconfirmed
          : l10n.adminChallengesLastConfirmedMessage,
      tone: AfriStateBannerTone.warning,
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.item,
    required this.enabled,
    required this.isMutating,
    required this.onRetry,
    this.retryFocusNode,
  });

  final AdminChallengeItem item;
  final bool enabled;
  final bool isMutating;
  final VoidCallback onRetry;
  final FocusNode? retryFocusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.competitionName,
                    style: TypographyTokens.titleSmall(),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                _OpsChip(label: item.status.toUpperCase()),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              context.afriL10n.adminVersus(item.homeTeam, item.awayTeam),
              style: TypographyTokens.titleMedium().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            _ChallengeMetrics(item: item),
            const SizedBox(height: SpacingTokens.spacing3),
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: [
                _OpsChip(
                  label: item.hasVoidReason
                      ? context.afriL10n.adminChallengesVoidReasonRecorded
                      : context.afriL10n.adminChallengesNoVoidReason,
                ),
                _OpsChip(
                  label: context.afriL10n.adminChallengesSettlementMode(
                    item.settlementMode,
                  ),
                ),
                _OpsChip(
                  label: context.afriL10n.adminChallengesAuditState(
                    item.settlementState,
                  ),
                ),
              ],
            ),
            if (item.canRetrySettlement) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              AfriButton(
                key: ValueKey<String>('admin-challenges-retry-${item.id}'),
                label: isMutating
                    ? context.afriL10n.adminChallengesRetryingAction
                    : context.afriL10n.adminChallengesRetryAction,
                labelMaxLines: 2,
                icon: AfriIcons.refresh,
                variant: AfriButtonVariant.secondary,
                enabled: enabled,
                isLoading: isMutating,
                focusNode: retryFocusNode,
                onTap: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChallengeMetrics extends StatelessWidget {
  const _ChallengeMetrics({required this.item});

  final AdminChallengeItem item;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.8;
    final metrics = <Widget>[
      _Metric(
        label: context.afriL10n.adminChallengesCreator,
        value: item.creatorName,
      ),
      _Metric(
        label: context.afriL10n.adminChallengesPool,
        value: '${item.totalPoolFet} FET',
      ),
      _Metric(
        label: context.afriL10n.adminChallengesParticipants,
        value: '${item.totalParticipants}',
      ),
    ];
    if (largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: metrics
            .map(
              (metric) => Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
                child: metric,
              ),
            )
            .toList(growable: false),
      );
    }
    return Wrap(
      spacing: SpacingTokens.spacing4,
      runSpacing: SpacingTokens.spacing2,
      children: metrics,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.afriL10n.adminMetricSemantic(label, value),
      child: ExcludeSemantics(
        child: Text(
          context.afriL10n.adminMetricSemantic(label, value),
          style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _OpsChip extends StatelessWidget {
  const _OpsChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: ShapeTokens.buttonRadius,
      ),
      child: Text(label.toUpperCase(), style: TypographyTokens.labelSmall()),
    );
  }
}

String _filterLabel(BuildContext context, AdminChallengeFilter filter) {
  final l10n = context.afriL10n;
  return switch (filter) {
    AdminChallengeFilter.all => l10n.adminChallengesFilterAll,
    AdminChallengeFilter.open => l10n.adminChallengesFilterOpen,
    AdminChallengeFilter.locked => l10n.adminChallengesFilterLocked,
    AdminChallengeFilter.settled => l10n.adminChallengesFilterSettled,
    AdminChallengeFilter.voided => l10n.adminChallengesFilterVoid,
  };
}
