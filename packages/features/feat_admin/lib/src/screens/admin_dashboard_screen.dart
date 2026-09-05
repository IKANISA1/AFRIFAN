import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_dashboard_controller.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({this.firstActionFocusNode, super.key});

  final FocusNode? firstActionFocusNode;

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(adminDashboardEnabledProvider);
    final dashboard = ref.watch(adminDashboardProvider);
    final permissionDenied =
        dashboard.valueOrNull?.failure?.kind ==
        AdminDashboardFailureKind.permissionDenied;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      constrainContent: true,
      bodyWrapper: (child) => GradientBackground(child: child),
      child: SafeArea(
        child: !enabled
            ? _buildDisabled()
            : permissionDenied
            ? _buildUnavailable(
                const AdminDashboardFailure(
                  AdminDashboardFailureKind.permissionDenied,
                ),
              )
            : dashboard.isLoading && dashboard.valueOrNull == null
            ? Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing4),
                child: AfriStateView.loading(
                  key: const ValueKey<String>('admin-dashboard-state-loading'),
                  title: context.afriL10n.adminLoadingTitle,
                  message: context.afriL10n.adminLoadingMessage,
                ),
              )
            : dashboard.hasError && dashboard.valueOrNull == null
            ? _buildUnavailable(
                AdminDashboardFailure.fromError(dashboard.error!),
              )
            : AfriRefreshIndicator(
                onRefresh: ref.read(adminDashboardProvider.notifier).refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(SpacingTokens.spacing4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: SpacingTokens.spacing6),
                      if (_buildStatusBanner(dashboard) case final banner?) ...[
                        banner,
                        const SizedBox(height: SpacingTokens.spacing4),
                      ],
                      if (dashboard.valueOrNull case final snapshot?) ...[
                        _buildMetrics(snapshot),
                        const SizedBox(height: SpacingTokens.spacing6),
                        _buildQuickActions(
                          enabled:
                              snapshot.actionsEnabled && !dashboard.isLoading,
                        ),
                        const SizedBox(height: SpacingTokens.spacing6),
                        _buildRecentActivity(snapshot),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final usesLargeText = MediaQuery.textScalerOf(context).scale(1) >= 1.8;
    if (usesLargeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.afriL10n.adminClubAdmin,
                  style: TypographyTokens.titleSmall().copyWith(
                    letterSpacing: TypographyTokens.trackingNone,
                  ),
                ),
              ),
              AfriIconButton(
                icon: AfriIcons.close,
                onTap: () => context.pop(),
                tooltip: context.afriL10n.adminExit,
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            context.afriL10n.adminCommandCenter,
            style: TypographyTokens.displaySmall(ColorTokens.onSurface),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.afriL10n.adminClubAdmin,
                style: TypographyTokens.titleSmall().copyWith(
                  letterSpacing: TypographyTokens.trackingNone,
                ),
              ),
              Text(
                context.afriL10n.adminCommandCenter,
                style: TypographyTokens.displaySmall(ColorTokens.onSurface),
              ),
            ],
          ),
        ),
        AfriIconButton(
          icon: AfriIcons.close,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.adminExit,
        ),
      ],
    );
  }

  Widget _buildMetrics(AdminDashboardSnapshot snapshot) {
    return Column(
      children: [
        Row(
          children: [
            _MetricCard(
              label: context.afriL10n.adminTotalUsers,
              value: '${snapshot.metrics.totalUsers}',
              icon: AfriIcons.people,
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            _MetricCard(
              label: context.afriL10n.adminActiveGroups,
              value: '${snapshot.metrics.activeGroups}',
              icon: AfriIcons.groups,
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        Row(
          children: [
            _MetricCard(
              label: context.afriL10n.adminTransactionsToday,
              value: '${snapshot.metrics.transactionsToday}',
              icon: AfriIcons.myPicks,
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            _MetricCard(
              label: context.afriL10n.adminTicketsSold,
              value: '${snapshot.metrics.ticketsSold}',
              icon: AfriIcons.tickets,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions({required bool enabled}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.afriL10n.adminQuickActions,
          style: TypographyTokens.titleMedium().copyWith(
            letterSpacing: TypographyTokens.trackingNone,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        AfriListGroup(
          children: [
            _AdminActionTile(
              route: '/admin/cms',
              title: context.afriL10n.adminManageCms,
              subtitle: context.afriL10n.adminManageCmsDescription,
              icon: AfriIcons.article,
              enabled: enabled,
              focusNode: widget.firstActionFocusNode,
              selected:
                  ref.watch(adminDashboardSelectedActionProvider) ==
                  '/admin/cms',
              onTap: () => _openAdminRoute('/admin/cms'),
            ),
            _AdminActionTile(
              route: '/admin/matches',
              title: context.afriL10n.adminCreateMatch,
              subtitle: context.afriL10n.adminCreateMatchDescription,
              icon: AfriIcons.predict,
              enabled: enabled,
              selected:
                  ref.watch(adminDashboardSelectedActionProvider) ==
                  '/admin/matches',
              onTap: () => _openAdminRoute('/admin/matches'),
            ),
            _AdminActionTile(
              route: '/admin/contributions',
              title: context.afriL10n.adminViewContributions,
              subtitle: context.afriL10n.adminViewContributionsDescription,
              icon: AfriIcons.contribute,
              enabled: enabled,
              selected:
                  ref.watch(adminDashboardSelectedActionProvider) ==
                  '/admin/contributions',
              onTap: () => _openAdminRoute('/admin/contributions'),
            ),
            _AdminActionTile(
              route: '/admin/notifications',
              title: context.afriL10n.adminSendNotification,
              subtitle: context.afriL10n.adminSendNotificationDescription,
              icon: AfriIcons.notificationsActive,
              enabled: enabled,
              selected:
                  ref.watch(adminDashboardSelectedActionProvider) ==
                  '/admin/notifications',
              onTap: () => _openAdminRoute('/admin/notifications'),
            ),
            _AdminActionTile(
              route: '/admin/settle',
              title: context.afriL10n.adminSettleFixtures,
              subtitle: context.afriL10n.adminSettleFixturesDescription,
              icon: AfriIcons.scoreboard,
              enabled: enabled,
              selected:
                  ref.watch(adminDashboardSelectedActionProvider) ==
                  '/admin/settle',
              onTap: () => _openAdminRoute('/admin/settle'),
            ),
            _AdminActionTile(
              route: '/admin/competitions',
              title: context.afriL10n.adminManageCompetitions,
              subtitle: context.afriL10n.adminManageCompetitionsDescription,
              icon: AfriIcons.rank,
              enabled: enabled,
              selected:
                  ref.watch(adminDashboardSelectedActionProvider) ==
                  '/admin/competitions',
              onTap: () => _openAdminRoute('/admin/competitions'),
            ),
            _AdminActionTile(
              route: '/admin/sms-monitor',
              title: context.afriL10n.adminSmsSyncMonitor,
              subtitle: context.afriL10n.adminSmsSyncMonitorDescription,
              icon: AfriIcons.sms,
              enabled: enabled,
              selected:
                  ref.watch(adminDashboardSelectedActionProvider) ==
                  '/admin/sms-monitor',
              onTap: () => _openAdminRoute('/admin/sms-monitor'),
            ),
            _AdminActionTile(
              route: '/admin/features',
              title: context.afriL10n.adminFeatureManager,
              subtitle:
                  context.afriL10n.adminFeatureManagerDashboardDescription,
              icon: AfriIcons.settings,
              enabled: enabled,
              selected:
                  ref.watch(adminDashboardSelectedActionProvider) ==
                  '/admin/features',
              onTap: () => _openAdminRoute('/admin/features'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity(AdminDashboardSnapshot snapshot) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.afriL10n.adminRecentActivity,
            style: TypographyTokens.titleMedium().copyWith(
              letterSpacing: TypographyTokens.trackingNone,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (snapshot.activityUnavailable)
            AfriStateBanner(
              key: const ValueKey<String>(
                'admin-dashboard-activity-unavailable',
              ),
              icon: AfriIcons.statusWarning,
              title: context.afriL10n.adminRecentActivityUnavailable,
              subtitle: context.afriL10n.adminRecentActivityUnavailableMessage,
              tone: AfriStateBannerTone.warning,
            )
          else if (snapshot.activity.isEmpty)
            AfriStateView.empty(
              key: const ValueKey<String>('admin-dashboard-state-empty'),
              title: context.afriL10n.adminNoRecentActivity,
              message: context.afriL10n.adminNoRecentActivityMessage,
              compact: true,
            )
          else
            ...snapshot.activity.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
                child: _AdminFeedRow(title: item.title, meta: item.category),
              ),
            ),
        ],
      ),
    );
  }

  void _openAdminRoute(String route) {
    ref.read(adminDashboardSelectedActionProvider.notifier).state = route;
    unawaited(context.push(route));
  }

  Widget _buildDisabled() {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-dashboard-state-disabled'),
        title: context.afriL10n.adminWorkspaceUnavailable,
        message: context.afriL10n.adminMobileDisabledMessage,
        icon: AfriIcons.lock,
        actionLabel: context.afriL10n.adminBackToSettings,
        onAction: () => context.go('/settings'),
      ),
    );
  }

  Widget _buildUnavailable(AdminDashboardFailure failure) {
    final l10n = context.afriL10n;
    final state = switch (failure.kind) {
      AdminDashboardFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-dashboard-state-offline'),
        title: l10n.adminWorkspaceOffline,
        message: l10n.adminWorkspaceOfflineMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: () =>
            unawaited(ref.read(adminDashboardProvider.notifier).refresh()),
      ),
      AdminDashboardFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-dashboard-state-permission-denied'),
        title: l10n.adminAccessUnavailable,
        message: l10n.adminAccessUnavailableMessage,
        actionLabel: l10n.adminBackToSettings,
        onAction: () => context.go('/settings'),
      ),
      AdminDashboardFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-dashboard-state-conflict'),
        title: l10n.adminDataChanged,
        message: l10n.adminDataChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: () =>
            unawaited(ref.read(adminDashboardProvider.notifier).refresh()),
      ),
      AdminDashboardFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-dashboard-state-security-timeout'),
        title: l10n.adminSecurityTimeout,
        message: l10n.adminSecurityTimeoutMessage,
        actionLabel: l10n.retry,
        onAction: () =>
            unawaited(ref.read(adminDashboardProvider.notifier).refresh()),
      ),
      AdminDashboardFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-dashboard-state-error'),
        title: l10n.adminWorkspaceUnavailable,
        message: l10n.adminPrivateDataHiddenMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: () =>
            unawaited(ref.read(adminDashboardProvider.notifier).refresh()),
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: state,
    );
  }

  Widget? _buildStatusBanner(AsyncValue<AdminDashboardSnapshot> dashboard) {
    final l10n = context.afriL10n;
    final snapshot = dashboard.valueOrNull;
    if (snapshot == null) return null;
    if (dashboard.isLoading) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-dashboard-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.adminRefreshingTitle,
        subtitle: l10n.adminRefreshingMessage,
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = snapshot.failure;
    if (snapshot.phase != AdminDashboardPhase.degraded || failure == null) {
      return null;
    }
    return AfriStateBanner(
      key: ValueKey<String>('admin-dashboard-state-${failure.kind.name}'),
      icon: failure.kind == AdminDashboardFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: failure.kind == AdminDashboardFailureKind.conflict
          ? l10n.adminDataChanged
          : failure.kind == AdminDashboardFailureKind.securityTimeout
          ? l10n.adminRefreshTimedOut
          : failure.kind == AdminDashboardFailureKind.offline
          ? l10n.adminWorkspaceOffline
          : l10n.adminCurrentRefreshUnavailable,
      subtitle: l10n.adminLastConfirmedMessage,
      tone: AfriStateBannerTone.warning,
    );
  }
}

// ── Private Widgets ──

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: ColorTokens.onSurfaceVariant),
                const SizedBox(width: SpacingTokens.spacing2),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TypographyTokens.labelSmall(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              value,
              style: TypographyTokens.headlineLarge().copyWith(
                color: ColorTokens.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  const _AdminActionTile({
    required this.route,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.enabled,
    required this.selected,
    this.focusNode,
  });

  final String route;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool selected;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey<String>('admin-dashboard-action-$route'),
      selected: selected,
      child: AfriSurfaceCard(
        borderRadius: BorderRadius.zero,
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        backgroundColor: selected
            ? context.afriSemanticColors.cardSurfaceStrong
            : null,
        enabled: enabled,
        onTap: onTap,
        focusNode: focusNode,
        semanticsLabel: title,
        semanticsHint: enabled
            ? 'Opens the $title workspace'
            : 'Unavailable while dashboard data is being checked',
        child: Row(
          children: [
            Icon(icon, size: 24, color: ColorTokens.onSurface),
            const SizedBox(width: SpacingTokens.spacing4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TypographyTokens.bodyLarge().copyWith(
                      color: ColorTokens.onSurface,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    subtitle,
                    style: TypographyTokens.bodyMedium(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing4),
            Icon(
              selected ? AfriIcons.statusSuccess : AfriIcons.forward,
              color: selected
                  ? ColorTokens.accessibleChartColor(
                      ColorTokens.primaryContainer,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminFeedRow extends StatelessWidget {
  const _AdminFeedRow({required this.title, required this.meta});

  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: ShapeTokens.inputRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TypographyTokens.bodyLarge()),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(meta, style: TypographyTokens.bodySmall()),
        ],
      ),
    );
  }
}
