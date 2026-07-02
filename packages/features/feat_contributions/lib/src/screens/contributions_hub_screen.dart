import 'dart:async';

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
    unawaited(_loadGroups());
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
                  'group_type': group.groupType.value,
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
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ContributionsHubScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Contribution initiatives are temporarily unavailable.';
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
      final message = enabled
          ? 'MoMo SMS sync enabled for this device.'
          : 'SMS access was not granted. Sync remains off.';
      if (enabled) {
        AfriToast.success(context, message);
      } else {
        AfriToast.error(context, message);
      }
    } catch (error) {
      if (!mounted) return;
      AfriToast.error(
        context,
        'Could not enable SMS sync. Check your permissions and try again.',
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
      AfriToast.info(context, 'MoMo SMS sync disabled.');
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
      AfriToast.success(
        context,
        'SMS sync complete: ${result.uploadedMessages} uploaded, ${result.duplicateMessages} duplicates.',
      );
    } catch (error) {
      if (!mounted) return;
      AfriToast.error(
        context,
        'SMS sync failed. Check your connection and try again.',
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
    final hasGroups = !_isLoading && _error == null && _groups.isNotEmpty;

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
                  AfriIconButton(
                    icon: AfriIcons.back,
                    tooltip: 'Back',
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Text(
                      'CONTRIBUTE',
                      style: TypographyTokens.headlineSmall().copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              if (hasGroups) ...[
                _HubCard(
                  title: 'TEAM PROJECTS',
                  subtitle:
                      '${currency.format(totalRaised)} of ${currency.format(totalTarget)} raised.',
                  accent: ColorTokens.clubPrimary,
                  metricLabel: '${_groups.length} OPEN',
                  onTap: () => context.push('/contribute/projects'),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                _HubCard(
                  title: 'COMMUNITIES',
                  subtitle: '$_groupsCountLabel active.',
                  accent: ColorTokens.success,
                  metricLabel: '${_groups.length} LIVE',
                  onTap: () => context.push('/contribute/groups'),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                _HubCard(
                  title: 'COMMUNITY',
                  subtitle: 'Fan clubs & local chapters.',
                  accent: ColorTokens.info,
                  metricLabel: 'LIVE',
                  onTap: () => context.push('/fan-clubs'),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
              ],
              AfriSectionCard(
                title: 'MoMo SMS sync',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!smsSyncAvailable)
                      Text(
                        'Unavailable in this build.',
                        style: TypographyTokens.bodySmall(
                          ColorTokens.onSurfaceVariant,
                        ),
                      )
                    else if (smsSyncEnabled) ...[
                      const AfriInfoChip(
                        label: 'ACTIVE',
                        color: ColorTokens.success,
                      ),
                      const SizedBox(height: SpacingTokens.spacing4),
                      AfriButton(
                        label: _isUpdatingSmsSync ? 'Syncing…' : 'Sync now',
                        onTap: _runManualSmsSync,
                        isLoading: _isUpdatingSmsSync,
                        enabled: !_isUpdatingSmsSync,
                      ),
                      const SizedBox(height: SpacingTokens.listItemGap),
                      AfriButton(
                        label: 'Disable',
                        variant: AfriButtonVariant.outline,
                        onTap: _disableSmsSync,
                        enabled: !_isUpdatingSmsSync,
                      ),
                    ] else
                      AfriButton(
                        label: _isUpdatingSmsSync
                            ? 'Enabling…'
                            : 'Enable SMS sync',
                        variant: AfriButtonVariant.outline,
                        onTap: _enableSmsSync,
                        isLoading: _isUpdatingSmsSync,
                        enabled: !_isUpdatingSmsSync,
                      ),
                  ],
                ),
              ),
              if (_isLoading || _error != null || hasGroups) ...[
                const SizedBox(height: SpacingTokens.spacing4),
                AfriSectionCard(
                  title: 'Live campaigns',
                  child: Column(
                    children: [
                      if (_isLoading)
                        const AfriSkeletonList()
                      else if (_error != null)
                        AfriStateView.offline(
                          title: 'Groups unavailable',
                          message: _error!,
                          actionLabel: 'Retry',
                          onAction: _loadGroups,
                          compact: true,
                        )
                      else
                        ..._groups.take(3).map((group) {
                          final groupId = group['id']?.toString() ?? '';
                          final name = group['name']?.toString() ?? 'Group';
                          final currentTotal =
                              (group['current_total'] as num?)?.toInt() ?? 0;
                          final targetAmount =
                              (group['target_amount'] as num?)?.toInt() ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: SpacingTokens.listItemGap,
                            ),
                            child: AfriListRow(
                              icon: AfriIcons.contribute,
                              title: name,
                              subtitle:
                                  '${currency.format(currentTotal)} of ${currency.format(targetAmount)}',
                              onTap: () =>
                                  context.push('/contribute/group/$groupId'),
                            ),
                          );
                        }),
                      if (_groups.length > 3)
                        Align(
                          alignment: Alignment.centerRight,
                          child: AfriPressFeedback(
                            onTap: () => context.push('/contribute/groups'),
                            tooltip: 'See all contribution groups',
                            semanticsLabel:
                                'See all ${_groups.length} contribution groups',
                            semanticsHint: 'Open contribution groups',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: SpacingTokens.spacing2,
                                horizontal: SpacingTokens.spacing2,
                              ),
                              child: Text(
                                'See all ${_groups.length}',
                                style: TypographyTokens.inlineAction(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _groupsCountLabel => _groups.length == 1
      ? '1 initiative is'
      : '${_groups.length} initiatives are';
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
          gradient: ColorTokens.universalSurfaceGradient(
            from: accent.withValues(alpha: 0.18),
            to: ColorTokens.surfaceContainerHighest,
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
                      style: TypographyTokens.headlineMedium().copyWith(
                        fontWeight: FontWeight.w800,
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
                      style:
                          TypographyTokens.labelLarge(
                            ColorTokens.onSurfaceVariant,
                          ).copyWith(
                            fontWeight: FontWeight.w700,
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
