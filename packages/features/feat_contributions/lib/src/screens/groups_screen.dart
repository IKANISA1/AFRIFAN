import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/group_card.dart';

/// Groups list screen — shows user's contribution Groups.
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
    _loadGroups();
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
                  'privacy': g.privacy.value,
                  'group_type': g.groupType.value,
                  'invite_code': g.inviteCode,
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
          _error = 'Could not load your Groups right now.';
        });
      }
    }
  }

  void _openCreateGroup() {
    final profile = ProviderScope.containerOf(
      context,
    ).read(currentUserProvider);
    if (profile == null) {
      context.go('/onboarding');
      return;
    }
    context.push('/contribute/create');
  }

  void _openJoinGroup() {
    final profile = ProviderScope.containerOf(
      context,
    ).read(currentUserProvider);
    if (profile == null) {
      context.go('/onboarding');
      return;
    }
    context.push('/contribute/join');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );
    final totalContributed = _groups.fold<int>(
      0,
      (sum, group) => sum + ((group['current_total'] as num?)?.toInt() ?? 0),
    );
    final totalMembers = _groups.fold<int>(
      0,
      (sum, group) => sum + ((group['member_count'] as num?)?.toInt() ?? 0),
    );

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'My groups',
          style: TypographyTokens.headlineSmall(),
        ),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          icon: Icon(
            AfriIcons.back,
            color: ColorTokens.onSurface,
          ),
          tooltip: 'Back',
        ),
        actions: [
          AfriIconButton(
            icon: AfriIcons.join,
            onTap: _openJoinGroup,
            tooltip: 'Join group',
          ),
          const SizedBox(width: SpacingTokens.spacing1),
          AfriIconButton(
            icon: AfriIcons.add,
            onTap: _openCreateGroup,
            tooltip: 'New group',
          ),
          const SizedBox(width: SpacingTokens.spacing4),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Summary row
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
                        label: 'Groups',
                        value: '${_groups.length}',
                        accentColor: ColorTokens.clubAccent,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: AfriMetricTile(
                        label: 'Contributed',
                        value: currency.formatPlain(totalContributed),
                        meta: context.afriCurrencyCode,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_groups.isNotEmpty)
              const SliverToBoxAdapter(
                child: AfriSectionHeader(title: 'Active groups'),
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
                    title: 'Groups unavailable',
                    message: _error!,
                    actionLabel: 'Retry',
                    onAction: _loadGroups,
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

            // Empty state
            if (!_isLoading && _error == null && _groups.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: AfriEmptyView(
                    icon: AfriIcons.groups,
                    title: 'No groups yet',
                    message: 'Create or join a group to start contributing.',
                    actionLabel: 'Create group',
                    onAction: _openCreateGroup,
                  ),
                ),
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

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TypographyTokens.editorialFont(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ColorTokens.onSurfaceVariant,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
