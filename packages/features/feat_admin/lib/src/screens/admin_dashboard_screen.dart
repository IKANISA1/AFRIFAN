import 'dart:async';

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
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.loading(
                  key: const ValueKey<String>('admin-dashboard-state-loading'),
                  title: 'Loading admin workspace',
                  message: 'Checking current club operations.',
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
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
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
                  'CLUB ADMIN',
                  style: TypographyTokens.titleSmall().copyWith(
                    letterSpacing: 2,
                  ),
                ),
              ),
              AfriIconButton(
                icon: AfriIcons.close,
                onTap: () => context.pop(),
                tooltip: 'Exit Admin',
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            'COMMAND CENTER',
            style: TypographyTokens.displaySmall(
              ColorTokens.accessibleMetricColor(ColorTokens.clubAccent),
            ),
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
                'CLUB ADMIN',
                style: TypographyTokens.titleSmall().copyWith(letterSpacing: 2),
              ),
              Text(
                'COMMAND CENTER',
                style: TypographyTokens.displaySmall(
                  ColorTokens.accessibleMetricColor(ColorTokens.clubAccent),
                ),
              ),
            ],
          ),
        ),
        AfriIconButton(
          icon: AfriIcons.close,
          onTap: () => context.pop(),
          tooltip: 'Exit Admin',
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
              label: 'TOTAL USERS',
              value: '${snapshot.metrics.totalUsers}',
              icon: AfriIcons.people,
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            _MetricCard(
              label: 'ACTIVE GROUPS',
              value: '${snapshot.metrics.activeGroups}',
              icon: AfriIcons.groups,
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        Row(
          children: [
            _MetricCard(
              label: 'TX TODAY',
              value: '${snapshot.metrics.transactionsToday}',
              icon: AfriIcons.myPicks,
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            _MetricCard(
              label: 'TICKETS SOLD',
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
          'QUICK ACTIONS',
          style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        _AdminActionTile(
          route: '/admin/cms',
          title: 'Manage CMS',
          subtitle: 'News articles, banners, and content surfaces',
          icon: AfriIcons.article,
          enabled: enabled,
          focusNode: widget.firstActionFocusNode,
          selected:
              ref.watch(adminDashboardSelectedActionProvider) == '/admin/cms',
          onTap: () => _openAdminRoute('/admin/cms'),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        _AdminActionTile(
          route: '/admin/matches',
          title: 'Create Match',
          subtitle: 'Fixture setup, zoning, and ticket controls',
          icon: AfriIcons.predict,
          enabled: enabled,
          selected:
              ref.watch(adminDashboardSelectedActionProvider) ==
              '/admin/matches',
          onTap: () => _openAdminRoute('/admin/matches'),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        _AdminActionTile(
          route: '/admin/contributions',
          title: 'View Contributions',
          subtitle: 'Monitor club and community fundraising',
          icon: AfriIcons.contribute,
          enabled: enabled,
          selected:
              ref.watch(adminDashboardSelectedActionProvider) ==
              '/admin/contributions',
          onTap: () => _openAdminRoute('/admin/contributions'),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        _AdminActionTile(
          route: '/admin/notifications',
          title: 'Send Notification',
          subtitle: 'Tier, group, and all-fan push delivery',
          icon: AfriIcons.notificationsActive,
          enabled: enabled,
          selected:
              ref.watch(adminDashboardSelectedActionProvider) ==
              '/admin/notifications',
          onTap: () => _openAdminRoute('/admin/notifications'),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        _AdminActionTile(
          route: '/admin/settle',
          title: 'Settle Fixtures',
          subtitle: 'Enter results and grade prediction markets',
          icon: AfriIcons.scoreboard,
          enabled: enabled,
          selected:
              ref.watch(adminDashboardSelectedActionProvider) ==
              '/admin/settle',
          onTap: () => _openAdminRoute('/admin/settle'),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        _AdminActionTile(
          route: '/admin/competitions',
          title: 'Manage Competitions',
          subtitle: 'Add, edit, and toggle supported leagues and cups',
          icon: AfriIcons.rank,
          enabled: enabled,
          selected:
              ref.watch(adminDashboardSelectedActionProvider) ==
              '/admin/competitions',
          onTap: () => _openAdminRoute('/admin/competitions'),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        _AdminActionTile(
          route: '/admin/sms-monitor',
          title: 'SMS Sync Monitor',
          subtitle: 'MoMo SMS ingestion pipeline health',
          icon: AfriIcons.sms,
          enabled: enabled,
          selected:
              ref.watch(adminDashboardSelectedActionProvider) ==
              '/admin/sms-monitor',
          onTap: () => _openAdminRoute('/admin/sms-monitor'),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        _AdminActionTile(
          route: '/admin/features',
          title: 'Feature Manager',
          subtitle: 'Toggle features, visibility, and scheduling',
          icon: AfriIcons.settings,
          enabled: enabled,
          selected:
              ref.watch(adminDashboardSelectedActionProvider) ==
              '/admin/features',
          onTap: () => _openAdminRoute('/admin/features'),
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
            'RECENT ACTIVITY',
            style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (snapshot.activityUnavailable)
            const AfriStateBanner(
              key: ValueKey<String>('admin-dashboard-activity-unavailable'),
              icon: AfriIcons.statusWarning,
              title: 'Recent activity unavailable',
              subtitle:
                  'Dashboard totals are current. Refresh to retry the activity feed.',
              tone: AfriStateBannerTone.warning,
            )
          else if (snapshot.activity.isEmpty)
            AfriStateView.empty(
              key: const ValueKey<String>('admin-dashboard-state-empty'),
              title: 'No recent activity',
              message:
                  'Current totals are confirmed. New club activity will appear here.',
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
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-dashboard-state-disabled'),
        title: 'Admin workspace unavailable',
        message: 'Mobile administration is disabled for this controlled build.',
        icon: AfriIcons.lock,
        actionLabel: 'Back to settings',
        onAction: () => context.go('/settings'),
      ),
    );
  }

  Widget _buildUnavailable(AdminDashboardFailure failure) {
    final state = switch (failure.kind) {
      AdminDashboardFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-dashboard-state-offline'),
        title: 'Admin workspace offline',
        message: 'Reconnect before loading private club operations.',
        actionLabel: 'Try again',
        onAction: () =>
            unawaited(ref.read(adminDashboardProvider.notifier).refresh()),
      ),
      AdminDashboardFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-dashboard-state-permission-denied'),
        title: 'Admin access unavailable',
        message:
            'This account cannot view the current club administration workspace.',
        actionLabel: 'Back to settings',
        onAction: () => context.go('/settings'),
      ),
      AdminDashboardFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-dashboard-state-conflict'),
        title: 'Admin data changed',
        message: 'Refresh before continuing with current club operations.',
        actionLabel: 'Refresh',
        onAction: () =>
            unawaited(ref.read(adminDashboardProvider.notifier).refresh()),
      ),
      AdminDashboardFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-dashboard-state-security-timeout'),
        title: 'Security check timed out',
        message: 'No admin data was shown. Check your connection and retry.',
        actionLabel: 'Retry',
        onAction: () =>
            unawaited(ref.read(adminDashboardProvider.notifier).refresh()),
      ),
      AdminDashboardFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-dashboard-state-error'),
        title: 'Admin workspace unavailable',
        message: 'Private club data remains hidden. Try again.',
        actionLabel: 'Try again',
        onAction: () =>
            unawaited(ref.read(adminDashboardProvider.notifier).refresh()),
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: state,
    );
  }

  Widget? _buildStatusBanner(AsyncValue<AdminDashboardSnapshot> dashboard) {
    final snapshot = dashboard.valueOrNull;
    if (snapshot == null) return null;
    if (dashboard.isLoading) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-dashboard-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Refreshing admin workspace',
        subtitle:
            'Showing the last confirmed dashboard while current data is checked.',
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
          ? 'Admin data changed'
          : failure.kind == AdminDashboardFailureKind.securityTimeout
          ? 'Refresh timed out'
          : failure.kind == AdminDashboardFailureKind.offline
          ? 'Admin workspace offline'
          : 'Current refresh unavailable',
      subtitle:
          'Showing the last confirmed dashboard. Actions are paused until refresh succeeds.',
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
                color: ColorTokens.accessibleMetricColor(
                  ColorTokens.clubAccent,
                ),
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
        backgroundColor: selected
            ? ColorTokens.clubAccent.withValues(alpha: 0.14)
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
            Icon(
              icon,
              size: 24,
              color: ColorTokens.accessibleChartColor(ColorTokens.clubAccent),
            ),
            const SizedBox(width: SpacingTokens.spacing4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TypographyTokens.titleLarge().copyWith(
                      color: ColorTokens.onSurface,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(subtitle, style: TypographyTokens.bodyMedium()),
                ],
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing4),
            Icon(
              selected ? AfriIcons.statusSuccess : AfriIcons.forward,
              color: selected
                  ? ColorTokens.accessibleChartColor(ColorTokens.clubAccent)
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
