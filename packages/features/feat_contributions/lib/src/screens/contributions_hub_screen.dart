import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_sms_ledger/feat_sms_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/contribution_overlays.dart';

class ContributionsHubScreen extends ConsumerStatefulWidget {
  const ContributionsHubScreen({super.key});

  @override
  ConsumerState<ContributionsHubScreen> createState() =>
      _ContributionsHubScreenState();
}

class _ContributionsHubScreenState
    extends ConsumerState<ContributionsHubScreen> {
  List<Map<String, dynamic>> _groups = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _isUpdatingSmsSync = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await ref
          .read(clubRepositoryProvider)
          .getContributionGroups();
      final rows =
          groups
              .map(
                (group) => <String, dynamic>{
                  'id': group.id,
                  'name': group.name,
                  'description': group.description,
                  'current_total': group.currentTotal,
                  'target_amount': group.targetAmount,
                  'member_count': group.memberCount,
                  'privacy': group.privacy.name.replaceAll('_', ''),
                  'created_at': group.createdAt.toIso8601String(),
                },
              )
              .toList(growable: false)
            ..sort((left, right) {
              final rightCreated = DateTime.tryParse(
                right['created_at']?.toString() ?? '',
              );
              final leftCreated = DateTime.tryParse(
                left['created_at']?.toString() ?? '',
              );
              if (leftCreated == null || rightCreated == null) {
                return 0;
              }
              return rightCreated.compareTo(leftCreated);
            });

      if (!mounted) return;
      setState(() {
        _groups = rows.take(8).toList(growable: false);
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Contribution circles are temporarily unavailable.';
      });
    }
  }

  Future<void> _enableSmsSync() async {
    final confirmed = await showSmsPermissionModal(context);
    if (!confirmed || !mounted) return;

    setState(() => _isUpdatingSmsSync = true);
    try {
      final enabled = await ref
          .read(momoSmsAutoreadServiceProvider)
          .enable(onShowRationale: () async => true);
      ref.invalidate(momoSmsSyncEnabledProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'MoMo SMS sync enabled for this device.'
                : 'SMS access was not granted. Sync remains off.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not enable SMS sync. Check your permissions and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingSmsSync = false);
      }
    }
  }

  Future<void> _disableSmsSync() async {
    setState(() => _isUpdatingSmsSync = true);
    try {
      await ref.read(momoSmsAutoreadServiceProvider).disable();
      ref.invalidate(momoSmsSyncEnabledProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('MoMo SMS sync disabled.')));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingSmsSync = false);
      }
    }
  }

  Future<void> _runManualSmsSync() async {
    setState(() => _isUpdatingSmsSync = true);
    try {
      final result = await ref
          .read(momoSmsAutoreadServiceProvider)
          .syncInbox(trigger: MomoInboxSyncTrigger.manual);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SMS sync complete: ${result.uploadedMessages} uploaded, ${result.duplicateMessages} duplicates.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SMS sync failed. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingSmsSync = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );
    final smsSyncEnabledAsync = ref.watch(momoSmsSyncEnabledProvider);
    final smsSyncEnabled = smsSyncEnabledAsync.valueOrNull ?? false;
    const smsSyncAvailable = EnvConfig.enableAndroidMomoSmsAutoread;
    final totalRaised = _groups.fold<int>(
      0,
      (sum, group) => sum + ((group['current_total'] as num?)?.toInt() ?? 0),
    );
    final totalTarget = _groups.fold<int>(
      0,
      (sum, group) => sum + ((group['target_amount'] as num?)?.toInt() ?? 0),
    );
    final privateGroups = _groups.where((group) {
      final privacy = group['privacy']?.toString().toLowerCase();
      return privacy == 'private' || privacy == 'members';
    }).length;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            children: [
              // ── Header: back + title ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: ColorTokens.onSurface,
                    ),
                    tooltip: 'Back',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Text(
                      'CONTRIBUTE',
                      style: TypographyTokens.displaySmall(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              _HubCard(
                title: 'CLUB PROJECTS',
                subtitle: totalRaised == 0
                    ? 'No campaigns yet.'
                    : '${currency.format(totalRaised)} of ${currency.format(totalTarget)} raised.',
                accent: ColorTokens.clubPrimary,
                metricLabel: '${_groups.length} OPEN',
                onTap: () => context.push('/contribute/projects'),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              _HubCard(
                title: 'MY CIRCLES',
                subtitle: _groups.isEmpty
                    ? 'No circles yet.'
                    : '$_groupsCountLabel active.',
                accent: ColorTokens.success,
                metricLabel: '$privateGroups PRIVATE',
                onTap: () => context.push('/contribute/groups'),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              _HubCard(
                title: 'COMMUNITY',
                subtitle: _groups.isEmpty
                    ? 'No community activity yet.'
                    : 'Fan clubs & local chapters.',
                accent: ColorTokens.info,
                metricLabel: _groups.isEmpty ? 'QUIET' : 'LIVE',
                onTap: () => context.push('/fan-clubs'),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              GlassCard(
                animate: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MOMO SMS SYNC', style: TypographyTokens.labelLarge()),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      smsSyncAvailable
                          ? 'Auto-match MoMo receipts to contributions on this device.'
                          : 'SMS sync is unavailable in this build.',
                      style: TypographyTokens.bodyMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    if (!smsSyncAvailable)
                      Text(
                        'Release builds must enable this capability before supporters can opt in.',
                        style: TypographyTokens.bodySmall(
                          ColorTokens.onSurfaceVariant,
                        ),
                      )
                    else if (smsSyncEnabled) ...[
                      Text(
                        'Status: active for this device.',
                        style: TypographyTokens.bodySmall(
                          ColorTokens.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      ClaymorphicButton(
                        label: _isUpdatingSmsSync ? 'SYNCING...' : 'SYNC NOW',
                        width: double.infinity,
                        onPressed: _isUpdatingSmsSync
                            ? null
                            : _runManualSmsSync,
                      ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      OutlinedButton(
                        onPressed: _isUpdatingSmsSync ? null : _disableSmsSync,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('DISABLE SMS SYNC'),
                      ),
                    ] else
                      OutlinedButton(
                        onPressed: _isUpdatingSmsSync ? null : _enableSmsSync,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          _isUpdatingSmsSync
                              ? 'ENABLING...'
                              : 'ENABLE SMS SYNC',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              GlassCard(
                animate: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE CIRCLES',
                      style: TypographyTokens.monolithFont(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ColorTokens.onSurface,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    if (_isLoading)
                      const AfriSkeletonList()
                    else if (_error != null)
                      AfriStateView.offline(
                        title: 'Circles unavailable',
                        message: _error!,
                        actionLabel: 'Retry',
                        onAction: _loadGroups,
                        compact: true,
                      )
                    else if (_groups.isEmpty)
                      Text(
                        'No circles yet.',
                        style: TypographyTokens.bodyMedium(),
                      )
                    else
                      ..._groups.take(3).map((group) {
                        final groupId = group['id']?.toString() ?? '';
                        final name = group['name']?.toString() ?? 'Circle';
                        final currentTotal =
                            (group['current_total'] as num?)?.toInt() ?? 0;
                        final targetAmount =
                            (group['target_amount'] as num?)?.toInt() ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.spacing3,
                          ),
                          child: InkWell(
                            onTap: () =>
                                context.push('/contribute/group/$groupId'),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.all(
                                SpacingTokens.spacing4,
                              ),
                              decoration: BoxDecoration(
                                color: ColorTokens.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.toUpperCase(),
                                          style: TypographyTokens.monolithFont(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: ColorTokens.onSurface,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: SpacingTokens.spacing1,
                                        ),
                                        Text(
                                          '${currency.format(currentTotal)} raised  •  ${currency.format(targetAmount)} target',
                                          style: TypographyTokens.bodySmall(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_rounded),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    if (_groups.length > 3)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/contribute/groups'),
                          child: Text(
                            'See all ${_groups.length} circles',
                            style: TypographyTokens.labelMedium(
                              ColorTokens.primaryContainer,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              ClaymorphicButton(
                label: 'START A CIRCLE',
                width: double.infinity,
                onPressed: () => context.push('/contribute/create'),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              OutlinedButton.icon(
                onPressed: () => context.push('/contribute/join'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.group_add_rounded),
                label: const Text('JOIN A CIRCLE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _groupsCountLabel =>
      _groups.length == 1 ? '1 circle is' : '${_groups.length} circles are';
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.metricLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final String metricLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.18),
              ColorTokens.surfaceContainerHighest,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TypographyTokens.monolithFont(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: ColorTokens.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ColorTokens.ghostBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      metricLabel,
                      style: TypographyTokens.editorialFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ColorTokens.onSurfaceVariant,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(subtitle, style: TypographyTokens.bodyMedium()),
            ],
          ),
        ),
      ),
    );
  }
}
