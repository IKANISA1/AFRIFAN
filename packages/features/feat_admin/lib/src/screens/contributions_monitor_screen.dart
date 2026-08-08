import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../admin_contributions_controller.dart';

/// Privacy-minimized, bounded monitoring for contribution groups and totals.
class ContributionsMonitorScreen extends ConsumerWidget {
  const ContributionsMonitorScreen({
    this.firstActionFocusNode,
    this.referenceTime,
    super.key,
  });

  final FocusNode? firstActionFocusNode;

  /// Fixed only by deterministic state tests; production uses the current UTC
  /// month so the monitoring total rolls over at the correct boundary.
  @visibleForTesting
  final DateTime? referenceTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(adminContributionsEnabledProvider);
    final contributions = ref.watch(adminContributionsProvider);
    final snapshot = contributions.valueOrNull;
    final denied =
        snapshot?.failure?.kind ==
        AdminContributionsFailureKind.permissionDenied;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.adminContributionsTitle,
          style: TypographyTokens.titleLarge(),
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
          : denied
          ? _unavailable(
              context,
              ref,
              const AdminContributionsFailure(
                AdminContributionsFailureKind.permissionDenied,
              ),
            )
          : contributions.isLoading && snapshot == null
          ? Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.loading(
                key: const ValueKey<String>(
                  'admin-contributions-state-loading',
                ),
                title: context.afriL10n.adminContributionsLoading,
                message: context.afriL10n.adminContributionsLoadingMessage,
              ),
            )
          : contributions.hasError && snapshot == null
          ? _unavailable(
              context,
              ref,
              AdminContributionsFailure.fromError(contributions.error!),
            )
          : _content(context, ref, contributions),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<AdminContributionsSnapshot> contributions,
  ) {
    final snapshot = contributions.requireValue;
    final visible = snapshot.visibleGroups;
    final controlsEnabled =
        snapshot.controlsEnabled && !contributions.isLoading;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final currency = NumberFormat.decimalPattern(locale);
    final currencySymbol = context.afriCurrencySymbol;
    final metricColor = Theme.of(context).brightness == Brightness.dark
        ? ColorTokens.clubAccent
        : ColorTokens.onSurface;

    return AfriRefreshIndicator(
      onRefresh: ref.read(adminContributionsProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          if (_statusBanner(context, contributions) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            context.afriL10n.adminContributionsDescription,
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          GlassCard(
            animate: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.afriL10n.adminContributionsMonthlyTotal,
                  style: TypographyTokens.labelSmall(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  '$currencySymbol ${currency.format(snapshot.monthlyTotalAt(referenceTime ?? DateTime.now().toUtc()))}',
                  style: TypographyTokens.displayMedium(metricColor),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  context.afriL10n.adminContributionsSummary(
                    snapshot.groups.length,
                    snapshot.contributions.length,
                  ),
                  style: TypographyTokens.bodyMedium(),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          _ContributionFilters(
            snapshot: snapshot,
            enabled: controlsEnabled,
            onFilter: ref
                .read(adminContributionsProvider.notifier)
                .selectFilter,
            onSort: ref.read(adminContributionsProvider.notifier).selectSort,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (visible.isEmpty)
            AfriStateView.empty(
              key: const ValueKey<String>('admin-contributions-state-empty'),
              title: snapshot.groups.isEmpty
                  ? context.afriL10n.adminContributionsNoGroups
                  : context.afriL10n.adminContributionsNoMatch,
              message: snapshot.groups.isEmpty
                  ? context.afriL10n.adminContributionsNoGroupsMessage
                  : context.afriL10n.adminContributionsNoMatchMessage,
              compact: true,
            )
          else
            ...visible.indexed.map(
              (entry) => _ContributionGroupCard(
                item: entry.$2,
                recordCount: snapshot.recordCountFor(entry.$2.id),
                lastActivity: snapshot.lastActivityFor(entry.$2.id),
                currency: currency,
                currencySymbol: currencySymbol,
                metricColor: metricColor,
              ),
            ),
          const SizedBox(height: SpacingTokens.spacing3),
          SizedBox(
            width: double.infinity,
            child: AfriTextIconButton(
              key: const ValueKey<String>('admin-contributions-export'),
              icon: const Icon(AfriIcons.copy),
              label: Text(context.afriL10n.adminContributionsExport),
              focusNode: firstActionFocusNode,
              style: AfriTextButton.styleFrom(
                foregroundColor: ColorTokens.onSurface,
              ),
              onPressed: controlsEnabled && visible.isNotEmpty
                  ? () => unawaited(_export(context, snapshot))
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    AdminContributionsSnapshot snapshot,
  ) async {
    final rows = <String>[
      'name,type,total,target,records,status,last_activity',
      ...snapshot.visibleGroups.map((group) {
        final lastActivity = snapshot.lastActivityFor(group.id);
        return <String>[
          group.name,
          group.type,
          '${group.currentTotal}',
          '${group.targetAmount}',
          '${snapshot.recordCountFor(group.id)}',
          group.isClosed ? 'closed' : 'active',
          lastActivity?.toIso8601String() ?? '',
        ].map(_csvCell).join(',');
      }),
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!context.mounted) return;
    AfriToast.success(context, context.afriL10n.adminContributionsReportCopied);
  }

  static String _csvCell(String value) =>
      '"${value.replaceAll('"', '""').replaceAll(RegExp(r'[\\r\\n]+'), ' ')}"';

  Widget _disabled(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-contributions-state-disabled'),
        title: context.afriL10n.adminContributionsUnavailable,
        message: context.afriL10n.adminContributionsDisabled,
        icon: AfriIcons.lock,
        actionLabel: context.afriL10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(
    BuildContext context,
    WidgetRef ref,
    AdminContributionsFailure failure,
  ) {
    final l10n = context.afriL10n;
    void retry() =>
        unawaited(ref.read(adminContributionsProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminContributionsFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-contributions-state-offline'),
        title: l10n.adminContributionsOffline,
        message: l10n.adminContributionsOfflineMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
      AdminContributionsFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-contributions-state-permission-denied',
        ),
        title: l10n.adminContributionsAccessUnavailable,
        message: l10n.adminContributionsAccessMessage,
        actionLabel: l10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
      AdminContributionsFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-contributions-state-conflict'),
        title: l10n.adminContributionsDataChanged,
        message: l10n.adminContributionsDataChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: retry,
      ),
      AdminContributionsFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-contributions-state-security-timeout',
        ),
        title: l10n.adminSecurityTimeout,
        message: l10n.adminContributionsSecurityMessage,
        actionLabel: l10n.retry,
        onAction: retry,
      ),
      AdminContributionsFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-contributions-state-error'),
        title: l10n.adminContributionsUnavailable,
        message: l10n.adminContributionsHiddenMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: view,
    );
  }

  Widget? _statusBanner(
    BuildContext context,
    AsyncValue<AdminContributionsSnapshot> value,
  ) {
    final snapshot = value.valueOrNull;
    if (snapshot == null) return null;
    if (value.isLoading) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-contributions-state-syncing'),
        icon: AfriIcons.refresh,
        title: context.afriL10n.adminContributionsRefreshing,
        subtitle: context.afriL10n.adminContributionsRefreshingMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = snapshot.failure;
    if (snapshot.phase != AdminContributionsPhase.degraded || failure == null) {
      return null;
    }
    return AfriStateBanner(
      key: ValueKey<String>('admin-contributions-state-${failure.kind.name}'),
      icon: failure.kind == AdminContributionsFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: switch (failure.kind) {
        AdminContributionsFailureKind.conflict =>
          context.afriL10n.adminContributionsDataChanged,
        AdminContributionsFailureKind.securityTimeout =>
          context.afriL10n.adminSecurityTimeout,
        AdminContributionsFailureKind.offline =>
          context.afriL10n.adminContributionsOffline,
        _ => context.afriL10n.adminContributionsUnavailable,
      },
      subtitle: context.afriL10n.adminContributionsLastConfirmed,
      tone: AfriStateBannerTone.warning,
    );
  }
}

class _ContributionFilters extends StatelessWidget {
  const _ContributionFilters({
    required this.snapshot,
    required this.enabled,
    required this.onFilter,
    required this.onSort,
  });

  final AdminContributionsSnapshot snapshot;
  final bool enabled;
  final ValueChanged<AdminContributionGroupFilter> onFilter;
  final ValueChanged<AdminContributionSort> onSort;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.afriL10n.adminContributionsGroupType,
            style: TypographyTokens.labelSmall(),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminContributionGroupFilter.values
                .map(
                  (filter) => AfriChoiceChip(
                    selected: snapshot.filter == filter,
                    label: Text(_contributionFilterLabel(context, filter)),
                    onSelected: enabled ? (_) => onFilter(filter) : null,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            context.afriL10n.adminContributionsSort,
            style: TypographyTokens.labelSmall(),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminContributionSort.values
                .map(
                  (sort) => AfriChoiceChip(
                    selected: snapshot.sort == sort,
                    label: Text(_contributionSortLabel(context, sort)),
                    onSelected: enabled ? (_) => onSort(sort) : null,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ContributionGroupCard extends StatelessWidget {
  const _ContributionGroupCard({
    required this.item,
    required this.recordCount,
    required this.lastActivity,
    required this.currency,
    required this.currencySymbol,
    required this.metricColor,
  });

  final AdminContributionGroup item;
  final int recordCount;
  final DateTime? lastActivity;
  final NumberFormat currency;
  final String currencySymbol;
  final Color metricColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  item.name.toUpperCase(),
                  style: TypographyTokens.titleLarge().copyWith(
                    color: ColorTokens.onSurface,
                  ),
                ),
                _StateChip(
                  label: item.isClosed
                      ? context.afriL10n.adminContributionsClosed
                      : context.afriL10n.adminContributionsActive,
                  active: !item.isClosed,
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              item.type == 'project'
                  ? context.afriL10n.adminContributionsTeamProject
                  : context.afriL10n.adminContributionsCommunity,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              '$currencySymbol ${currency.format(item.currentTotal)}'
              '${item.targetAmount > 0 ? ' / $currencySymbol ${currency.format(item.targetAmount)}' : ''}',
              style: TypographyTokens.headlineLarge().copyWith(
                color: metricColor,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              context.afriL10n.adminContributionsRecordMembers(
                recordCount,
                item.memberCount,
              ),
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              lastActivity == null
                  ? context.afriL10n.adminContributionsActivityPending
                  : context.afriL10n.adminContributionsLastActivity(
                      DateFormat(
                        'dd MMM HH:mm',
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(lastActivity!.toLocal()),
                    ),
              style: TypographyTokens.bodySmall(),
            ),
          ],
        ),
      ),
    );
  }
}

String _contributionFilterLabel(
  BuildContext context,
  AdminContributionGroupFilter filter,
) {
  final l10n = context.afriL10n;
  return switch (filter) {
    AdminContributionGroupFilter.all => l10n.adminContributionsFilterAll,
    AdminContributionGroupFilter.projects =>
      l10n.adminContributionsTeamProjects,
    AdminContributionGroupFilter.community => l10n.adminContributionsCommunity,
  };
}

String _contributionSortLabel(
  BuildContext context,
  AdminContributionSort sort,
) {
  return switch (sort) {
    AdminContributionSort.recent => context.afriL10n.adminContributionsRecent,
    AdminContributionSort.total => context.afriL10n.adminContributionsTotal,
  };
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2,
      ),
      decoration: BoxDecoration(
        color: active
            ? ColorTokens.clubAccent.withValues(alpha: 0.15)
            : ColorTokens.surfaceContainerLow,
        borderRadius: ShapeTokens.buttonRadius,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TypographyTokens.labelSmall().copyWith(
          color: ColorTokens.onSurface,
        ),
      ),
    );
  }
}
