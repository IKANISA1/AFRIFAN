import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
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
          snapshot?.feature?.displayName.toUpperCase() ??
              context.afriL10n.adminFeatureDetailTitle,
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
                title: context.afriL10n.adminFeatureLoadingTitle,
                message: context.afriL10n.adminFeatureLoadingMessage,
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
          title: context.afriL10n.adminFeatureNotFound,
          message: context.afriL10n.adminFeatureNotFoundMessage,
          actionLabel: context.afriL10n.adminBackToFeatures,
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
          if (_statusBanner(context, detail) case final banner?) ...[
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
          _SectionTitle(context.afriL10n.adminFeatureGlobalState),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriPressFeedback(
            key: const ValueKey<String>('admin-feature-detail-global-toggle'),
            onTap: controlsEnabled
                ? () => unawaited(notifier.setGlobalEnabled(!feature.isEnabled))
                : null,
            enabled: controlsEnabled,
            focusNode: firstActionFocusNode,
            tooltip: feature.isEnabled
                ? context.afriL10n.adminFeatureDisableTooltip(
                    feature.displayName,
                  )
                : context.afriL10n.adminFeatureEnableTooltip(
                    feature.displayName,
                  ),
            semanticsLabel: context.afriL10n.adminFeatureStateSemantic(
              feature.displayName,
              feature.isEnabled
                  ? context.afriL10n.adminFeatureEnabled
                  : context.afriL10n.adminFeatureDisabled,
            ),
            semanticsHint: context.afriL10n.adminFeatureChangesGlobalState,
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
                          feature.isEnabled
                              ? context.afriL10n.adminFeatureEnabled
                              : context.afriL10n.adminFeatureDisabled,
                          style: TypographyTokens.titleSmall(),
                        ),
                        Text(
                          feature.isEnabled
                              ? context.afriL10n.adminFeatureTapDisable
                              : context.afriL10n.adminFeatureTapEnable,
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
          Text(
            context.afriL10n.adminFeatureVisibility,
            style: TypographyTokens.labelSmall(),
          ),
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
                    label: Text(_visibilityLabel(context, visibility)),
                    onSelected: controlsEnabled
                        ? (_) => unawaited(notifier.setVisibility(visibility))
                        : null,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          _SectionTitle(context.afriL10n.adminFeatureChannelConfig),
          const SizedBox(height: SpacingTokens.spacing3),
          if (feature.channels.isEmpty)
            AfriStateView.empty(
              title: context.afriL10n.adminFeatureNoChannelOverrides,
              message: context.afriL10n.adminFeatureNoChannelOverridesMessage,
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
          _SectionTitle(context.afriL10n.adminFeatureScheduling),
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
          _SectionTitle(context.afriL10n.adminFeatureAccessRules),
          const SizedBox(height: SpacingTokens.spacing3),
          GlassCard(
            animate: false,
            child: _ToggleRow(
              label: context.afriL10n.adminFeatureAuthRequired,
              subtitle: context.afriL10n.adminFeatureAuthRequiredMessage,
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
        title: context.afriL10n.adminFeatureSettingsUnavailable,
        message: context.afriL10n.adminFeatureEditingDisabled,
        icon: AfriIcons.lock,
        actionLabel: context.afriL10n.adminBackToFeatures,
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(
    BuildContext context,
    WidgetRef ref,
    AdminFeaturesFailure failure,
  ) {
    final l10n = context.afriL10n;
    void retry() => unawaited(
      ref.read(adminFeatureDetailProvider(featureKey).notifier).refresh(),
    );
    final view = switch (failure.kind) {
      AdminFeaturesFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-feature-detail-state-offline'),
        title: l10n.adminFeatureSettingsOffline,
        message: l10n.adminFeatureSettingsOfflineMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
      AdminFeaturesFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-feature-detail-state-permission-denied',
        ),
        title: l10n.adminFeatureAccessUnavailable,
        message: l10n.adminFeatureAccessUnavailableMessage,
        actionLabel: l10n.adminBackToFeatures,
        onAction: () => context.pop(),
      ),
      AdminFeaturesFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-feature-detail-state-conflict'),
        title: l10n.adminFeatureSettingsChanged,
        message: l10n.adminFeatureSettingsChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: retry,
      ),
      AdminFeaturesFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-feature-detail-state-security-timeout',
        ),
        title: l10n.adminSecurityTimeout,
        message: l10n.adminFeatureSecurityTimeoutMessage,
        actionLabel: l10n.retry,
        onAction: retry,
      ),
      AdminFeaturesFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-feature-detail-state-error'),
        title: l10n.adminFeatureSettingsUnavailable,
        message: l10n.adminFeaturePrivateDataHidden,
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
    AsyncValue<AdminFeatureDetailSnapshot> value,
  ) {
    final l10n = context.afriL10n;
    final snapshot = value.valueOrNull;
    if (snapshot == null) return null;
    if (value.isLoading || snapshot.isMutating) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-feature-detail-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.adminFeatureCheckingTitle,
        subtitle: l10n.adminFeatureCheckingMessage,
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
        AdminFeaturesFailureKind.conflict => l10n.adminFeatureSettingsChanged,
        AdminFeaturesFailureKind.securityTimeout => l10n.adminSecurityTimeout,
        AdminFeaturesFailureKind.offline => l10n.adminFeatureSettingsOffline,
        _ => l10n.adminFeatureSettingsUnavailable,
      },
      subtitle: snapshot.mutationOutcomeUnconfirmed
          ? l10n.adminFeatureOutcomeUnconfirmed
          : l10n.adminFeatureLastConfirmed,
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
                  _channelLabel(context, channel.channel),
                  style: TypographyTokens.titleSmall(),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            _ToggleRow(
              label: context.afriL10n.adminFeatureChannelEnabled,
              subtitle: context.afriL10n.adminFeatureChannelEnabledMessage,
              value: channel.isEnabled,
              enabled: enabled,
              onChanged: (value) =>
                  onUpdate(<String, dynamic>{'is_enabled': value}),
            ),
            const AfriDivider(color: ColorTokens.onDarkHairline),
            _ToggleRow(
              label: context.afriL10n.adminFeatureChannelVisible,
              subtitle: context.afriL10n.adminFeatureChannelVisibleMessage,
              value: channel.isVisible,
              enabled: enabled,
              onChanged: (value) =>
                  onUpdate(<String, dynamic>{'is_visible': value}),
            ),
            const AfriDivider(color: ColorTokens.onDarkHairline),
            _ToggleRow(
              label: context.afriL10n.adminFeatureShowInNavigation,
              subtitle: context.afriL10n.adminFeatureShowInNavigationMessage,
              value: channel.showInNavigation,
              enabled: enabled,
              onChanged: (value) =>
                  onUpdate(<String, dynamic>{'show_in_navigation': value}),
            ),
            const AfriDivider(color: ColorTokens.onDarkHairline),
            _ToggleRow(
              label: context.afriL10n.adminFeatureShowOnHome,
              subtitle: context.afriL10n.adminFeatureShowOnHomeMessage,
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
            context: context,
            label: context.afriL10n.adminFeatureAvailableFrom,
            value: start,
            onTap: enabled ? () => onPick('schedule_start_at', start) : null,
          ),
          const AfriDivider(color: ColorTokens.onDarkHairline),
          _dateRow(
            context: context,
            label: context.afriL10n.adminFeatureAvailableUntil,
            value: end,
            onTap: enabled ? () => onPick('schedule_end_at', end) : null,
          ),
          if (start != null || end != null) ...[
            const AfriDivider(color: ColorTokens.onDarkHairline),
            Align(
              alignment: Alignment.centerRight,
              child: AfriTextButton(
                onPressed: enabled ? onClear : null,
                child: Text(context.afriL10n.adminFeatureClearSchedule),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateRow({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required VoidCallback? onTap,
  }) {
    final formatted = value == null
        ? context.afriL10n.adminFeatureNotSet
        : MaterialLocalizations.of(context).formatShortDate(value.toLocal());
    return AfriPressFeedback(
      onTap: onTap,
      enabled: onTap != null,
      tooltip: context.afriL10n.adminFeatureSetTooltip(label),
      semanticsLabel: context.afriL10n.adminFeatureDateSemantic(
        label,
        formatted,
      ),
      semanticsHint: context.afriL10n.adminFeatureOpenDateTime,
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

String _visibilityLabel(BuildContext context, String visibility) {
  final l10n = context.afriL10n;
  return switch (visibility) {
    'visible' => l10n.adminFeatureVisibilityVisible,
    'hidden' => l10n.adminFeatureVisibilityHidden,
    'maintenance' => l10n.adminFeatureVisibilityMaintenance,
    _ => visibility.toUpperCase(),
  };
}

String _channelLabel(BuildContext context, String channel) {
  final l10n = context.afriL10n;
  return switch (channel) {
    'mobile' => l10n.adminFeatureChannelMobile,
    'web' => l10n.adminFeatureChannelWeb,
    _ => channel.toUpperCase(),
  };
}
