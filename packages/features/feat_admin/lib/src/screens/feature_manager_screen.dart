import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_features_controller.dart';

/// Bounded, role-gated registry for platform feature controls.
class FeatureManagerScreen extends ConsumerWidget {
  const FeatureManagerScreen({this.firstActionFocusNode, super.key});

  final FocusNode? firstActionFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(adminFeaturesEnabledProvider);
    final features = ref.watch(adminFeaturesProvider);
    final snapshot = features.valueOrNull;
    final denied =
        snapshot?.failure?.kind == AdminFeaturesFailureKind.permissionDenied;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.adminFeatureManagerTitle,
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
          : features.isLoading && snapshot == null
          ? Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-features-state-loading'),
                title: context.afriL10n.adminFeatureRegistryLoading,
                message: context.afriL10n.adminFeatureRegistryLoadingMessage,
              ),
            )
          : features.hasError && snapshot == null
          ? _unavailable(
              context,
              ref,
              AdminFeaturesFailure.fromError(features.error!),
            )
          : _content(context, ref, features),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<AdminFeaturesSnapshot> features,
  ) {
    final snapshot = features.requireValue;
    final visible = snapshot.visibleFeatures;
    final controlsEnabled = snapshot.actionsEnabled && !features.isLoading;
    final metricColor = Theme.of(context).brightness == Brightness.dark
        ? ColorTokens.clubAccent
        : ColorTokens.onSurface;

    return AfriRefreshIndicator(
      onRefresh: ref.read(adminFeaturesProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          if (_statusBanner(context, features) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            context.afriL10n.adminFeatureManagerDescription,
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          GlassCard(
            animate: false,
            child: Wrap(
              spacing: SpacingTokens.spacing6,
              runSpacing: SpacingTokens.spacing3,
              children: [
                _Metric(
                  label: context.afriL10n.adminFeatureRegistered,
                  value: '${snapshot.features.length}',
                  color: metricColor,
                ),
                _Metric(
                  label: context.afriL10n.adminFeatureEnabledUpper,
                  value: '${snapshot.enabledCount}',
                  color: metricColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text(
            context.afriL10n.adminFeatureStatus,
            style: TypographyTokens.labelSmall(),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminFeatureStatusFilter.values
                .map(
                  (filter) => AfriChoiceChip(
                    selected: snapshot.filter == filter,
                    label: Text(_filterLabel(context, filter)),
                    onSelected: controlsEnabled
                        ? (_) => ref
                              .read(adminFeaturesProvider.notifier)
                              .selectFilter(filter)
                        : null,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (visible.isEmpty)
            AfriStateView.empty(
              key: const ValueKey<String>('admin-features-state-empty'),
              title: snapshot.features.isEmpty
                  ? context.afriL10n.adminFeatureNoneConfigured
                  : context.afriL10n.adminFeatureNoneMatch,
              message: snapshot.features.isEmpty
                  ? context.afriL10n.adminFeatureNoneConfiguredMessage
                  : context.afriL10n.adminFeatureNoneMatchMessage,
              compact: true,
            )
          else
            ...visible.indexed.map(
              (entry) => _FeatureCard(
                feature: entry.$2,
                enabled: controlsEnabled,
                focusNode: entry.$1 == 0 ? firstActionFocusNode : null,
                onOpen: () =>
                    context.push('/admin/features/${entry.$2.featureKey}'),
                onToggle: (value) => unawaited(
                  ref
                      .read(adminFeaturesProvider.notifier)
                      .setGlobalEnabled(entry.$2.id, value),
                ),
                onVisibility: (value) => unawaited(
                  ref
                      .read(adminFeaturesProvider.notifier)
                      .setVisibility(entry.$2.id, value),
                ),
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
        key: const ValueKey<String>('admin-features-state-disabled'),
        title: context.afriL10n.adminFeatureManagementUnavailable,
        message: context.afriL10n.adminFeatureControlsDisabled,
        icon: AfriIcons.lock,
        actionLabel: context.afriL10n.adminBackToAdmin,
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
    void retry() =>
        unawaited(ref.read(adminFeaturesProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminFeaturesFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-features-state-offline'),
        title: l10n.adminFeatureRegistryOffline,
        message: l10n.adminFeatureSettingsOfflineMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
      AdminFeaturesFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-features-state-permission-denied'),
        title: l10n.adminFeatureAccessUnavailable,
        message: l10n.adminFeatureConfigurationAccessMessage,
        actionLabel: l10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
      AdminFeaturesFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-features-state-conflict'),
        title: l10n.adminFeatureConfigurationChanged,
        message: l10n.adminFeatureConfigurationChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: retry,
      ),
      AdminFeaturesFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-features-state-security-timeout'),
        title: l10n.adminSecurityTimeout,
        message: l10n.adminFeatureConfigurationSecurityMessage,
        actionLabel: l10n.retry,
        onAction: retry,
      ),
      AdminFeaturesFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-features-state-error'),
        title: l10n.adminFeatureRegistryUnavailable,
        message: l10n.adminFeatureConfigurationHidden,
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
    AsyncValue<AdminFeaturesSnapshot> value,
  ) {
    final l10n = context.afriL10n;
    final snapshot = value.valueOrNull;
    if (snapshot == null) return null;
    if (value.isLoading || snapshot.isMutating) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-features-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.adminFeatureConfigurationChecking,
        subtitle: l10n.adminFeatureCheckingMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = snapshot.failure;
    if (snapshot.phase != AdminFeaturesPhase.degraded || failure == null) {
      return null;
    }
    return AfriStateBanner(
      key: ValueKey<String>('admin-features-state-${failure.kind.name}'),
      icon: failure.kind == AdminFeaturesFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: switch (failure.kind) {
        AdminFeaturesFailureKind.conflict =>
          l10n.adminFeatureConfigurationChanged,
        AdminFeaturesFailureKind.securityTimeout => l10n.adminSecurityTimeout,
        AdminFeaturesFailureKind.offline => l10n.adminFeatureRegistryOffline,
        _ => l10n.adminFeatureRegistryUnavailable,
      },
      subtitle: snapshot.mutationOutcomeUnconfirmed
          ? l10n.adminFeatureOutcomeUnconfirmed
          : l10n.adminFeatureConfigurationLastConfirmed,
      tone: AfriStateBannerTone.warning,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TypographyTokens.labelSmall()),
          Text(value, style: TypographyTokens.displayMedium(color)),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.feature,
    required this.enabled,
    required this.onOpen,
    required this.onToggle,
    required this.onVisibility,
    this.focusNode,
  });

  final AdminManagedFeature feature;
  final bool enabled;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onVisibility;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final visibilityColor = switch (feature.visibility) {
      'visible' => ColorTokens.success,
      'hidden' => ColorTokens.error,
      _ => ColorTokens.warning,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: AfriPressFeedback(
        key: ValueKey<String>('admin-feature-${feature.featureKey}'),
        onTap: enabled ? onOpen : null,
        focusNode: focusNode,
        enabled: enabled,
        tooltip: context.afriL10n.adminFeatureOpenTooltip(feature.displayName),
        semanticsLabel: context.afriL10n.adminFeatureSettingsSemantic(
          feature.displayName,
        ),
        semanticsHint: context.afriL10n.adminFeatureOpenSettingsHint,
        child: GlassCard(
          animate: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.displayName,
                          style: TypographyTokens.titleSmall(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing1),
                        Text(
                          feature.featureKey,
                          style: TypographyTokens.bodySmall().copyWith(
                            color: ColorTokens.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AfriSwitch(
                    value: feature.isEnabled,
                    onChanged: enabled ? onToggle : null,
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Wrap(
                spacing: SpacingTokens.spacing2,
                runSpacing: SpacingTokens.spacing2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AfriChip(
                    label: Text(
                      _visibilityLabel(context, feature.visibility),
                      style: TypographyTokens.labelSmall(visibilityColor),
                    ),
                    backgroundColor: visibilityColor.withValues(alpha: 0.12),
                    side: BorderTokens.side(
                      color: visibilityColor,
                      opacity: 0.4,
                    ),
                  ),
                  AfriPopupMenuButton<String>(
                    enabled: enabled,
                    tooltip: context.afriL10n
                        .adminFeatureChangeVisibilityTooltip(
                          feature.displayName,
                        ),
                    onSelected: onVisibility,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'visible',
                        child: Text(
                          context.afriL10n.adminFeatureVisibilityVisible,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'hidden',
                        child: Text(
                          context.afriL10n.adminFeatureVisibilityHidden,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'maintenance',
                        child: Text(
                          context.afriL10n.adminFeatureVisibilityMaintenance,
                        ),
                      ),
                    ],
                    child: Text(
                      context.afriL10n.adminFeatureChangeVisibility,
                      style: TypographyTokens.labelMedium(
                        enabled
                            ? ColorTokens.onSurface
                            : ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _filterLabel(BuildContext context, AdminFeatureStatusFilter filter) {
  final l10n = context.afriL10n;
  return switch (filter) {
    AdminFeatureStatusFilter.all => l10n.adminFeatureFilterAll,
    AdminFeatureStatusFilter.enabled => l10n.adminFeatureEnabledUpper,
    AdminFeatureStatusFilter.disabled => l10n.adminFeatureDisabledUpper,
  };
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
