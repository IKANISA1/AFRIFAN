import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_competitions_controller.dart';

part '../widgets/competitions/competition_widgets.dart';

/// Controlled workspace for managing prediction competitions and seasons.
class CompetitionManagerScreen extends ConsumerWidget {
  const CompetitionManagerScreen({this.firstActionFocusNode, super.key});

  final FocusNode? firstActionFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(adminCompetitionsEnabledProvider);
    final competitions = ref.watch(adminCompetitionsProvider);
    final snapshot = competitions.valueOrNull;
    final denied =
        snapshot?.failure?.kind ==
        AdminCompetitionsFailureKind.permissionDenied;
    final controlsEnabled =
        enabled && snapshot?.actionsEnabled == true && !competitions.isLoading;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('COMPETITIONS', style: TypographyTokens.titleLarge()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
        actions: [
          AfriIconButton(
            key: const ValueKey<String>('admin-competitions-add'),
            icon: AfriIcons.add,
            onTap: controlsEnabled
                ? () => _openCompetitionForm(context, ref)
                : null,
            tooltip: controlsEnabled
                ? 'Add competition'
                : 'Competition actions unavailable',
          ),
        ],
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _disabled(context)
          : denied
          ? _unavailable(
              context,
              ref,
              const AdminCompetitionsFailure(
                AdminCompetitionsFailureKind.permissionDenied,
              ),
            )
          : competitions.isLoading && snapshot == null
          ? Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-competitions-state-loading'),
                title: 'Loading competitions',
                message: 'Checking the controlled competition workspace.',
              ),
            )
          : competitions.hasError && snapshot == null
          ? _unavailable(
              context,
              ref,
              AdminCompetitionsFailure.fromError(competitions.error!),
            )
          : _content(context, ref, competitions),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<AdminCompetitionsSnapshot> competitions,
  ) {
    final snapshot = competitions.requireValue;
    final visible = snapshot.visibleCompetitions;
    final controlsEnabled = snapshot.actionsEnabled && !competitions.isLoading;
    return AfriRefreshIndicator(
      onRefresh: ref.read(adminCompetitionsProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          if (_statusBanner(competitions) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            'Manage the competitions and seasons available to the prediction engine.',
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          _CompetitionStats(
            total: snapshot.competitions.length,
            active: snapshot.activeCount,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          _CompetitionFilters(
            snapshot: snapshot,
            enabled: controlsEnabled,
            onRegion: ref.read(adminCompetitionsProvider.notifier).selectRegion,
            onKind: ref.read(adminCompetitionsProvider.notifier).selectKind,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (visible.isEmpty)
            AfriStateView.empty(
              key: const ValueKey<String>('admin-competitions-state-empty'),
              title: snapshot.competitions.isEmpty
                  ? 'No competitions configured'
                  : 'No competitions match',
              message: snapshot.competitions.isEmpty
                  ? 'Create the first controlled competition when access is available.'
                  : 'Choose another region or competition kind.',
              compact: true,
              actionLabel: snapshot.competitions.isEmpty && controlsEnabled
                  ? 'Add competition'
                  : null,
              onAction: snapshot.competitions.isEmpty && controlsEnabled
                  ? () => _openCompetitionForm(context, ref)
                  : null,
            )
          else
            ...visible.indexed.map(
              (entry) => _CompetitionCard(
                item: entry.$2,
                enabled: controlsEnabled,
                primaryFocusNode: entry.$1 == 0 ? firstActionFocusNode : null,
                onSeasons: () => _openSeasonManager(context, ref, entry.$2),
                onEdit: () =>
                    _openCompetitionForm(context, ref, existing: entry.$2),
                onToggle: () =>
                    _confirmCompetitionToggle(context, ref, entry.$2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _disabled(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-competitions-state-disabled'),
        title: 'Competition management unavailable',
        message: 'Competition controls are disabled for this controlled build.',
        icon: AfriIcons.lock,
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(
    BuildContext context,
    WidgetRef ref,
    AdminCompetitionsFailure failure,
  ) {
    final view = switch (failure.kind) {
      AdminCompetitionsFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-competitions-state-offline'),
        title: 'Competition workspace offline',
        message: 'Reconnect before loading private competition records.',
        actionLabel: 'Try again',
        onAction: () =>
            unawaited(ref.read(adminCompetitionsProvider.notifier).refresh()),
      ),
      AdminCompetitionsFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-competitions-state-permission-denied',
        ),
        title: 'Competition access unavailable',
        message:
            'This account cannot view or change competition configuration.',
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
      AdminCompetitionsFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-competitions-state-conflict'),
        title: 'Competition data changed',
        message: 'Refresh before continuing with competition work.',
        actionLabel: 'Refresh',
        onAction: () =>
            unawaited(ref.read(adminCompetitionsProvider.notifier).refresh()),
      ),
      AdminCompetitionsFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-competitions-state-security-timeout',
        ),
        title: 'Security check timed out',
        message: 'No competition data was shown. Check your connection.',
        actionLabel: 'Retry',
        onAction: () =>
            unawaited(ref.read(adminCompetitionsProvider.notifier).refresh()),
      ),
      AdminCompetitionsFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-competitions-state-error'),
        title: 'Competition workspace unavailable',
        message: 'Private competition records remain hidden. Try again.',
        actionLabel: 'Try again',
        onAction: () =>
            unawaited(ref.read(adminCompetitionsProvider.notifier).refresh()),
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminCompetitionsSnapshot> value) {
    final snapshot = value.valueOrNull;
    if (snapshot == null) return null;
    if (snapshot.isMutating) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-competitions-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Updating competition workspace',
        subtitle: 'Controls are paused until the current result is confirmed.',
        tone: AfriStateBannerTone.info,
      );
    }
    if (value.isLoading) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-competitions-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Refreshing competitions',
        subtitle:
            'Showing the last confirmed records while current data is checked.',
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = snapshot.failure;
    if (snapshot.phase != AdminCompetitionsPhase.degraded || failure == null) {
      return null;
    }
    final uncertain = snapshot.mutationOutcomeUnconfirmed;
    return AfriStateBanner(
      key: ValueKey<String>('admin-competitions-state-${failure.kind.name}'),
      icon: failure.kind == AdminCompetitionsFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: failure.kind == AdminCompetitionsFailureKind.conflict
          ? 'Competition data changed'
          : failure.kind == AdminCompetitionsFailureKind.securityTimeout
          ? 'Security check timed out'
          : failure.kind == AdminCompetitionsFailureKind.offline
          ? 'Competition workspace offline'
          : 'Current refresh unavailable',
      subtitle: uncertain
          ? 'The update outcome is not confirmed. Refresh before taking another action.'
          : 'Showing the last confirmed records. Actions are paused until refresh succeeds.',
      tone: AfriStateBannerTone.warning,
    );
  }

  Future<void> _openCompetitionForm(
    BuildContext context,
    WidgetRef ref, {
    AdminCompetitionItem? existing,
  }) async {
    final payload = await showAfriBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CompetitionFormSheet(existing: existing),
    );
    if (payload == null || !context.mounted) return;
    final saved = await ref
        .read(adminCompetitionsProvider.notifier)
        .saveCompetition(payload, competitionId: existing?.id);
    if (!context.mounted) return;
    if (saved) {
      AfriToast.success(
        context,
        existing == null ? 'Competition created' : 'Competition updated',
      );
    }
  }

  Future<void> _openSeasonManager(
    BuildContext context,
    WidgetRef ref,
    AdminCompetitionItem competition,
  ) {
    return showAfriBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SeasonManagerSheet(competition: competition),
    );
  }

  Future<void> _confirmCompetitionToggle(
    BuildContext context,
    WidgetRef ref,
    AdminCompetitionItem competition,
  ) async {
    final activating = !competition.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AfriAlertDialog(
        title: Text(activating ? 'ACTIVATE COMPETITION?' : 'DEACTIVATE?'),
        content: Text(
          activating
              ? '${competition.name} will become available to configured prediction journeys.'
              : '${competition.name} will stop being available to configured prediction journeys.',
        ),
        actions: [
          AfriTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          AfriTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(activating ? 'ACTIVATE' : 'DEACTIVATE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final saved = await ref
        .read(adminCompetitionsProvider.notifier)
        .setCompetitionActive(competition.id, activating);
    if (!context.mounted || !saved) return;
    AfriToast.success(
      context,
      activating ? 'Competition activated' : 'Competition deactivated',
    );
  }
}

class _CompetitionStats extends StatelessWidget {
  const _CompetitionStats({required this.total, required this.active});

  final int total;
  final int active;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _StatCard(
        icon: AfriIcons.rank,
        label: 'TOTAL',
        value: '$total',
        valueColor: ColorTokens.clubAccent,
      ),
      _StatCard(
        icon: AfriIcons.statusSuccess,
        label: 'ACTIVE',
        value: '$active',
        valueColor: ColorTokens.success,
      ),
    ];
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.8) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
                child: card,
              ),
            )
            .toList(growable: false),
      );
    }
    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: SpacingTokens.spacing3),
        Expanded(child: cards[1]),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: ColorTokens.onSurfaceVariant),
              const SizedBox(width: SpacingTokens.spacing2),
              Text(label, style: TypographyTokens.labelSmall()),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            value,
            style: TypographyTokens.headlineLarge().copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _CompetitionFilters extends StatelessWidget {
  const _CompetitionFilters({
    required this.snapshot,
    required this.enabled,
    required this.onRegion,
    required this.onKind,
  });

  final AdminCompetitionsSnapshot snapshot;
  final bool enabled;
  final ValueChanged<AdminCompetitionRegionFilter> onRegion;
  final ValueChanged<AdminCompetitionKindFilter> onKind;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Competition filters',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REGION', style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminCompetitionRegionFilter.values
                .map(
                  (filter) => AfriChoiceChip(
                    selected: snapshot.regionFilter == filter,
                    label: Text(filter.label),
                    onSelected: enabled ? (_) => onRegion(filter) : null,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text('KIND', style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminCompetitionKindFilter.values
                .map(
                  (filter) => AfriChoiceChip(
                    selected: snapshot.kindFilter == filter,
                    label: Text(filter.label),
                    onSelected: enabled ? (_) => onKind(filter) : null,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({
    required this.item,
    required this.enabled,
    required this.onSeasons,
    required this.onEdit,
    required this.onToggle,
    this.primaryFocusNode,
  });

  final AdminCompetitionItem item;
  final bool enabled;
  final VoidCallback onSeasons;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final FocusNode? primaryFocusNode;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TypographyTokens.titleLarge().copyWith(
                          color: ColorTokens.onSurface,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing1),
                      Text(
                        item.shortName,
                        style: TypographyTokens.bodyMedium(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                _StatusBadge(isActive: item.isActive),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: [
                _InfoChip(
                  icon: AfriIcons.category,
                  label: item.kind.toUpperCase(),
                ),
                _InfoChip(
                  icon: AfriIcons.public,
                  label: item.region.toUpperCase(),
                ),
                if (item.countryName != null)
                  _InfoChip(
                    icon: AfriIcons.challenge,
                    label: item.countryName!,
                  ),
                if (item.organizer != null)
                  _InfoChip(icon: AfriIcons.business, label: item.organizer!),
              ],
            ),
            if (item.formatNotes != null) ...[
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                item.formatNotes!,
                style: TypographyTokens.bodySmall(),
                maxLines: MediaQuery.textScalerOf(context).scale(1) >= 1.8
                    ? 4
                    : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing3),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: [
                AfriTextIconButton(
                  key: ValueKey<String>(
                    'admin-competitions-seasons-${item.id}',
                  ),
                  focusNode: primaryFocusNode,
                  onPressed: enabled ? onSeasons : null,
                  icon: const Icon(AfriIcons.calendar, size: 16),
                  label: const Text('SEASONS'),
                  style: AfriTextButton.styleFrom(
                    foregroundColor: ColorTokens.onSurface,
                  ),
                ),
                AfriTextIconButton(
                  onPressed: enabled ? onEdit : null,
                  icon: const Icon(AfriIcons.edit, size: 16),
                  label: const Text('EDIT'),
                  style: AfriTextButton.styleFrom(
                    foregroundColor: ColorTokens.onSurface,
                  ),
                ),
                AfriTextIconButton(
                  onPressed: enabled ? onToggle : null,
                  icon: Icon(
                    item.isActive
                        ? AfriIcons.visibilityOff
                        : AfriIcons.visibility,
                    size: 16,
                  ),
                  label: Text(item.isActive ? 'DEACTIVATE' : 'ACTIVATE'),
                  style: AfriTextButton.styleFrom(
                    foregroundColor: item.isActive
                        ? ColorTokens.error
                        : ColorTokens.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
