import 'dart:async';

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
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('SMS OPERATIONS', style: TypographyTokens.titleLarge()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
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
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-sms-state-loading'),
                title: 'Loading SMS operations',
                message: 'Checking controlled pipeline health information.',
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
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          children: [
            if (_statusBanner(monitor) case final banner?) ...[
              banner,
              const SizedBox(height: SpacingTokens.spacing4),
            ],
            AfriStateView.empty(
              key: const ValueKey<String>('admin-sms-state-empty'),
              title: 'No SMS operations history',
              message:
                  'No controlled health signals or synchronization runs are available yet.',
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
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
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
                  'CONTROLLED HEALTH VIEW',
                  style: TypographyTokens.labelLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  'Review device synchronization, message checks, contribution '
                  'matching, sender drift, retries, and privacy cleanup without '
                  'displaying message bodies or supporter identifiers.',
                  style: TypographyTokens.bodyMedium(),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          Text('PIPELINE HEALTH', style: TypographyTokens.titleMedium()),
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
            'RECENT DEVICE SYNCHRONIZATION',
            style: TypographyTokens.titleMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (snapshot.runs.isEmpty)
            AfriStateView.empty(
              title: 'No recent synchronization runs',
              message: 'The health summary remains available above.',
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
        semanticsLabel: '${metric.label}, ${metric.status}',
        semanticsHint: selected
            ? 'Collapse health details'
            : 'Expand health details',
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
                        metric.label.toUpperCase(),
                        style: TypographyTokens.titleMedium(),
                      ),
                    ),
                    _StatusChip(
                      label: metric.status.replaceAll('_', ' ').toUpperCase(),
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
                      'Last confirmed signal ${DateFormat('dd MMM yyyy, HH:mm').format(metric.lastSignalAt!.toLocal())}',
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
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-sms-state-disabled'),
        title: 'SMS operations unavailable',
        message: 'SMS operations monitoring is disabled for this build.',
        icon: AfriIcons.lock,
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(AdminSmsMonitorFailure failure) {
    void retry() =>
        unawaited(ref.read(adminSmsMonitorProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminSmsMonitorFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-sms-state-offline'),
        title: 'SMS operations offline',
        message: 'Reconnect before loading private operational information.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
      AdminSmsMonitorFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-sms-state-permission-denied'),
        title: 'SMS operations access unavailable',
        message: 'Platform administrator access is required for this view.',
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
      AdminSmsMonitorFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-sms-state-conflict'),
        title: 'SMS operations changed',
        message: 'Refresh before using this operational information.',
        actionLabel: 'Refresh',
        onAction: retry,
      ),
      AdminSmsMonitorFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-sms-state-security-timeout'),
        title: 'Security check timed out',
        message: 'No operational information was shown. Check your connection.',
        actionLabel: 'Retry',
        onAction: retry,
      ),
      AdminSmsMonitorFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-sms-state-error'),
        title: 'SMS operations unavailable',
        message: 'Private operational information remains hidden. Try again.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminSmsMonitorSnapshot> monitor) {
    final snapshot = monitor.valueOrNull;
    if (snapshot == null) return null;
    if (monitor.isLoading) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-sms-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Checking SMS operations',
        subtitle:
            'Showing the last confirmed state while current data is checked.',
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
        AdminSmsMonitorFailureKind.conflict => 'SMS operations changed',
        AdminSmsMonitorFailureKind.securityTimeout =>
          'Security check timed out',
        AdminSmsMonitorFailureKind.offline => 'SMS operations offline',
        _ => 'SMS operations unavailable',
      },
      subtitle:
          'Last confirmed operational information remains visible. Controls are paused.',
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
            style: TypographyTokens.headlineSmall(
              ColorTokens.accessibleMetricColor(ColorTokens.clubAccent),
            ),
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
      'initial_permission_grant' => 'INITIAL HISTORY',
      'manual' => 'MANUAL',
      _ => 'CONTROLLED',
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
                  '${run.status.replaceAll('_', ' ').toUpperCase()} • $triggerLabel',
                  style: TypographyTokens.bodyLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  '${run.scannedMessages} scanned • '
                  '${run.uploadedMessages} uploaded • '
                  '${run.duplicateMessages} duplicates',
                  style: TypographyTokens.bodySmall(),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  DateFormat(
                    'dd MMM yyyy, HH:mm',
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
