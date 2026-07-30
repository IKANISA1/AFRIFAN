import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
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
  bool _isRefreshing = false;
  bool _isStale = false;
  bool _isUpdatingSmsSync = false;
  String? _error;
  late bool _wasOnline;
  bool _didStartInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStartInitialLoad) return;
    _didStartInitialLoad = true;
    unawaited(_loadGroups());
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    super.dispose();
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;

    if (!mounted) return;
    if (!isOnline && _groups.isNotEmpty) {
      setState(() => _isStale = true);
    } else if (restored) {
      unawaited(_loadGroups());
    }
  }

  Future<void> _loadGroups() async {
    if (!ConnectivityService.isOnline) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isStale = _groups.isNotEmpty;
        _error = _groups.isEmpty
            ? context.afriL10n.contributionsConnectToLoad
            : null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isRefreshing = _groups.isNotEmpty;
        if (_groups.isEmpty) {
          _isLoading = true;
        }
        _error = null;
      });
    }

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
        _isRefreshing = false;
        _isStale = false;
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
        _isRefreshing = false;
        _isStale = _groups.isNotEmpty;
        _error = _groups.isEmpty
            ? context.afriL10n.contributionsInitiativesUnavailableMessage
            : null;
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
          ? context.afriL10n.contributionsSmsEnabled
          : context.afriL10n.contributionsSmsPermissionDenied;
      if (enabled) {
        AfriToast.success(context, message);
      } else {
        AfriToast.error(context, message);
      }
    } catch (error) {
      if (!mounted) return;
      AfriToast.error(context, context.afriL10n.contributionsSmsEnableFailed);
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
      AfriToast.info(context, context.afriL10n.contributionsSmsDisabled);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingSmsSync = false);
      }
    }
  }

  Future<void> _runManualSmsSync() async {
    if (!ConnectivityService.isOnline) {
      AfriToast.error(
        context,
        context.afriL10n.contributionsConnectBeforeSmsSync,
      );
      return;
    }

    setState(() => _isUpdatingSmsSync = true);
    try {
      final result = await ref
          .read(momoSmsAutoreadServiceProvider)
          .syncInbox(trigger: MomoInboxSyncTrigger.manual);
      if (!mounted) return;
      AfriToast.success(
        context,
        context.afriL10n.contributionsSmsSyncComplete(
          result.uploadedMessages,
          result.duplicateMessages,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      AfriToast.error(context, context.afriL10n.contributionsSmsSyncFailed);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingSmsSync = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
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

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      bodyWrapper: (child) => GradientBackground(child: child),
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
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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
                    l10n.contributionsHubTitle,
                    style: TypographyTokens.headlineSmall().copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            if (_isStale || _isRefreshing) ...[
              AfriStateBanner(
                icon: _isRefreshing
                    ? AfriIcons.refresh
                    : AfriIcons.statusWarning,
                title: _isRefreshing
                    ? l10n.contributionsRefreshingTitle
                    : l10n.contributionsSavedTitle,
                subtitle: _isRefreshing
                    ? l10n.contributionsRefreshingMessage
                    : l10n.contributionsSavedMessage,
                tone: _isRefreshing
                    ? AfriStateBannerTone.info
                    : AfriStateBannerTone.warning,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
            ],
            if (hasGroups) ...[
              _HubCard(
                title: l10n.contributionsTeamProjects,
                subtitle: l10n.contributionsRaised(
                  currency.format(totalRaised),
                  currency.format(totalTarget),
                ),
                accent: ColorTokens.clubPrimary,
                metricLabel: l10n.contributionsOpenMetric(_groups.length),
                onTap: () => context.push('/contribute/projects'),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              _HubCard(
                title: l10n.contributionsCommunitiesUpper,
                subtitle: l10n.contributionsInitiativesActive(_groups.length),
                accent: ColorTokens.success,
                metricLabel: l10n.contributionsLiveMetric(_groups.length),
                onTap: () => context.push('/contribute/groups'),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              _HubCard(
                title: l10n.contributionsCommunityUpper,
                subtitle: l10n.contributionsFanClubsChapters,
                accent: ColorTokens.info,
                metricLabel: l10n.contributionsLive,
                onTap: () => context.push('/fan-clubs'),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
            ],
            AfriSectionCard(
              title: l10n.contributionsMomoSmsSync,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!smsSyncAvailable)
                    Text(
                      l10n.contributionsUnavailableBuild,
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    )
                  else if (smsSyncEnabled) ...[
                    AfriInfoChip(
                      label: l10n.contributionsActiveUpper,
                      color: ColorTokens.success,
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    ConnectivityBuilder(
                      builder: (context, isOnline) => AfriButton(
                        label: !isOnline
                            ? l10n.connectionRequired
                            : _isUpdatingSmsSync
                            ? l10n.contributionsSyncing
                            : l10n.contributionsSyncNow,
                        onTap: _runManualSmsSync,
                        isLoading: _isUpdatingSmsSync,
                        enabled: isOnline && !_isUpdatingSmsSync,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.listItemGap),
                    AfriButton(
                      label: l10n.contributionsDisable,
                      variant: AfriButtonVariant.outline,
                      onTap: _disableSmsSync,
                      enabled: !_isUpdatingSmsSync,
                    ),
                  ] else
                    AfriButton(
                      label: _isUpdatingSmsSync
                          ? l10n.contributionsEnabling
                          : l10n.contributionsEnableSmsSync,
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
                title: l10n.contributionsLiveCampaigns,
                child: Column(
                  children: [
                    if (_isLoading)
                      const AfriSkeletonList()
                    else if (_error != null)
                      ConnectivityBuilder(
                        builder: (context, isOnline) => Column(
                          children: [
                            AfriStateView.offline(
                              title: l10n.contributionsGroupsUnavailableTitle,
                              message: _error!,
                              actionLabel: isOnline ? l10n.retry : null,
                              onAction: isOnline ? _loadGroups : null,
                              compact: true,
                            ),
                            if (!isOnline) ...[
                              const SizedBox(height: SpacingTokens.listItemGap),
                              AfriButton(
                                label: l10n.connectionRequired,
                                onTap: () {},
                                enabled: false,
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      ..._groups.take(3).map((group) {
                        final groupId = group['id']?.toString() ?? '';
                        final name =
                            group['name']?.toString() ??
                            l10n.contributionsGroupFallback;
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
                            subtitle: l10n.contributionsAmountOfTarget(
                              currency.format(currentTotal),
                              currency.format(targetAmount),
                            ),
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
                          tooltip: l10n.contributionsSeeAllGroups,
                          semanticsLabel: l10n
                              .contributionsSeeAllGroupsSemantic(
                                _groups.length,
                              ),
                          semanticsHint: l10n.contributionsOpenGroupsHint,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: SpacingTokens.spacing2,
                              horizontal: SpacingTokens.spacing2,
                            ),
                            child: Text(
                              l10n.contributionsSeeAll(_groups.length),
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
    );
  }
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
          borderRadius: ShapeTokens.inputRadius,
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
                      borderRadius: ShapeTokens.buttonRadius,
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
