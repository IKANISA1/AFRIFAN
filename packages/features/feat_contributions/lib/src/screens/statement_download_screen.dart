import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../controllers/statement_controller.dart';

class StatementDownloadScreen extends ConsumerStatefulWidget {
  const StatementDownloadScreen({
    required this.groupId,
    this.exportActionFocusNode,
    super.key,
  });

  final String groupId;
  final FocusNode? exportActionFocusNode;

  @override
  ConsumerState<StatementDownloadScreen> createState() =>
      _StatementDownloadScreenState();
}

class _StatementDownloadScreenState
    extends ConsumerState<StatementDownloadScreen> {
  bool? _lastOnline;
  bool _isExporting = false;

  Future<void> _refresh() =>
      ref.read(statementProvider(widget.groupId).notifier).refresh();

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/contribute/group/${widget.groupId}');
    }
  }

  Future<void> _pickDate(StatementState state, {required bool isFrom}) async {
    final initialDate = isFrom
        ? (state.from ?? DateTime.now())
        : (state.to ?? state.from ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;

    var from = state.from;
    var to = state.to;
    if (isFrom) {
      from = picked;
      if (to != null && to.isBefore(from)) to = from;
    } else {
      to = picked;
      if (from != null && to.isBefore(from)) from = to;
    }
    await ref
        .read(statementProvider(widget.groupId).notifier)
        .setRange(from: from, to: to);
  }

  Future<void> _copyStatement(StatementState state) async {
    if (_isExporting || state.actionsBlocked) return;
    setState(() => _isExporting = true);
    final csv = buildStatementCsv(state);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    setState(() => _isExporting = false);
    AfriToast.success(
      context,
      state.snapshot.entries.isEmpty
          ? 'Empty CSV copied to clipboard.'
          : 'Privacy-safe CSV copied to clipboard.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final statementAsync = ref.watch(statementProvider(widget.groupId));
    final configuredExportEnabled = ref.watch(statementExportEnabledProvider);

    return ConnectivityBuilder(
      builder: (context, isOnline) {
        final previousOnline = _lastOnline;
        _lastOnline = isOnline;
        if (previousOnline == false && isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_refresh());
          });
        }

        return AfriScreenScaffold(
          backgroundColor: ColorTokens.background,
          appBar: AfriAppBar(
            backgroundColor: ColorTokens.transparent,
            title: Text(
              'PUBLIC STATEMENT',
              style: TypographyTokens.titleLarge(
                ColorTokens.chromeForeground,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            leading: AfriIconButton(
              icon: AfriIcons.back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: _goBack,
            ),
          ),
          scrollable: false,
          constrainContent: true,
          child: AfriRefreshIndicator(
            onRefresh: _refresh,
            child: statementAsync.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                children: [
                  AfriStateView.loading(
                    title: 'Loading public statement',
                    message:
                        'Checking confirmed contributions and privacy-safe supporter aliases.',
                  ),
                ],
              ),
              error: (error, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                children: [_buildFailure(error, isOnline)],
              ),
              data: (state) => _buildStatement(
                state,
                isOnline: isOnline,
                configuredExportEnabled: configuredExportEnabled,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFailure(Object error, bool isOnline) {
    final failure = StatementFailure.fromError(error);
    final content = _StatementFailureContent.fromFailure(failure, isOnline);
    final refresh = content.canRefresh ? () => unawaited(_refresh()) : null;
    return switch (failure.kind) {
      StatementFailureKind.offline => AfriStateView.offline(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? 'Refresh' : null,
        onAction: refresh,
      ),
      StatementFailureKind.notFound => AfriStateView.empty(
        title: content.title,
        message: content.message,
        icon: AfriIcons.groups,
        actionLabel: 'Back to initiative',
        onAction: _goBack,
      ),
      _ => AfriStateView.error(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? 'Refresh' : null,
        onAction: refresh,
      ),
    };
  }

  Widget _buildStatement(
    StatementState state, {
    required bool isOnline,
    required bool configuredExportEnabled,
  }) {
    final exportEnabled =
        configuredExportEnabled &&
        isOnline &&
        !state.actionsBlocked &&
        !_isExporting;
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );
    final entries = state.sortedEntries;
    final preview = entries.take(5).toList(growable: false);
    final children = <Widget>[];

    if (state.phase == StatementPhase.syncing) {
      children.add(
        const AfriStateBanner(
          icon: AfriIcons.refresh,
          title: 'Refreshing statement',
          subtitle:
              'Keeping the last confirmed statement visible while new activity is checked.',
          tone: AfriStateBannerTone.info,
          compact: true,
        ),
      );
    } else if (!configuredExportEnabled) {
      children.add(
        const AfriStateBanner(
          icon: AfriIcons.lock,
          title: 'Statement export is read-only',
          subtitle:
              'You can review confirmed public entries, but copying a statement is disabled for this build.',
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
      );
    } else if (!isOnline) {
      children.add(
        const AfriStateBanner(
          icon: AfriIcons.offline,
          title: 'Showing saved statement data',
          subtitle:
              'Reconnect and refresh before exporting or relying on the latest total.',
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
      );
    } else if (state.failure != null) {
      children.add(_RetainedStatementFailure(failure: state.failure!));
      if (state.failure!.kind != StatementFailureKind.permissionDenied) {
        children.add(const SizedBox(height: SpacingTokens.spacing3));
        children.add(
          AfriButton(
            key: const ValueKey<String>('statement-refresh-action'),
            label: 'REFRESH STATEMENT',
            icon: AfriIcons.refresh,
            variant: AfriButtonVariant.outline,
            labelMaxLines: 2,
            onTap: _refresh,
          ),
        );
      }
    }

    if (children.isNotEmpty) {
      children.add(const SizedBox(height: SpacingTokens.spacing4));
    }
    children.add(
      _StatementSummaryCard(
        groupName: state.snapshot.groupName,
        entryCount: entries.length,
        confirmedTotal: currency.format(state.confirmedTotal),
      ),
    );
    children.add(const SizedBox(height: SpacingTokens.spacing4));
    children.add(
      AfriButton(
        key: const ValueKey<String>('statement-export-action'),
        label: _exportLabel(
          state: state,
          isOnline: isOnline,
          configuredExportEnabled: configuredExportEnabled,
        ),
        semanticsLabel: exportEnabled
            ? 'Copy privacy-safe CSV statement'
            : 'Statement export unavailable. ${_exportLabel(state: state, isOnline: isOnline, configuredExportEnabled: configuredExportEnabled)}',
        icon: AfriIcons.excel,
        fullWidth: true,
        labelMaxLines: 2,
        isLoading: _isExporting,
        enabled: exportEnabled,
        focusNode: widget.exportActionFocusNode,
        onTap: () => _copyStatement(state),
      ),
    );
    children.add(const SizedBox(height: SpacingTokens.spacing5));
    children.add(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _DateInputCard(
              label: 'FROM',
              value: state.from == null
                  ? 'All time'
                  : DateFormat('dd MMM yyyy').format(state.from!),
              enabled: isOnline && !state.actionsBlocked,
              onTap: () => _pickDate(state, isFrom: true),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: _DateInputCard(
              label: 'TO',
              value: state.to == null
                  ? 'Now'
                  : DateFormat('dd MMM yyyy').format(state.to!),
              enabled: isOnline && !state.actionsBlocked,
              onTap: () => _pickDate(state, isFrom: false),
            ),
          ),
        ],
      ),
    );
    children.add(const SizedBox(height: SpacingTokens.spacing4));
    children.add(
      GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SORT', style: TypographyTokens.labelSmall()),
            const SizedBox(height: SpacingTokens.spacing2),
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: StatementSort.values
                  .map(
                    (sort) => AfriChoiceChip(
                      key: ValueKey<String>('statement-sort-${sort.name}'),
                      selected: state.sort == sort,
                      label: Text(sort.label),
                      tooltip: sort.label,
                      onSelected: state.actionsBlocked
                          ? null
                          : (_) => ref
                                .read(
                                  statementProvider(widget.groupId).notifier,
                                )
                                .setSort(sort),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
    children.add(const SizedBox(height: SpacingTokens.spacing4));
    children.add(
      const Row(
        children: [
          Expanded(
            child: _FormatCard(
              label: 'PDF',
              icon: AfriIcons.pdf,
              selected: false,
              enabled: false,
              helper: 'Coming soon',
            ),
          ),
          SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: _FormatCard(
              label: 'CSV',
              icon: AfriIcons.excel,
              selected: true,
              enabled: true,
              helper: 'Clipboard',
            ),
          ),
        ],
      ),
    );
    children.add(const SizedBox(height: SpacingTokens.spacing4));
    children.add(
      _StatementPreview(
        entries: preview,
        totalEntryCount: entries.length,
        currency: currency,
      ),
    );

    return ListView(
      key: const ValueKey<String>('statement-scroll-view'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(SpacingTokens.screenPadding),
      children: children,
    );
  }

  String _exportLabel({
    required StatementState state,
    required bool isOnline,
    required bool configuredExportEnabled,
  }) {
    if (_isExporting) return 'Copying CSV…';
    if (!configuredExportEnabled) return 'Export disabled';
    if (!isOnline) return 'Connection required';
    if (state.phase == StatementPhase.syncing) return 'Checking latest entries';
    if (state.phase == StatementPhase.degraded) {
      return 'Refresh before exporting';
    }
    return 'Copy CSV statement';
  }
}

class _StatementSummaryCard extends StatelessWidget {
  const _StatementSummaryCard({
    required this.groupName,
    required this.entryCount,
    required this.confirmedTotal,
  });

  final String groupName;
  final int entryCount;
  final String confirmedTotal;

  @override
  Widget build(BuildContext context) {
    final metricAccent = ColorTokens.accessibleMetricColor(
      ColorTokens.clubAccent,
    );
    return GlassCard(
      key: const ValueKey<String>('statement-summary-card'),
      animate: false,
      child: Semantics(
        container: true,
        label:
            '$groupName public statement, $entryCount entries, confirmed total $confirmedTotal',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupName,
              style: TypographyTokens.headlineMedium().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'CONFIRMED TOTAL',
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              confirmedTotal,
              style: TypographyTokens.displayLarge(
                metricAccent,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              '$entryCount public ${entryCount == 1 ? 'entry' : 'entries'} in this range',
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              'Public supporter aliases only. Names, phone numbers, payment references, and account identifiers are excluded.',
              style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateInputCard extends StatelessWidget {
  const _DateInputCard({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: AfriPressFeedback(
        onTap: onTap,
        enabled: enabled,
        tooltip: label,
        semanticsLabel: '$label, $value',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TypographyTokens.labelSmall()),
            const SizedBox(height: SpacingTokens.spacing2),
            Row(
              children: [
                Expanded(
                  child: Text(value, style: TypographyTokens.bodyMedium()),
                ),
                Icon(
                  AfriIcons.calendar,
                  size: 18,
                  color: enabled
                      ? ColorTokens.onSurface
                      : ColorTokens.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.helper,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      enabled: enabled,
      label: '$label export format, $helper',
      child: GlassCard(
        animate: false,
        borderColor: selected
            ? ColorTokens.clubPrimary.withValues(alpha: 0.8)
            : ColorTokens.ghostBorder,
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? ColorTokens.accessibleChartColor(ColorTokens.clubPrimary)
                  : ColorTokens.onSurfaceVariant,
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              label,
              style: TypographyTokens.headlineSmall().copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              helper,
              textAlign: TextAlign.center,
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatementPreview extends StatelessWidget {
  const _StatementPreview({
    required this.entries,
    required this.totalEntryCount,
    required this.currency,
  });

  final List<StatementEntry> entries;
  final int totalEntryCount;
  final CurrencyFormatter currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('statement-preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PREVIEW',
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          totalEntryCount > 5
              ? 'Showing 5 of $totalEntryCount entries. The CSV includes the full bounded range.'
              : 'The CSV includes only the public fields shown below.',
          style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (entries.isEmpty)
          AfriStateView.empty(
            key: const ValueKey<String>('statement-empty'),
            title: 'No statement entries',
            message:
                'No public contributions match this date range. Choose another range and refresh.',
            icon: AfriIcons.excel,
            compact: true,
          )
        else
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _StatementEntryRow(entry: entry, currency: currency),
            ),
          ),
      ],
    );
  }
}

class _StatementEntryRow extends StatelessWidget {
  const _StatementEntryRow({required this.entry, required this.currency});

  final StatementEntry entry;
  final CurrencyFormatter currency;

  @override
  Widget build(BuildContext context) {
    final amount = currency.format(entry.amount);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final tone = switch (entry.status) {
      StatementEntryStatus.confirmed => AfriStatusTone.success,
      StatementEntryStatus.processing => AfriStatusTone.warning,
      StatementEntryStatus.failed => AfriStatusTone.error,
    };
    return GlassCard(
      animate: false,
      child: Semantics(
        container: true,
        label:
            '${entry.publicAlias}, $amount, ${entry.status.label}, ${AfriDateFormatter.formatDate(entry.createdAt)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (largeText) ...[
              Text(entry.publicAlias, style: TypographyTokens.titleMedium()),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                amount,
                style: TypographyTokens.headlineMedium(
                  ColorTokens.accessibleMetricColor(ColorTokens.clubAccent),
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.publicAlias,
                      style: TypographyTokens.titleMedium(),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Flexible(
                    child: Text(
                      amount,
                      textAlign: TextAlign.end,
                      style: TypographyTokens.headlineMedium(
                        ColorTokens.accessibleMetricColor(
                          ColorTokens.clubAccent,
                        ),
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: SpacingTokens.spacing3),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: SpacingTokens.spacing3,
              runSpacing: SpacingTokens.spacing2,
              children: [
                AfriStatusChip(label: entry.status.label, tone: tone),
                Text(
                  AfriDateFormatter.formatDate(entry.createdAt),
                  style: TypographyTokens.bodySmall(
                    ColorTokens.onSurfaceVariant,
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

class _StatementFailureContent {
  const _StatementFailureContent({
    required this.title,
    required this.message,
    required this.canRefresh,
  });

  final String title;
  final String message;
  final bool canRefresh;

  factory _StatementFailureContent.fromFailure(
    StatementFailure failure,
    bool isOnline,
  ) {
    return switch (failure.kind) {
      StatementFailureKind.offline => _StatementFailureContent(
        title: isOnline ? 'Connection restored' : 'Statement offline',
        message: isOnline
            ? 'Refresh to check the latest confirmed public entries.'
            : 'Reconnect to load this public statement.',
        canRefresh: isOnline,
      ),
      StatementFailureKind.notFound => const _StatementFailureContent(
        title: 'Statement not found',
        message:
            'This initiative may have closed or the statement link may no longer be valid.',
        canRefresh: false,
      ),
      StatementFailureKind.permissionDenied => const _StatementFailureContent(
        title: 'Statement unavailable',
        message:
            'Your current club access does not allow this contribution statement.',
        canRefresh: false,
      ),
      StatementFailureKind.conflict => const _StatementFailureContent(
        title: 'Statement changed',
        message:
            'Refresh and review the latest confirmed entries before exporting.',
        canRefresh: true,
      ),
      StatementFailureKind.securityTimeout => const _StatementFailureContent(
        title: 'Statement check timed out',
        message:
            'No current statement was confirmed. Refresh before exporting.',
        canRefresh: true,
      ),
      StatementFailureKind.unknown => const _StatementFailureContent(
        title: 'Statement unavailable',
        message:
            'Refresh and try again when the public contribution ledger is available.',
        canRefresh: true,
      ),
    };
  }
}

class _RetainedStatementFailure extends StatelessWidget {
  const _RetainedStatementFailure({required this.failure});

  final StatementFailure failure;

  @override
  Widget build(BuildContext context) {
    final content = _StatementFailureContent.fromFailure(failure, true);
    return AfriStateBanner(
      icon: failure.kind == StatementFailureKind.permissionDenied
          ? AfriIcons.lock
          : AfriIcons.warning,
      title: content.title,
      subtitle: content.message,
      tone: AfriStateBannerTone.warning,
      compact: true,
    );
  }
}
