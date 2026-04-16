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
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing4,
                  SpacingTokens.spacing6,
                  0,
                ),
                child: Row(
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
                        AfriIcons.back,
                        color: ColorTokens.onSurface,
                      ),
                      tooltip: 'Back',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: Text(
                        'MY Groups',
                        style: TypographyTokens.monolithFont(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ColorTokens.onSurface,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: SpacingTokens.spacing3,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openJoinGroup,
                          icon: const Icon(AfriIcons.join),
                          label: const Text('Join'),
                        ),
                        AfriButton(
                          label: 'New',
                          icon: AfriIcons.add,
                          onTap: _openCreateGroup,
                          fullWidth: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing6),
            ),

            // Summary card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: GlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SummaryItem(
                        value: '${_groups.length}',
                        label: 'GROUPS',
                        color: primary,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: ColorTokens.ghostBorder,
                      ),
                      _SummaryItem(
                        value: currency.format(totalContributed),
                        label: 'CONTRIBUTED',
                        color: ColorTokens.success,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: ColorTokens.ghostBorder,
                      ),
                      _SummaryItem(
                        value: '$totalMembers',
                        label: 'MEMBERS',
                        color: ColorTokens.info,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: SpacingTokens.spacing6),
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
                      SpacingTokens.spacing2,
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
                  padding: const EdgeInsets.all(SpacingTokens.spacing10),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          AfriIcons.groups,
                          size: 56,
                          color: primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Text(
                          'No contribution groups yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          'Create or join a group to start contributing.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: SpacingTokens.spacing6),
                        AfriButton(
                          label: 'Create group',
                          icon: AfriIcons.add,
                          onTap: _openCreateGroup,
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        OutlinedButton.icon(
                          onPressed: _openJoinGroup,
                          icon: const Icon(AfriIcons.join),
                          label: const Text('JOIN GROUP'),
                        ),
                      ],
                    ),
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
