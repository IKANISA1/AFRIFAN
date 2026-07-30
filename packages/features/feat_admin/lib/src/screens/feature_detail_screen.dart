import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_features_controller.dart';

/// Controlled editor for one platform feature and its channel/rule settings.
class FeatureDetailScreen extends ConsumerWidget {
  const FeatureDetailScreen({
    required this.featureKey,
    this.firstActionFocusNode,
    super.key,
  });

  final String featureKey;
  final FocusNode? firstActionFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(adminFeaturesEnabledProvider);
    final detail = ref.watch(adminFeatureDetailProvider(featureKey));
    final snapshot = detail.valueOrNull;
    final denied =
        snapshot?.failure?.kind == AdminFeaturesFailureKind.permissionDenied;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          snapshot?.feature?.displayName.toUpperCase() ?? 'FEATURE DETAIL',
          style: TypographyTokens.titleLarge(),
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
          : denied
          ? _unavailable(
              context,
              ref,
              const AdminFeaturesFailure(
                AdminFeaturesFailureKind.permissionDenied,
              ),
            )
          : detail.isLoading && snapshot == null
          ? Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.loading(
                key: const ValueKey<String>(
                  'admin-feature-detail-state-loading',
                ),
                title: 'Loading feature settings',
                message: 'Checking controlled channel and access rules.',
              ),
            )
          : detail.hasError && snapshot == null
          ? _unavailable(
              context,
              ref,
              AdminFeaturesFailure.fromError(detail.error!),
            )
          : _content(context, ref, detail),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<AdminFeatureDetailSnapshot> detail,
  ) {
    final snapshot = detail.requireValue;
    final feature = snapshot.feature;
    final controlsEnabled = snapshot.actionsEnabled && !detail.isLoading;
    if (feature == null) {
      return Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: AfriStateView.empty(
          key: const ValueKey<String>('admin-feature-detail-state-empty'),
          title: 'Feature not found',
          message: 'No confirmed feature matches this controlled route.',
          actionLabel: 'Back to features',
          onAction: () => context.pop(),
        ),
      );
    }

    final notifier = ref.read(adminFeatureDetailProvider(featureKey).notifier);
    return AfriRefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          if (_statusBanner(detail) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            feature.featureKey,
            style: TypographyTokens.labelMedium(ColorTokens.onSurfaceVariant),
          ),
          if (feature.description case final description?) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            Text(description, style: TypographyTokens.bodyMedium()),
          ],
          const SizedBox(height: SpacingTokens.spacing5),
          const _SectionTitle('GLOBAL STATE'),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriPressFeedback(
            key: const ValueKey<String>('admin-feature-detail-global-toggle'),
            onTap: controlsEnabled
                ? () => unawaited(notifier.setGlobalEnabled(!feature.isEnabled))
                : null,
            enabled: controlsEnabled,
            focusNode: firstActionFocusNode,
            tooltip: feature.isEnabled
                ? 'Disable ${feature.displayName}'
                : 'Enable ${feature.displayName}',
            semanticsLabel:
                '${feature.displayName} is ${feature.isEnabled ? 'enabled' : 'disabled'}',
            semanticsHint: 'Changes the global feature state',
            child: GlassCard(
              animate: false,
              child: Row(
                children: [
                  Icon(
                    feature.isEnabled
                        ? AfriIcons.statusSuccess
                        : AfriIcons.lock,
                    color: feature.isEnabled
                        ? ColorTokens.success
                        : ColorTokens.onSurfaceVariant,
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.isEnabled ? 'Enabled' : 'Disabled',
                          style: TypographyTokens.titleSmall(),
                        ),
                        Text(
                          feature.isEnabled
                              ? 'Tap to disable this feature globally'
                              : 'Tap to enable this feature globally',
                          style: TypographyTokens.bodySmall().copyWith(
                            color: ColorTokens.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    AfriIcons.chevronRight,
                    color: ColorTokens.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text('VISIBILITY', style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: const <String>['visible', 'hidden', 'maintenance']
                .map(
                  (visibility) => AfriChoiceChip(
                    key: ValueKey<String>(
                      'admin-feature-detail-visibility-$visibility',
                    ),
                    selected: feature.visibility == visibility,
                    label: Text(visibility.toUpperCase()),
                    onSelected: controlsEnabled
                        ? (_) => unawaited(notifier.setVisibility(visibility))
                        : null,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          const _SectionTitle('CHANNEL CONFIG'),
          const SizedBox(height: SpacingTokens.spacing3),
          if (feature.channels.isEmpty)
            AfriStateView.empty(
              title: 'No channel overrides',
              message: 'This feature uses its confirmed global state.',
              compact: true,
            )
          else
            ...feature.channels.map(
              (channel) => _ChannelCard(
                channel: channel,
                enabled: controlsEnabled,
                onUpdate: (updates) =>
                    unawaited(notifier.updateChannel(channel.channel, updates)),
              ),
            ),
          const SizedBox(height: SpacingTokens.spacing6),
          const _SectionTitle('SCHEDULING'),
          const SizedBox(height: SpacingTokens.spacing3),
          _ScheduleCard(
            rules: feature.rules,
            enabled: controlsEnabled,
            onPick: (field, current) =>
                _pickDateTime(context, current, (value) {
                  unawaited(
                    notifier.updateRules(<String, dynamic>{
                      field: value?.toUtc().toIso8601String(),
                    }),
                  );
                }),
            onClear: () => unawaited(
              notifier.updateRules(const <String, dynamic>{
                'schedule_start_at': null,
                'schedule_end_at': null,
              }),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          const _SectionTitle('ACCESS RULES'),
          const SizedBox(height: SpacingTokens.spacing3),
          GlassCard(
            animate: false,
            child: _ToggleRow(
              label: 'Authentication required',
              subtitle: 'Users must sign in before accessing this feature.',
              value: feature.rules?.authRequired ?? false,
              enabled: controlsEnabled,
              onChanged: (value) => unawaited(
                notifier.updateRules(<String, dynamic>{'auth_required': value}),
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing8),
        ],
      ),
    );
  }

  Future<void> _pickDateTime(
    BuildContext context,
    DateTime? initial,
    ValueChanged<DateTime?> onChanged,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial?.toLocal() ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: initial == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(initial.toLocal()),
    );
    if (!context.mounted || time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Widget _disabled(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-feature-detail-state-disabled'),
        title: 'Feature settings unavailable',
        message: 'Feature editing is disabled for this controlled build.',
        icon: AfriIcons.lock,
        actionLabel: 'Back to features',
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(
    BuildContext context,
    WidgetRef ref,
    AdminFeaturesFailure failure,
  ) {
    void retry() => unawaited(
      ref.read(adminFeatureDetailProvider(featureKey).notifier).refresh(),
    );
    final view = switch (failure.kind) {
      AdminFeaturesFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-feature-detail-state-offline'),
        title: 'Feature settings offline',
        message: 'Reconnect before loading private feature configuration.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
      AdminFeaturesFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-feature-detail-state-permission-denied',
        ),
        title: 'Feature access unavailable',
        message: 'This account cannot view or change feature settings.',
        actionLabel: 'Back to features',
        onAction: () => context.pop(),
      ),
      AdminFeaturesFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-feature-detail-state-conflict'),
        title: 'Feature settings changed',
        message: 'Refresh before making another feature change.',
        actionLabel: 'Refresh',
        onAction: retry,
      ),
      AdminFeaturesFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-feature-detail-state-security-timeout',
        ),
        title: 'Security check timed out',
        message: 'No feature settings were shown. Check your connection.',
        actionLabel: 'Retry',
        onAction: retry,
      ),
      AdminFeaturesFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-feature-detail-state-error'),
        title: 'Feature settings unavailable',
        message: 'Private feature settings remain hidden. Try again.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminFeatureDetailSnapshot> value) {
    final snapshot = value.valueOrNull;
    if (snapshot == null) return null;
    if (value.isLoading || snapshot.isMutating) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-feature-detail-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Checking feature settings',
        subtitle:
            'Showing the last confirmed state while current data is checked.',
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = snapshot.failure;
    if (snapshot.phase != AdminFeaturesPhase.degraded || failure == null) {
      return null;
    }
    return AfriStateBanner(
      key: ValueKey<String>('admin-feature-detail-state-${failure.kind.name}'),
      icon: failure.kind == AdminFeaturesFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: switch (failure.kind) {
        AdminFeaturesFailureKind.conflict => 'Feature settings changed',
        AdminFeaturesFailureKind.securityTimeout => 'Security check timed out',
        AdminFeaturesFailureKind.offline => 'Feature settings offline',
        _ => 'Feature settings unavailable',
      },
      subtitle: snapshot.mutationOutcomeUnconfirmed
          ? 'The last change is unconfirmed. Controls stay paused until refresh succeeds.'
          : 'Last confirmed settings remain visible. Controls are paused.',
      tone: AfriStateBannerTone.warning,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? ColorTokens.clubAccent
        : ColorTokens.onSurface;
    return Text(
      title,
      style: TypographyTokens.titleSmall().copyWith(
        color: color,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.channel,
    required this.enabled,
    required this.onUpdate,
  });

  final AdminManagedFeatureChannel channel;
  final bool enabled;
  final ValueChanged<Map<String, dynamic>> onUpdate;

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
              children: [
                Icon(
                  channel.channel == 'mobile'
                      ? AfriIcons.smartphone
                      : AfriIcons.public,
                  color: ColorTokens.onSurface,
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Text(
                  channel.channel.toUpperCase(),
                  style: TypographyTokens.titleSmall(),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            _ToggleRow(
              label: 'Enabled',
              subtitle: 'Feature is active on this channel.',
              value: channel.isEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  onUpdate(<String, dynamic>{'is_enabled': value}),
            ),
            const AfriDivider(color: ColorTokens.onDarkHairline),
            _ToggleRow(
              label: 'Visible',
              subtitle: 'Feature can be shown on this channel.',
              value: channel.isVisible,
              enabled: enabled,
              onChanged: (value) =>
                  onUpdate(<String, dynamic>{'is_visible': value}),
            ),
            const AfriDivider(color: ColorTokens.onDarkHairline),
            _ToggleRow(
              label: 'Show in navigation',
              subtitle: 'Include this feature in channel navigation.',
              value: channel.showInNavigation,
              enabled: enabled,
              onChanged: (value) =>
                  onUpdate(<String, dynamic>{'show_in_navigation': value}),
            ),
            const AfriDivider(color: ColorTokens.onDarkHairline),
            _ToggleRow(
              label: 'Show on home',
              subtitle: 'Include this feature on the channel home screen.',
              value: channel.showOnHome,
              enabled: enabled,
              onChanged: (value) =>
                  onUpdate(<String, dynamic>{'show_on_home': value}),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TypographyTokens.bodyMedium()),
                Text(
                  subtitle,
                  style: TypographyTokens.bodySmall().copyWith(
                    color: ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AfriSwitch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.rules,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final AdminManagedFeatureRules? rules;
  final bool enabled;
  final void Function(String field, DateTime? current) onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final start = rules?.scheduleStartAt;
    final end = rules?.scheduleEndAt;
    return GlassCard(
      animate: false,
      child: Column(
        children: [
          _dateRow(
            label: 'Available from',
            value: start,
            onTap: enabled ? () => onPick('schedule_start_at', start) : null,
          ),
          const AfriDivider(color: ColorTokens.onDarkHairline),
          _dateRow(
            label: 'Available until',
            value: end,
            onTap: enabled ? () => onPick('schedule_end_at', end) : null,
          ),
          if (start != null || end != null) ...[
            const AfriDivider(color: ColorTokens.onDarkHairline),
            Align(
              alignment: Alignment.centerRight,
              child: AfriTextButton(
                onPressed: enabled ? onClear : null,
                child: const Text('Clear schedule'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateRow({
    required String label,
    required DateTime? value,
    required VoidCallback? onTap,
  }) {
    final formatted = value == null
        ? 'Not set'
        : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return AfriPressFeedback(
      onTap: onTap,
      enabled: onTap != null,
      tooltip: 'Set $label',
      semanticsLabel: '$label: $formatted',
      semanticsHint: 'Opens date and time selection',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TypographyTokens.bodyMedium())),
            const SizedBox(width: SpacingTokens.spacing2),
            Text(
              formatted,
              style: TypographyTokens.bodySmall().copyWith(
                color: value == null
                    ? ColorTokens.onSurfaceVariant
                    : ColorTokens.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
