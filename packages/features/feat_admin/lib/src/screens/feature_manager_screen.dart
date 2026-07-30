import 'dart:async';

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
        title: Text('FEATURE MANAGER', style: TypographyTokens.titleLarge()),
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
          : features.isLoading && snapshot == null
          ? Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-features-state-loading'),
                title: 'Loading feature registry',
                message: 'Checking controlled feature configuration.',
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
          if (_statusBanner(features) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          Text(
            'Control club-scoped feature availability with confirmed, bounded configuration.',
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
                  label: 'REGISTERED',
                  value: '${snapshot.features.length}',
                  color: metricColor,
                ),
                _Metric(
                  label: 'ENABLED',
                  value: '${snapshot.enabledCount}',
                  color: metricColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text('STATUS', style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: AdminFeatureStatusFilter.values
                .map(
                  (filter) => AfriChoiceChip(
                    selected: snapshot.filter == filter,
                    label: Text(filter.label),
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
                  ? 'No features configured'
                  : 'No features match',
              message: snapshot.features.isEmpty
                  ? 'Confirmed feature configuration will appear here.'
                  : 'Choose another status filter.',
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
        title: 'Feature management unavailable',
        message: 'Feature controls are disabled for this controlled build.',
        icon: AfriIcons.lock,
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(
    BuildContext context,
    WidgetRef ref,
    AdminFeaturesFailure failure,
  ) {
    void retry() =>
        unawaited(ref.read(adminFeaturesProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminFeaturesFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-features-state-offline'),
        title: 'Feature registry offline',
        message: 'Reconnect before loading private feature configuration.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
      AdminFeaturesFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-features-state-permission-denied'),
        title: 'Feature access unavailable',
        message: 'This account cannot view or change feature configuration.',
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
      AdminFeaturesFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-features-state-conflict'),
        title: 'Feature configuration changed',
        message: 'Refresh before making another feature change.',
        actionLabel: 'Refresh',
        onAction: retry,
      ),
      AdminFeaturesFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-features-state-security-timeout'),
        title: 'Security check timed out',
        message: 'No feature configuration was shown. Check your connection.',
        actionLabel: 'Retry',
        onAction: retry,
      ),
      AdminFeaturesFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-features-state-error'),
        title: 'Feature registry unavailable',
        message: 'Private feature configuration remains hidden. Try again.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminFeaturesSnapshot> value) {
    final snapshot = value.valueOrNull;
    if (snapshot == null) return null;
    if (value.isLoading || snapshot.isMutating) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-features-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Checking feature configuration',
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
      key: ValueKey<String>('admin-features-state-${failure.kind.name}'),
      icon: failure.kind == AdminFeaturesFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: switch (failure.kind) {
        AdminFeaturesFailureKind.conflict => 'Feature configuration changed',
        AdminFeaturesFailureKind.securityTimeout => 'Security check timed out',
        AdminFeaturesFailureKind.offline => 'Feature registry offline',
        _ => 'Feature registry unavailable',
      },
      subtitle: snapshot.mutationOutcomeUnconfirmed
          ? 'The last change is unconfirmed. Controls stay paused until refresh succeeds.'
          : 'Last confirmed configuration remains visible. Controls are paused.',
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
        tooltip: 'Open ${feature.displayName}',
        semanticsLabel: '${feature.displayName} feature settings',
        semanticsHint: 'Opens controlled feature settings',
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
                      feature.visibility.toUpperCase(),
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
                    tooltip: 'Change ${feature.displayName} visibility',
                    onSelected: onVisibility,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'visible', child: Text('Visible')),
                      PopupMenuItem(value: 'hidden', child: Text('Hidden')),
                      PopupMenuItem(
                        value: 'maintenance',
                        child: Text('Maintenance'),
                      ),
                    ],
                    child: Text(
                      'Change visibility',
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
