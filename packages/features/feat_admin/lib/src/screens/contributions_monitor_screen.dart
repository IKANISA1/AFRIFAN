import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../admin_contributions_controller.dart';

/// Privacy-minimized, bounded monitoring for contribution groups and totals.
class ContributionsMonitorScreen extends ConsumerWidget {
  const ContributionsMonitorScreen({this.firstActionFocusNode, super.key});

  final FocusNode? firstActionFocusNode;

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
        title: Text('CONTRIBUTIONS', style: TypographyTokens.titleLarge()),
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
                title: 'Loading contributions',
                message: 'Checking the controlled contribution monitor.',
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
    final currency = NumberFormat.decimalPattern();
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
          if (_statusBanner(contributions) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            'Review club-scoped group totals without exposing supporter or payment identifiers.',
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          GlassCard(
            animate: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL RECORDED THIS MONTH',
                  style: TypographyTokens.labelSmall(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  '$currencySymbol ${currency.format(snapshot.monthlyTotalAt(DateTime.now().toUtc()))}',
                  style: TypographyTokens.displayMedium(metricColor),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  '${snapshot.groups.length} groups • ${snapshot.contributions.length} bounded records',
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
                  ? 'No contribution groups'
                  : 'No groups match',
              message: snapshot.groups.isEmpty
                  ? 'Confirmed club-scoped contribution groups will appear here.'
                  : 'Choose another contribution group filter.',
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
              label: const Text('Export privacy-safe report'),
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
    AfriToast.success(context, 'Privacy-safe contribution report copied.');
  }

  static String _csvCell(String value) =>
      '"${value.replaceAll('"', '""').replaceAll(RegExp(r'[\\r\\n]+'), ' ')}"';

  Widget _disabled(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-contributions-state-disabled'),
        title: 'Contribution monitor unavailable',
        message:
            'Contribution monitoring is disabled for this controlled build.',
        icon: AfriIcons.lock,
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(
    BuildContext context,
    WidgetRef ref,
    AdminContributionsFailure failure,
  ) {
    void retry() =>
        unawaited(ref.read(adminContributionsProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminContributionsFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-contributions-state-offline'),
        title: 'Contribution monitor offline',
        message: 'Reconnect before loading private contribution records.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
      AdminContributionsFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-contributions-state-permission-denied',
        ),
        title: 'Contribution access unavailable',
        message: 'This account cannot view private contribution operations.',
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
      AdminContributionsFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-contributions-state-conflict'),
        title: 'Contribution data changed',
        message: 'Refresh before relying on contribution totals.',
        actionLabel: 'Refresh',
        onAction: retry,
      ),
      AdminContributionsFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-contributions-state-security-timeout',
        ),
        title: 'Security check timed out',
        message: 'No contribution records were shown. Check your connection.',
        actionLabel: 'Retry',
        onAction: retry,
      ),
      AdminContributionsFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-contributions-state-error'),
        title: 'Contribution monitor unavailable',
        message: 'Private contribution records remain hidden. Try again.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminContributionsSnapshot> value) {
    final snapshot = value.valueOrNull;
    if (snapshot == null) return null;
    if (value.isLoading) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-contributions-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Refreshing contributions',
        subtitle:
            'Showing the last confirmed totals while current data is checked.',
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
        AdminContributionsFailureKind.conflict => 'Contribution data changed',
        AdminContributionsFailureKind.securityTimeout =>
          'Security check timed out',
        AdminContributionsFailureKind.offline => 'Contribution monitor offline',
        _ => 'Contribution monitor unavailable',
      },
      subtitle:
          'Last confirmed totals remain visible. Controls are paused until refresh succeeds.',
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
          Text('GROUP TYPE', style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminContributionGroupFilter.values
                .map(
                  (filter) => AfriChoiceChip(
                    selected: snapshot.filter == filter,
                    label: Text(filter.label),
                    onSelected: enabled ? (_) => onFilter(filter) : null,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text('SORT', style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminContributionSort.values
                .map(
                  (sort) => AfriChoiceChip(
                    selected: snapshot.sort == sort,
                    label: Text(sort.label),
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
                  label: item.isClosed ? 'CLOSED' : 'ACTIVE',
                  active: !item.isClosed,
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              item.type == 'project' ? 'TEAM PROJECT' : 'COMMUNITY',
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
              '$recordCount bounded records • ${item.memberCount} registered members',
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              lastActivity == null
                  ? 'Payment activity pending'
                  : 'Last activity ${DateFormat('dd MMM HH:mm').format(lastActivity!.toLocal())}',
              style: TypographyTokens.bodySmall(),
            ),
          ],
        ),
      ),
    );
  }
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
