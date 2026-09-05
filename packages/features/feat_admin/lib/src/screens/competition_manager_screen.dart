import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
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
      title: context.afriL10n.adminCompetitionsTitle,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.adminBack,
        ),
        actions: [
          AfriIconButton(
            key: const ValueKey<String>('admin-competitions-add'),
            icon: AfriIcons.add,
            onTap: controlsEnabled
                ? () => _openCompetitionForm(context, ref)
                : null,
            tooltip: controlsEnabled
                ? context.afriL10n.adminCompetitionsAdd
                : context.afriL10n.adminCompetitionsActionsUnavailable,
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
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.spacing4,
              ),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-competitions-state-loading'),
                title: context.afriL10n.adminCompetitionsLoading,
                message: context.afriL10n.adminCompetitionsLoadingMessage,
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
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
        children: [
          if (_statusBanner(context, competitions) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            context.afriL10n.adminCompetitionsDescription,
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
                  ? context.afriL10n.adminCompetitionsNoneConfigured
                  : context.afriL10n.adminCompetitionsNoneMatch,
              message: snapshot.competitions.isEmpty
                  ? context.afriL10n.adminCompetitionsNoneConfiguredMessage
                  : context.afriL10n.adminCompetitionsNoneMatchMessage,
              compact: true,
              actionLabel: snapshot.competitions.isEmpty && controlsEnabled
                  ? context.afriL10n.adminCompetitionsAdd
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
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-competitions-state-disabled'),
        title: context.afriL10n.adminCompetitionsManagementUnavailable,
        message: context.afriL10n.adminCompetitionsControlsDisabled,
        icon: AfriIcons.lock,
        actionLabel: context.afriL10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(
    BuildContext context,
    WidgetRef ref,
    AdminCompetitionsFailure failure,
  ) {
    final l10n = context.afriL10n;
    final view = switch (failure.kind) {
      AdminCompetitionsFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-competitions-state-offline'),
        title: l10n.adminCompetitionsOffline,
        message: l10n.adminCompetitionsOfflineMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: () =>
            unawaited(ref.read(adminCompetitionsProvider.notifier).refresh()),
      ),
      AdminCompetitionsFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-competitions-state-permission-denied',
        ),
        title: l10n.adminCompetitionsAccessUnavailable,
        message: l10n.adminCompetitionsAccessMessage,
        actionLabel: l10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
      AdminCompetitionsFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-competitions-state-conflict'),
        title: l10n.adminCompetitionsDataChanged,
        message: l10n.adminCompetitionsDataChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: () =>
            unawaited(ref.read(adminCompetitionsProvider.notifier).refresh()),
      ),
      AdminCompetitionsFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-competitions-state-security-timeout',
        ),
        title: l10n.adminSecurityTimeout,
        message: l10n.adminCompetitionsSecurityMessage,
        actionLabel: l10n.retry,
        onAction: () =>
            unawaited(ref.read(adminCompetitionsProvider.notifier).refresh()),
      ),
      AdminCompetitionsFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-competitions-state-error'),
        title: l10n.adminCompetitionsWorkspaceUnavailable,
        message: l10n.adminCompetitionsHiddenMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: () =>
            unawaited(ref.read(adminCompetitionsProvider.notifier).refresh()),
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
      child: view,
    );
  }

  Widget? _statusBanner(
    BuildContext context,
    AsyncValue<AdminCompetitionsSnapshot> value,
  ) {
    final l10n = context.afriL10n;
    final snapshot = value.valueOrNull;
    if (snapshot == null) return null;
    if (snapshot.isMutating) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-competitions-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.adminCompetitionsUpdating,
        subtitle: l10n.adminCompetitionsUpdatingMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    if (value.isLoading) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-competitions-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.adminCompetitionsRefreshing,
        subtitle: l10n.adminCompetitionsRefreshingMessage,
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
          ? l10n.adminCompetitionsDataChanged
          : failure.kind == AdminCompetitionsFailureKind.securityTimeout
          ? l10n.adminSecurityTimeout
          : failure.kind == AdminCompetitionsFailureKind.offline
          ? l10n.adminCompetitionsOffline
          : l10n.adminCompetitionsCurrentRefreshUnavailable,
      subtitle: uncertain
          ? l10n.adminCompetitionsOutcomeUnconfirmed
          : l10n.adminCompetitionsLastConfirmed,
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
        existing == null
            ? context.afriL10n.adminCompetitionCreated
            : context.afriL10n.adminCompetitionUpdated,
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
        title: Text(
          activating
              ? context.afriL10n.adminCompetitionActivateQuestion
              : context.afriL10n.adminCompetitionDeactivateQuestion,
        ),
        content: Text(
          activating
              ? context.afriL10n.adminCompetitionActivateMessage(
                  competition.name,
                )
              : context.afriL10n.adminCompetitionDeactivateMessage(
                  competition.name,
                ),
        ),
        actions: [
          AfriTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.afriL10n.adminCancelUpper),
          ),
          AfriTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              activating
                  ? context.afriL10n.adminActivateUpper
                  : context.afriL10n.adminDeactivateUpper,
            ),
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
      activating
          ? context.afriL10n.adminCompetitionActivated
          : context.afriL10n.adminCompetitionDeactivated,
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
        label: context.afriL10n.adminCompetitionsTotal,
        value: '$total',
      ),
      _StatCard(
        icon: AfriIcons.statusSuccess,
        label: context.afriL10n.adminCompetitionsActive,
        value: '$active',
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
  });

  final IconData icon;
  final String label;
  final String value;

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
          Text(value, style: TypographyTokens.headlineLarge()),
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
      label: context.afriL10n.adminCompetitionFilters,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.afriL10n.adminCompetitionRegion,
            style: TypographyTokens.labelSmall(),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminCompetitionRegionFilter.values
                .map(
                  (filter) => AfriChoiceChip(
                    selected: snapshot.regionFilter == filter,
                    label: Text(_regionFilterLabel(context, filter)),
                    onSelected: enabled ? (_) => onRegion(filter) : null,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            context.afriL10n.adminCompetitionKind,
            style: TypographyTokens.labelSmall(),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminCompetitionKindFilter.values
                .map(
                  (filter) => AfriChoiceChip(
                    selected: snapshot.kindFilter == filter,
                    label: Text(_kindFilterLabel(context, filter)),
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
                  label: _competitionKindLabel(context, item.kind),
                ),
                _InfoChip(
                  icon: AfriIcons.public,
                  label: _competitionRegionLabel(context, item.region),
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
                  label: Text(context.afriL10n.adminCompetitionSeasons),
                  style: AfriTextButton.styleFrom(
                    foregroundColor: ColorTokens.onSurface,
                  ),
                ),
                AfriTextIconButton(
                  onPressed: enabled ? onEdit : null,
                  icon: const Icon(AfriIcons.edit, size: 16),
                  label: Text(context.afriL10n.adminEditUpper),
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
                  label: Text(
                    item.isActive
                        ? context.afriL10n.adminDeactivateUpper
                        : context.afriL10n.adminActivateUpper,
                  ),
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

String _regionFilterLabel(
  BuildContext context,
  AdminCompetitionRegionFilter filter,
) {
  final l10n = context.afriL10n;
  return switch (filter) {
    AdminCompetitionRegionFilter.all => l10n.adminCompetitionFilterAll,
    AdminCompetitionRegionFilter.africa => l10n.adminCompetitionRegionAfrica,
    AdminCompetitionRegionFilter.europe => l10n.adminCompetitionRegionEurope,
    AdminCompetitionRegionFilter.international =>
      l10n.adminCompetitionRegionInternational,
    AdminCompetitionRegionFilter.global => l10n.adminCompetitionRegionGlobal,
  };
}

String _kindFilterLabel(
  BuildContext context,
  AdminCompetitionKindFilter filter,
) {
  final l10n = context.afriL10n;
  return switch (filter) {
    AdminCompetitionKindFilter.all => l10n.adminCompetitionFilterAll,
    AdminCompetitionKindFilter.league => l10n.adminCompetitionKindLeague,
    AdminCompetitionKindFilter.cup => l10n.adminCompetitionKindCup,
    AdminCompetitionKindFilter.tournament =>
      l10n.adminCompetitionKindTournament,
  };
}

String _competitionKindLabel(BuildContext context, String kind) {
  final l10n = context.afriL10n;
  return switch (kind) {
    'league' => l10n.adminCompetitionKindLeague,
    'cup' => l10n.adminCompetitionKindCup,
    'tournament' => l10n.adminCompetitionKindTournament,
    _ => kind.toUpperCase(),
  };
}

String _competitionRegionLabel(BuildContext context, String region) {
  final l10n = context.afriL10n;
  return switch (region) {
    'africa' => l10n.adminCompetitionRegionAfrica,
    'europe' => l10n.adminCompetitionRegionEurope,
    'international' => l10n.adminCompetitionRegionInternational,
    'global' => l10n.adminCompetitionRegionGlobal,
    _ => region.toUpperCase(),
  };
}

String _seasonStatusLabel(BuildContext context, String status) {
  final l10n = context.afriL10n;
  return switch (status) {
    'planned' => l10n.adminSeasonStatusPlanned,
    'active' => l10n.adminSeasonStatusActive,
    'finished' => l10n.adminSeasonStatusFinished,
    'archived' => l10n.adminSeasonStatusArchived,
    _ => status.toUpperCase(),
  };
}
