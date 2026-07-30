import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/group_card.dart';

/// Communities list screen — shows admin-managed public initiatives.
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadGroups());
  }

  Future<void> _loadGroups() async {
    try {
      final repo = ref.read(clubRepositoryProvider);
      final groups = await repo.getContributionGroups();

      if (mounted) {
        setState(() {
          _groups = groups
              .map(
                (g) => <String, dynamic>{
                  'id': g.id,
                  'name': g.name,
                  'description': g.description,
                  'current_total': g.currentTotal,
                  'target_amount': g.targetAmount,
                  'member_count': g.memberCount,
                  'group_type': g.groupType.value,
                  'created_at': g.createdAt.toIso8601String(),
                },
              )
              .toList();
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = context.afriL10n.contributionsCommunitiesLoadError;
        });
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
    final totalContributed = _groups.fold<int>(
      0,
      (sum, group) => sum + ((group['current_total'] as num?)?.toInt() ?? 0),
    );
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          l10n.contributionsCommunitiesTitle,
          style: TypographyTokens.headlineSmall(),
        ),
        leading: AfriIconButton(
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
      scrollable: false,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            if (!_isLoading && _error == null && _groups.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AfriMetricTile(
                          label: l10n.contributionsInitiatives,
                          value: '${_groups.length}',
                          accentColor: ColorTokens.clubAccent,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: AfriMetricTile(
                          label: l10n.contributionsContributed,
                          value: currency.formatPlain(totalContributed),
                          meta: context.afriCurrencyCode,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_groups.isNotEmpty)
              SliverToBoxAdapter(
                child: AfriSectionHeader(
                  title: l10n.contributionsActiveInitiatives,
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing3),
            ),

            // Loading
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing6,
                  ),
                  child: AfriSkeletonList(),
                ),
              ),

            if (!_isLoading && _error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing6,
                  ),
                  child: AfriStateView.offline(
                    title: l10n.contributionsCommunitiesUnavailableTitle,
                    message: _error!,
                    actionLabel: l10n.retry,
                    onAction: _loadGroups,
                    compact: true,
                  ),
                ),
              ),

            if (!_isLoading && _error == null && _groups.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing6,
                  ),
                  child: AfriStateView.empty(
                    title: l10n.contributionsCommunityQuietTitle,
                    message: l10n.contributionsCommunityQuietMessage,
                    compact: true,
                  ),
                ),
              ),

            // Group list
            if (!_isLoading && _error == null && _groups.isNotEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final group = _groups[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SpacingTokens.spacing6,
                      0,
                      SpacingTokens.spacing6,
                      SpacingTokens.spacing3,
                    ),
                    child: GroupCard(
                      group: group,
                      onTap: () {
                        final id = group['id']?.toString() ?? '';
                        context.go('/contribute/group/$id');
                      },
                    ),
                  );
                }, childCount: _groups.length),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing20),
            ),
          ],
        ),
      ),
    );
  }
}
