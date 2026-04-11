import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../repositories/admin_repository.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  AdminDashboardMetrics _metrics = const AdminDashboardMetrics();
  List<String> _activity = const <String>[];
  bool _isLoading = true;
  bool _isAuthorized = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final repo = ref.read(adminRepositoryProvider);

      // RBAC gate: verify admin access
      final isAdmin = await repo.isCurrentUserAdmin();
      if (!isAdmin) {
        if (!mounted) return;
        setState(() {
          _isAuthorized = false;
          _isLoading = false;
        });
        return;
      }

      final results = await Future.wait([
        repo.getDashboardMetrics(),
        repo.getRecentNewsTitles(),
        repo.getContributionGroups(limit: 3),
      ]);

      final metrics = results[0] as AdminDashboardMetrics;
      final newsTitles = results[1] as List<String>;
      final groups = results[2] as List<Map<String, dynamic>>;

      final activity = <String>[
        ...newsTitles.map((title) => 'CMS  •  $title'),
        ...groups.take(2).map((group) {
          final total = (group['current_total'] as num?)?.toInt() ?? 0;
          return 'CONTRIBUTIONS  •  ${group['name']?.toString() ?? 'Circle'} at FRw $total';
        }),
      ];

      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _activity = activity;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return _buildUnauthorized();
    }

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(SpacingTokens.spacing6),
                  child: AfriSkeletonList(),
                )
              : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: SpacingTokens.spacing6),
                        _buildMetrics(),
                        const SizedBox(height: SpacingTokens.spacing6),
                        _buildQuickActions(),
                        const SizedBox(height: SpacingTokens.spacing6),
                        _buildRecentActivity(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Exit Admin',
        ),
      ],
    );
  }

  Widget _buildMetrics() {
    return Column(
      children: [
        Row(
          children: [
            _MetricCard(
              label: 'TOTAL USERS',
              value: '${_metrics.totalUsers}',
              icon: Icons.people_alt_rounded,
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            _MetricCard(
              label: 'ACTIVE CIRCLES',
              value: '${_metrics.activeGroups}',
              icon: Icons.group_work_rounded,
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        Row(
          children: [
            _MetricCard(
              label: 'TX TODAY',
              value: '${_metrics.transactionsToday}',
              icon: Icons.receipt_long_rounded,
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            _MetricCard(
              label: 'TICKETS SOLD',
              value: '${_metrics.ticketsSold}',
              icon: Icons.confirmation_number_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        _AdminActionTile(
          title: 'Manage CMS',
          subtitle: 'News articles, banners, and content surfaces',
          icon: Icons.article_rounded,
          onTap: () => context.push('/admin/cms'),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        _AdminActionTile(
          title: 'Create Match',
          subtitle: 'Fixture setup, zoning, and ticket controls',
          icon: Icons.sports_soccer_rounded,
          onTap: () => context.push('/admin/matches'),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        _AdminActionTile(
          title: 'View Contributions',
          subtitle: 'Monitor club and community fundraising',
          icon: Icons.volunteer_activism_rounded,
          onTap: () => context.push('/admin/contributions'),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        _AdminActionTile(
          title: 'Send Notification',
          subtitle: 'Tier, group, and all-fan push delivery',
          icon: Icons.notifications_active_rounded,
          onTap: () => context.push('/admin/notifications'),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        _AdminActionTile(
          title: 'SMS Sync Monitor',
          subtitle: 'MoMo SMS ingestion pipeline health',
          icon: Icons.sms_rounded,
          onTap: () => context.push('/admin/sms-monitor'),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
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
          if (_activity.isEmpty)
            Text(
              'No recent admin activity is available yet.',
              style: TypographyTokens.bodyMedium(),
            )
          else
            ..._activity.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
                child: _AdminFeedRow(title: item, meta: 'LIVE DATA'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnauthorized() {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing8),
              child: GlassCard(
                animate: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 48,
                      color: ColorTokens.onSurfaceVariant,
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    Text(
                      'ACCESS DENIED',
                      style: TypographyTokens.headlineMedium().copyWith(
                        color: ColorTokens.onSurface,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Text(
                      'No admin privileges. Contact a club administrator.',
                      textAlign: TextAlign.center,
                      style: TypographyTokens.bodyMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing6),
                    ClaymorphicButton(
                      label: 'GO BACK',
                      width: double.infinity,
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: GlassCard(
          animate: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: ColorTokens.onSurfaceVariant,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                'Failed to load dashboard.',
                style: TypographyTokens.bodyLarge(),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              ClaymorphicButton(
                label: 'RETRY',
                width: double.infinity,
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadDashboard();
                },
              ),
            ],
          ),
        ),
      ),
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
                Text(label, style: TypographyTokens.labelSmall()),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              value,
              style: TypographyTokens.headlineLarge().copyWith(
                color: ColorTokens.clubAccent,
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
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
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
          const Icon(Icons.arrow_forward_rounded),
        ],
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
        borderRadius: BorderRadius.circular(16),
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
