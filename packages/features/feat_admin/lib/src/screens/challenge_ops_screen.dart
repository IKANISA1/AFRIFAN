import 'dart:async';

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
          'CHALLENGE OPS',
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
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
                title: 'Loading challenge operations',
                message: 'Checking current settlement work.',
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
          if (_statusBanner(challenges) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Semantics(
            container: true,
            label: 'Challenge status filter',
            child: Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: AdminChallengeFilter.values
                  .map(
                    (filter) => AfriChoiceChip(
                      selected: snapshot.filter == filter,
                      label: Text(filter.label),
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
              title: 'No challenge operations',
              message: snapshot.filter == AdminChallengeFilter.all
                  ? 'No challenges are currently queued.'
                  : 'No ${snapshot.filter.label.toLowerCase()} challenges are currently queued.',
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retry settlement?'),
        content: Text(
          'Recheck ${item.homeTeam} vs ${item.awayTeam}. '
          'Do not retry again until the refreshed status is confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(adminChallengesProvider.notifier)
        .retrySettlement(item.id);
    if (!context.mounted || result == null) return;
    if (result.status == 'pending') {
      AfriToast.info(
        context,
        'Settlement remains pending. Review the refreshed status.',
      );
    } else {
      AfriToast.success(context, 'Settlement status refreshed.');
    }
  }

  Widget _disabled(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-challenges-state-disabled'),
        title: 'Challenge operations unavailable',
        message:
            'Challenge settlement controls are disabled for this controlled build.',
        icon: AfriIcons.lock,
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(
    BuildContext context,
    WidgetRef ref,
    AdminChallengesFailure failure,
  ) {
    final view = switch (failure.kind) {
      AdminChallengesFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-challenges-state-offline'),
        title: 'Challenge operations offline',
        message: 'Reconnect before loading private settlement work.',
        actionLabel: 'Try again',
        onAction: () =>
            unawaited(ref.read(adminChallengesProvider.notifier).refresh()),
      ),
      AdminChallengesFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-challenges-state-permission-denied'),
        title: 'Challenge access unavailable',
        message:
            'This account cannot view or retry club challenge settlements.',
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
      AdminChallengesFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-challenges-state-conflict'),
        title: 'Challenge status changed',
        message: 'Refresh before continuing with settlement work.',
        actionLabel: 'Refresh',
        onAction: () =>
            unawaited(ref.read(adminChallengesProvider.notifier).refresh()),
      ),
      AdminChallengesFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-challenges-state-security-timeout'),
        title: 'Security check timed out',
        message:
            'No challenge data was shown. Check your connection and retry.',
        actionLabel: 'Retry',
        onAction: () =>
            unawaited(ref.read(adminChallengesProvider.notifier).refresh()),
      ),
      AdminChallengesFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-challenges-state-error'),
        title: 'Challenge operations unavailable',
        message: 'Private settlement data remains hidden. Try again.',
        actionLabel: 'Try again',
        onAction: () =>
            unawaited(ref.read(adminChallengesProvider.notifier).refresh()),
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminChallengesSnapshot> challenges) {
    final snapshot = challenges.valueOrNull;
    if (snapshot == null) return null;
    if (snapshot.mutationChallengeId != null) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-challenges-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Retrying settlement',
        subtitle: 'Controls are paused until the current result is confirmed.',
        tone: AfriStateBannerTone.info,
      );
    }
    if (challenges.isLoading) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-challenges-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Refreshing challenge operations',
        subtitle:
            'Showing the last confirmed list while current status is checked.',
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
          ? 'Challenge status changed'
          : failure.kind == AdminChallengesFailureKind.securityTimeout
          ? 'Security check timed out'
          : failure.kind == AdminChallengesFailureKind.offline
          ? 'Challenge operations offline'
          : 'Current refresh unavailable',
      subtitle: uncertain
          ? 'The retry outcome is not confirmed. Refresh before taking another action.'
          : 'Showing the last confirmed list. Actions are paused until refresh succeeds.',
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
              '${item.homeTeam} vs ${item.awayTeam}',
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
                      ? 'VOID REASON RECORDED'
                      : 'NO VOID REASON',
                ),
                _OpsChip(label: 'SETTLEMENT ${item.settlementMode}'),
                _OpsChip(label: 'AUDIT ${item.settlementState}'),
              ],
            ),
            if (item.canRetrySettlement) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              AfriButton(
                key: ValueKey<String>('admin-challenges-retry-${item.id}'),
                label: isMutating ? 'RETRYING SETTLEMENT' : 'RETRY SETTLEMENT',
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
      _Metric(label: 'CREATOR', value: item.creatorName),
      _Metric(label: 'POOL', value: '${item.totalPoolFet} FET'),
      _Metric(label: 'PARTICIPANTS', value: '${item.totalParticipants}'),
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
      label: '$label $value',
      child: ExcludeSemantics(
        child: Text(
          '$label  $value',
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
