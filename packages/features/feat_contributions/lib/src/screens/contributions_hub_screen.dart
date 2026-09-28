import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/group_card.dart';

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
                  'image_url': group.imageUrl,
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
        _groups = rows;
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;

    final filter = GoRouterState.of(context).uri.queryParameters['type'];
    final visibleGroups = _groups
        .where((group) => filter == null || group['group_type'] == filter)
        .toList();
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
            Align(
              alignment: Alignment.centerLeft,
              child: AfriIconButton(
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
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriSectionHeader(
              title: l10n.contributionsHubTitle,
              isPageTitle: true,
              padding: EdgeInsets.zero,
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
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: [
                for (final entry in <String?, String>{
                  null: l10n.contributionsHubTitle,
                  'project': l10n.contributionsTeamProjects,
                  'community': l10n.contributionsCommunitiesUpper,
                }.entries)
                  AfriChoiceChip(
                    label: Text(entry.value),
                    selected: filter == entry.key,
                    onSelected: (_) => context.go(
                      entry.key == null
                          ? '/contribute'
                          : '/contribute?type=${entry.key}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            if (_isLoading)
              const AfriSkeletonList()
            else if (_error != null)
              AfriStateView.offline(
                title: l10n.contributionsGroupsUnavailableTitle,
                message: _error!,
                actionLabel: l10n.retry,
                onAction: _loadGroups,
              )
            else if (visibleGroups.isEmpty)
              AfriStateView.empty(
                title: l10n.contributionsLedgerEmptyTitle,
                message: l10n.contributionsInitiativesUnavailableMessage,
              )
            else
              for (final group in visibleGroups)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: SpacingTokens.spacing4,
                  ),
                  child: GroupCard(
                    group: group,
                    onTap: () => context.push(
                      '/contribute/group/${Uri.encodeComponent(group['id'].toString())}',
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
