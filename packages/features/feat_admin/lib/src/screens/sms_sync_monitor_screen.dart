import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../admin_sms_monitor_controller.dart';

/// Privacy-minimized platform SMS operations monitor.
class SmsSyncMonitorScreen extends ConsumerStatefulWidget {
  const SmsSyncMonitorScreen({this.firstActionFocusNode, super.key});

  final FocusNode? firstActionFocusNode;

  @override
  ConsumerState<SmsSyncMonitorScreen> createState() =>
      _SmsSyncMonitorScreenState();
}

class _SmsSyncMonitorScreenState extends ConsumerState<SmsSyncMonitorScreen> {
  String? _selectedMetricKey;

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(adminSmsMonitorEnabledProvider);
    final monitor = ref.watch(adminSmsMonitorProvider);
    final snapshot = monitor.valueOrNull;
    final denied =
        snapshot?.failure?.kind == AdminSmsMonitorFailureKind.permissionDenied;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      title: context.afriL10n.adminSmsTitle,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.adminBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _disabled()
          : denied
          ? _unavailable(
              const AdminSmsMonitorFailure(
                AdminSmsMonitorFailureKind.permissionDenied,
              ),
            )
          : monitor.isLoading && snapshot == null
          ? Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.spacing4,
              ),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-sms-state-loading'),
                title: context.afriL10n.adminSmsLoading,
                message: context.afriL10n.adminSmsLoadingMessage,
              ),
            )
          : monitor.hasError && snapshot == null
          ? _unavailable(AdminSmsMonitorFailure.fromError(monitor.error!))
          : _content(monitor),
    );
  }

  Widget _content(AsyncValue<AdminSmsMonitorSnapshot> monitor) {
    final snapshot = monitor.requireValue;
    final controlsEnabled = snapshot.controlsEnabled && !monitor.isLoading;
    if (snapshot.metrics.isEmpty && snapshot.runs.isEmpty) {
      return AfriRefreshIndicator(
        onRefresh: ref.read(adminSmsMonitorProvider.notifier).refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
          children: [
            if (_statusBanner(monitor) case final banner?) ...[
              banner,
              const SizedBox(height: SpacingTokens.spacing4),
            ],
            AfriStateView.empty(
              key: const ValueKey<String>('admin-sms-state-empty'),
              title: context.afriL10n.adminSmsNoHistory,
              message: context.afriL10n.adminSmsNoHistoryMessage,
              compact: true,
            ),
          ],
        ),
      );
    }

    return AfriRefreshIndicator(
      onRefresh: ref.read(adminSmsMonitorProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
        children: [
          if (_statusBanner(monitor) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          GlassCard(
            animate: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.afriL10n.adminSmsControlledHealth,
                  style: TypographyTokens.labelLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  context.afriL10n.adminSmsControlledHealthMessage,
                  style: TypographyTokens.bodyMedium(),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          Text(
            context.afriL10n.adminSmsPipelineHealth,
            style: TypographyTokens.titleMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          ...snapshot.metrics.indexed.map(
            (entry) => _metricCard(
              entry.$2,
              controlsEnabled: controlsEnabled,
              focusNode: entry.$1 == 0 ? widget.firstActionFocusNode : null,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          Text(
            context.afriL10n.adminSmsRecentSync,
            style: TypographyTokens.titleMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (snapshot.runs.isEmpty)
            AfriStateView.empty(
              title: context.afriL10n.adminSmsNoRecentRuns,
              message: context.afriL10n.adminSmsNoRecentRunsMessage,
              compact: true,
            )
          else
            GlassCard(
              animate: false,
              child: Column(
                children: snapshot.runs
                    .map(
                      (run) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: SpacingTokens.spacing3,
                        ),
                        child: _SyncRunRow(run: run),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metricCard(
    AdminSmsHealthMetric metric, {
    required bool controlsEnabled,
    FocusNode? focusNode,
  }) {
    final selected = _selectedMetricKey == metric.key;
    final statusColor = _statusColor(metric.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: AfriPressFeedback(
        key: ValueKey<String>('admin-sms-metric-${metric.key}'),
        focusNode: focusNode,
        enabled: controlsEnabled,
        selected: selected,
        onTap: controlsEnabled
            ? () => setState(() {
                _selectedMetricKey = selected ? null : metric.key;
              })
            : null,
        semanticsLabel: context.afriL10n.adminSmsMetricSemantics(
          metric.label,
          _smsStatusLabel(context, metric.status),
        ),
        semanticsHint: selected
            ? context.afriL10n.adminSmsCollapseDetails
            : context.afriL10n.adminSmsExpandDetails,
        builder: (context, state) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: ShapeTokens.cardRadius,
            border: BorderTokens.all(
              color: state.isFocused || state.isPressed || selected
                  ? ColorTokens.primaryContainer
                  : ColorTokens.transparent,
              width: state.isFocused || state.isPressed || selected ? 2 : 0,
            ),
          ),
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
                        metric.label,
                        style: TypographyTokens.titleMedium(),
                      ),
                    ),
                    _StatusChip(
                      label: _smsStatusLabel(context, metric.status),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Wrap(
                  spacing: SpacingTokens.spacing4,
                  runSpacing: SpacingTokens.spacing3,
                  children: [
                    _MetricValue(
                      label: metric.primaryLabel,
                      value: metric.primaryValue,
                    ),
                    _MetricValue(
                      label: metric.secondaryLabel,
                      value: metric.secondaryValue,
                    ),
                    _MetricValue(
                      label: metric.tertiaryLabel,
                      value: metric.tertiaryValue,
                    ),
                  ],
                ),
                if (selected) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(metric.summary, style: TypographyTokens.bodyMedium()),
                  if (metric.lastSignalAt != null) ...[
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      context.afriL10n.adminSmsLastSignal(
                        DateFormat(
                          'dd MMM yyyy, HH:mm',
                          Localizations.localeOf(context).toLanguageTag(),
                        ).format(metric.lastSignalAt!.toLocal()),
                      ),
                      style: TypographyTokens.bodySmall(),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _disabled() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-sms-state-disabled'),
        title: context.afriL10n.adminSmsUnavailable,
        message: context.afriL10n.adminSmsDisabled,
        icon: AfriIcons.lock,
        actionLabel: context.afriL10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(AdminSmsMonitorFailure failure) {
    final l10n = context.afriL10n;
    void retry() =>
        unawaited(ref.read(adminSmsMonitorProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminSmsMonitorFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-sms-state-offline'),
        title: l10n.adminSmsOffline,
        message: l10n.adminSmsOfflineMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
      AdminSmsMonitorFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-sms-state-permission-denied'),
        title: l10n.adminSmsAccessUnavailable,
        message: l10n.adminSmsAccessMessage,
        actionLabel: l10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
      AdminSmsMonitorFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-sms-state-conflict'),
        title: l10n.adminSmsChanged,
        message: l10n.adminSmsChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: retry,
      ),
      AdminSmsMonitorFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-sms-state-security-timeout'),
        title: l10n.adminSecurityTimeout,
        message: l10n.adminSmsSecurityMessage,
        actionLabel: l10n.retry,
        onAction: retry,
      ),
      AdminSmsMonitorFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-sms-state-error'),
        title: l10n.adminSmsUnavailable,
        message: l10n.adminSmsHiddenMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminSmsMonitorSnapshot> monitor) {
    final snapshot = monitor.valueOrNull;
    if (snapshot == null) return null;
    if (monitor.isLoading) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-sms-state-syncing'),
        icon: AfriIcons.refresh,
        title: context.afriL10n.adminSmsChecking,
        subtitle: context.afriL10n.adminSmsCheckingMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = snapshot.failure;
    if (snapshot.phase != AdminSmsMonitorPhase.degraded || failure == null) {
      return null;
    }
    return AfriStateBanner(
      key: ValueKey<String>('admin-sms-state-${failure.kind.name}'),
      icon: failure.kind == AdminSmsMonitorFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: switch (failure.kind) {
        AdminSmsMonitorFailureKind.conflict => context.afriL10n.adminSmsChanged,
        AdminSmsMonitorFailureKind.securityTimeout =>
          context.afriL10n.adminSecurityTimeout,
        AdminSmsMonitorFailureKind.offline => context.afriL10n.adminSmsOffline,
        _ => context.afriL10n.adminSmsUnavailable,
      },
      subtitle: context.afriL10n.adminSmsLastConfirmed,
      tone: AfriStateBannerTone.warning,
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 88, maxWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TypographyTokens.headlineSmall(ColorTokens.onSurface),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(label, style: TypographyTokens.labelSmall()),
        ],
      ),
    );
  }
}

class _SyncRunRow extends StatelessWidget {
  const _SyncRunRow({required this.run});

  final AdminSmsSyncRun run;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(run.status);
    final triggerLabel = switch (run.trigger) {
      'initial_permission_grant' => context.afriL10n.adminSmsTriggerInitial,
      'manual' => context.afriL10n.adminSmsTriggerManual,
      _ => context.afriL10n.adminSmsTriggerControlled,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: ShapeTokens.inputRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: SpacingTokens.spacing1),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.afriL10n.adminSmsRunTitle(
                    _smsStatusLabel(context, run.status),
                    triggerLabel,
                  ),
                  style: TypographyTokens.bodyLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  context.afriL10n.adminSmsRunMetrics(
                    run.scannedMessages,
                    run.uploadedMessages,
                    run.duplicateMessages,
                  ),
                  style: TypographyTokens.bodySmall(),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  DateFormat(
                    'dd MMM yyyy, HH:mm',
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(run.startedAt.toLocal()),
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing1,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainer,
        borderRadius: ShapeTokens.buttonRadius,
        border: BorderTokens.all(
          color: color.withValues(alpha: 0.8),
          width: BorderTokens.standard,
        ),
      ),
      child: Text(label, style: TypographyTokens.labelSmall(color)),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    'healthy' || 'succeeded' => ColorTokens.success,
    'degraded' || 'running' || 'rate_limited' => ColorTokens.warning,
    'failing' || 'failed' => ColorTokens.error,
    _ => ColorTokens.onSurfaceVariant,
  };
}

String _smsStatusLabel(BuildContext context, String status) {
  final l10n = context.afriL10n;
  return switch (status) {
    'healthy' => l10n.adminSmsStatusHealthy,
    'succeeded' => l10n.adminSmsStatusSucceeded,
    'degraded' => l10n.adminSmsStatusDegraded,
    'running' => l10n.adminSmsStatusRunning,
    'rate_limited' => l10n.adminSmsStatusRateLimited,
    'failing' => l10n.adminSmsStatusFailing,
    'failed' => l10n.adminSmsStatusFailed,
    _ => status.replaceAll('_', ' ').toUpperCase(),
  };
}
