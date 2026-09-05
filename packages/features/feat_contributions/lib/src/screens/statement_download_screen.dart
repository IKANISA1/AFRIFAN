import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
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
          ? context.afriL10n.contributionsEmptyCsvCopied
          : context.afriL10n.contributionsCsvCopied,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
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
              l10n.contributionsStatementTitle,
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
                    title: l10n.contributionsStatementLoadingTitle,
                    message: l10n.contributionsStatementLoadingMessage,
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
    final l10n = context.afriL10n;
    final failure = StatementFailure.fromError(error);
    final content = _StatementFailureContent.fromFailure(
      failure,
      isOnline,
      l10n,
    );
    final refresh = content.canRefresh ? () => unawaited(_refresh()) : null;
    return switch (failure.kind) {
      StatementFailureKind.offline => AfriStateView.offline(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? l10n.contributionsRefresh : null,
        onAction: refresh,
      ),
      StatementFailureKind.notFound => AfriStateView.empty(
        title: content.title,
        message: content.message,
        icon: AfriIcons.groups,
        actionLabel: l10n.contributionsBackToInitiative,
        onAction: _goBack,
      ),
      _ => AfriStateView.error(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? l10n.contributionsRefresh : null,
        onAction: refresh,
      ),
    };
  }

  Widget _buildStatement(
    StatementState state, {
    required bool isOnline,
    required bool configuredExportEnabled,
  }) {
    final l10n = context.afriL10n;
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
        AfriStateBanner(
          icon: AfriIcons.refresh,
          title: l10n.contributionsStatementRefreshingTitle,
          subtitle: l10n.contributionsStatementRefreshingMessage,
          tone: AfriStateBannerTone.info,
          compact: true,
        ),
      );
    } else if (!configuredExportEnabled) {
      children.add(
        AfriStateBanner(
          icon: AfriIcons.lock,
          title: l10n.contributionsStatementReadOnlyTitle,
          subtitle: l10n.contributionsStatementReadOnlyMessage,
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
      );
    } else if (!isOnline) {
      children.add(
        AfriStateBanner(
          icon: AfriIcons.offline,
          title: l10n.contributionsSavedStatementTitle,
          subtitle: l10n.contributionsSavedStatementMessage,
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
            label: l10n.contributionsRefreshStatementUpper,
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
            ? l10n.contributionsCopyCsvSemantic
            : l10n.contributionsExportUnavailableSemantic(
                _exportLabel(
                  state: state,
                  isOnline: isOnline,
                  configuredExportEnabled: configuredExportEnabled,
                ),
              ),
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
              label: l10n.contributionsFromUpper,
              value: state.from == null
                  ? l10n.contributionsAllTime
                  : DateFormat('dd MMM yyyy').format(state.from!),
              enabled: isOnline && !state.actionsBlocked,
              onTap: () => _pickDate(state, isFrom: true),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: _DateInputCard(
              label: l10n.contributionsToUpper,
              value: state.to == null
                  ? l10n.contributionsNow
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
            Text(
              l10n.contributionsSortUpper,
              style: TypographyTokens.labelSmall(),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: StatementSort.values
                  .map(
                    (sort) => AfriChoiceChip(
                      key: ValueKey<String>('statement-sort-${sort.name}'),
                      selected: state.sort == sort,
                      label: Text(_statementSortLabel(sort, l10n)),
                      tooltip: _statementSortLabel(sort, l10n),
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
      Row(
        children: [
          Expanded(
            child: _FormatCard(
              label: l10n.contributionsPdf,
              icon: AfriIcons.pdf,
              selected: false,
              enabled: false,
              helper: l10n.contributionsComingSoon,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: _FormatCard(
              label: l10n.contributionsCsv,
              icon: AfriIcons.excel,
              selected: true,
              enabled: true,
              helper: l10n.contributionsClipboard,
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
    final l10n = context.afriL10n;
    if (_isExporting) return l10n.contributionsCopyingCsv;
    if (!configuredExportEnabled) return l10n.contributionsExportDisabled;
    if (!isOnline) return l10n.connectionRequired;
    if (state.phase == StatementPhase.syncing) {
      return l10n.contributionsCheckingLatestEntries;
    }
    if (state.phase == StatementPhase.degraded) {
      return l10n.contributionsRefreshBeforeExporting;
    }
    return l10n.contributionsCopyCsvStatement;
  }

  String _statementSortLabel(StatementSort sort, AfriLocalizations l10n) =>
      switch (sort) {
        StatementSort.date => l10n.contributionsSortDate,
        StatementSort.amount => l10n.contributionsSortAmount,
        StatementSort.alias => l10n.contributionsSortAlias,
      };
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
    final l10n = context.afriL10n;
    final metricAccent = ColorTokens.accessibleMetricColor(
      ColorTokens.primaryContainer,
    );
    return GlassCard(
      key: const ValueKey<String>('statement-summary-card'),
      animate: false,
      child: Semantics(
        container: true,
        label: l10n.contributionsStatementSummarySemantic(
          groupName,
          entryCount,
          confirmedTotal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupName,
              style: TypographyTokens.headlineMedium().copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              l10n.contributionsConfirmedTotalUpper,
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              confirmedTotal,
              style: TypographyTokens.displayLarge(
                metricAccent,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              l10n.contributionsPublicEntriesInRange(entryCount),
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              l10n.contributionsStatementPrivacy,
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
        semanticsLabel: context.afriL10n.contributionsMetaSemantic(
          label,
          value,
        ),
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
      label: context.afriL10n.contributionsFormatSemantic(label, helper),
      child: GlassCard(
        animate: false,
        borderColor: selected
            ? ColorTokens.primary.withValues(alpha: 0.8)
            : ColorTokens.ghostBorder,
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? ColorTokens.accessibleChartColor(ColorTokens.primary)
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
    final l10n = context.afriL10n;
    return Column(
      key: const ValueKey<String>('statement-preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.contributionsPreviewUpper,
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: TypographyTokens.trackingNone,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          totalEntryCount > 5
              ? l10n.contributionsPreviewShowing(totalEntryCount)
              : l10n.contributionsPreviewPublicFields,
          style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (entries.isEmpty)
          AfriStateView.empty(
            key: const ValueKey<String>('statement-empty'),
            title: l10n.contributionsNoStatementEntriesTitle,
            message: l10n.contributionsNoStatementEntriesMessage,
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
    final l10n = context.afriL10n;
    final amount = currency.format(entry.amount);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final tone = switch (entry.status) {
      StatementEntryStatus.confirmed => AfriStatusTone.success,
      StatementEntryStatus.processing => AfriStatusTone.warning,
      StatementEntryStatus.failed => AfriStatusTone.error,
    };
    final statusLabel = switch (entry.status) {
      StatementEntryStatus.confirmed => l10n.contributionsStatusConfirmed,
      StatementEntryStatus.processing => l10n.contributionsStatusProcessing,
      StatementEntryStatus.failed => l10n.contributionsStatusFailed,
    };
    final date = AfriDateFormatter.formatDate(entry.createdAt);
    return GlassCard(
      animate: false,
      child: Semantics(
        container: true,
        label: l10n.contributionsLedgerEntrySemantic(
          entry.publicAlias,
          amount,
          statusLabel,
          date,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (largeText) ...[
              Text(entry.publicAlias, style: TypographyTokens.titleMedium()),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                amount,
                style: TypographyTokens.headlineMedium(
                  ColorTokens.accessibleMetricColor(
                    ColorTokens.primaryContainer,
                  ),
                ).copyWith(fontWeight: FontWeight.w600),
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
                          ColorTokens.primaryContainer,
                        ),
                      ).copyWith(fontWeight: FontWeight.w600),
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
                AfriStatusChip(label: statusLabel, tone: tone),
                Text(
                  date,
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
    AfriLocalizations l10n,
  ) {
    return switch (failure.kind) {
      StatementFailureKind.offline => _StatementFailureContent(
        title: isOnline
            ? l10n.contributionsConnectionRestoredTitle
            : l10n.contributionsStatementOfflineTitle,
        message: isOnline
            ? l10n.contributionsStatementRestoredMessage
            : l10n.contributionsStatementOfflineMessage,
        canRefresh: isOnline,
      ),
      StatementFailureKind.notFound => _StatementFailureContent(
        title: l10n.contributionsStatementNotFoundTitle,
        message: l10n.contributionsStatementNotFoundMessage,
        canRefresh: false,
      ),
      StatementFailureKind.permissionDenied => _StatementFailureContent(
        title: l10n.contributionsStatementUnavailableTitle,
        message: l10n.contributionsStatementAccessMessage,
        canRefresh: false,
      ),
      StatementFailureKind.conflict => _StatementFailureContent(
        title: l10n.contributionsStatementChangedTitle,
        message: l10n.contributionsStatementChangedMessage,
        canRefresh: true,
      ),
      StatementFailureKind.securityTimeout => _StatementFailureContent(
        title: l10n.contributionsStatementTimeoutTitle,
        message: l10n.contributionsStatementTimeoutMessage,
        canRefresh: true,
      ),
      StatementFailureKind.unknown => _StatementFailureContent(
        title: l10n.contributionsStatementUnavailableTitle,
        message: l10n.contributionsStatementUnavailableMessage,
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
    final content = _StatementFailureContent.fromFailure(
      failure,
      true,
      context.afriL10n,
    );
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
