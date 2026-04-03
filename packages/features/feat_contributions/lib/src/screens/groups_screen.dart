import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/group_card.dart';

/// Groups list screen — shows user's contribution circles.
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
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
                    Text(
                      'MY CIRCLES',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ColorTokens.onSurface,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const Spacer(),
                    ClaymorphicButton(
                      label: 'New',
                      icon: Icons.add,
                      onPressed: () {
                        final profile = ProviderScope.containerOf(
                          context,
                        ).read(currentUserProvider);
                        if (profile == null || !profile.hasMomo) {
                          context.push('/profile_setup');
                          return;
                        }
                        context.push('/contribute/create');
                      },
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
                        value:
                            'FRw ${CurrencyFormatter(currencyCode: 'RWF', currencySymbol: 'FRw').formatPlain(totalContributed)}',
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

            // Group list
            if (!_isLoading && _groups.isNotEmpty)
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
            if (!_isLoading && _groups.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing10),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_work_outlined,
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
                        ClaymorphicButton(
                          label: 'Create Group',
                          icon: Icons.add,
                          onPressed: () {
                            final profile = ProviderScope.containerOf(
                              context,
                            ).read(currentUserProvider);
                            if (profile == null || !profile.hasMomo) {
                              context.push('/profile_setup');
                              return;
                            }
                            context.push('/contribute/create');
                          },
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
          style: GoogleFonts.barlowCondensed(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
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
