import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/badge_grid.dart';
import '../widgets/xp_arc.dart';

/// XP Dashboard — the gamification hub.
class XpDashboardScreen extends ConsumerStatefulWidget {
  const XpDashboardScreen({super.key});

  @override
  ConsumerState<XpDashboardScreen> createState() => _XpDashboardScreenState();
}

class _XpDashboardScreenState extends ConsumerState<XpDashboardScreen> {
  List<Map<String, dynamic>> _achievements = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _leaderboard = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  int _currentXp = 0;
  int _fanRank = 0;
  int _weeklyXp = 0;
  String _tier = 'BRONZE';
  String _nextTier = 'SILVER';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;

    try {
      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();
      var membershipsQuery = client.from('fan_memberships').select(
        'user_id, points',
      );
      membershipsQuery = resolver.apply(membershipsQuery, scope);
      final memberships = await membershipsQuery
          .order('points', ascending: false)
          .limit(10);
      final events = userId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await client
                  .from('cool_events')
                  .select('xp_awarded, event_at')
                  .eq('user_id', userId)
                  .gte(
                    'event_at',
                    DateTime.now()
                        .subtract(const Duration(days: 7))
                        .toIso8601String(),
                  )
                  .order('event_at', ascending: false),
            );

      final membershipRows = List<Map<String, dynamic>>.from(memberships);
      final currentIndex = membershipRows.indexWhere(
        (row) => row['user_id']?.toString() == userId,
      );
      final currentXp = currentIndex == -1
          ? 0
          : (membershipRows[currentIndex]['points'] as num?)?.toInt() ?? 0;
      final weeklyXp = events.fold<int>(
        0,
        (sum, event) => sum + ((event['xp_awarded'] as num?)?.toInt() ?? 0),
      );
      final fanRank = currentIndex == -1 ? 0 : currentIndex + 1;
      final tier = _tierLabelFromXp(currentXp);
      final nextTier = _nextTierFromXp(currentXp);

      final aliases = <String, String>{};
      final ids = membershipRows
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (ids.isNotEmpty) {
        try {
          final profiles = await client
              .from('profiles')
              .select('id, public_user_id')
              .inFilter('id', ids);
          for (final profile in profiles) {
            final id = profile['id']?.toString();
            final alias = profile['public_user_id']?.toString();
            if (id != null && alias != null && alias.isNotEmpty) {
              aliases[id] = alias;
            }
          }
        } catch (_) {
          // Alias lookup is best-effort.
        }
      }

      final leaderboard = membershipRows
          .map((row) {
            final memberId = row['user_id']?.toString() ?? '';
            return <String, dynamic>{
              'alias': aliases[memberId] ?? _aliasFromUserId(memberId),
              'points': (row['points'] as num?)?.toInt() ?? 0,
            };
          })
          .toList(growable: false);

      final achievements = _derivedAchievements(
        currentXp: currentXp,
        weeklyXp: weeklyXp,
        hasLeaderboard: leaderboard.isNotEmpty,
      );

      if (!mounted) return;
      setState(() {
        _currentXp = currentXp;
        _weeklyXp = weeklyXp;
        _fanRank = fanRank;
        _tier = tier;
        _nextTier = nextTier;
        _leaderboard = leaderboard;
        _achievements = achievements;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _aliasFromUserId(String userId) {
    if (userId.isEmpty) return '000000';
    final hash = userId.hashCode.abs();
    return (100000 + hash % 900000).toString();
  }

  String _tierLabelFromXp(int xp) {
    if (xp >= 50000) return 'LEGEND';
    if (xp >= 15000) return 'GOLD';
    if (xp >= 5000) return 'SILVER';
    return 'BRONZE';
  }

  String _nextTierFromXp(int xp) {
    if (xp >= 50000) return 'LEGEND';
    if (xp >= 15000) return 'LEGEND';
    if (xp >= 5000) return 'GOLD';
    return 'SILVER';
  }

  int _nextTierThreshold(int xp) {
    if (xp >= 50000) return 50000;
    if (xp >= 15000) return 50000;
    if (xp >= 5000) return 15000;
    return 5000;
  }

  List<Map<String, dynamic>> _derivedAchievements({
    required int currentXp,
    required int weeklyXp,
    required bool hasLeaderboard,
  }) {
    return <Map<String, dynamic>>[
      {
        'title': 'Bronze Pulse',
        'icon_key': 'match',
        'is_earned': currentXp >= 500,
      },
      {
        'title': 'Weekly Run',
        'icon_key': 'streak',
        'is_earned': weeklyXp >= 250,
      },
      {
        'title': 'Leaderboard',
        'icon_key': 'mvp',
        'is_earned': hasLeaderboard && _fanRank > 0,
      },
      {
        'title': 'Silver Rise',
        'icon_key': 'legend',
        'is_earned': currentXp >= 5000,
      },
      {
        'title': 'Gold Faithful',
        'icon_key': 'contributor',
        'is_earned': currentXp >= 15000,
      },
      {
        'title': 'Legend Circle',
        'icon_key': 'fan_club',
        'is_earned': currentXp >= 50000,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: ColorTokens.onSurface),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: Text(
          'GAMIFICATION',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurface,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: SpacingTokens.spacing4),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing6,
                    ),
                    child: GlassCard(
                      child: Column(
                        children: [
                          const SizedBox(height: SpacingTokens.spacing4),
                          XpArc(
                            currentXp: _currentXp,
                            maxXp: _nextTierThreshold(_currentXp),
                            tier: _tier,
                            nextTier: _nextTier,
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _StatColumn(
                                value: '+$_weeklyXp',
                                label: 'THIS WEEK',
                                color: ColorTokens.success,
                              ),
                              _StatColumn(
                                value:
                                    '${_achievements.where((a) => a['is_earned'] == true).length}',
                                label: 'BADGES',
                                color: primary,
                              ),
                              _StatColumn(
                                value: _fanRank == 0 ? '--' : '#$_fanRank',
                                label: 'RANK',
                                color: ColorTokens.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SpacingTokens.spacing6,
                      SpacingTokens.spacing4,
                      SpacingTokens.spacing6,
                      0,
                    ),
                    child: Wrap(
                      spacing: SpacingTokens.spacing2,
                      runSpacing: SpacingTokens.spacing2,
                      children: [
                        _RouteChip(
                          label: 'CHALLENGES',
                          onTap: () => context.push('/xp/challenges'),
                        ),
                        _RouteChip(
                          label: 'LEADERBOARD',
                          onTap: () => context.push('/xp/leaderboard'),
                        ),
                        _RouteChip(
                          label: 'BADGES',
                          onTap: () => context.push('/xp/badges'),
                        ),
                        _RouteChip(
                          label: 'STREAK',
                          onTap: () => context.push('/xp/streak'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: SpacingTokens.spacing8),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing6,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'ACHIEVEMENTS',
                          style: TypographyTokens.monolithFont(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ColorTokens.onSurfaceVariant,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_achievements.where((a) => a['is_earned'] == true).length} EARNED',
                          style: TypographyTokens.editorialFont(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: SpacingTokens.spacing4),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing6,
                    ),
                    child: BadgeGrid(achievements: _achievements),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: SpacingTokens.spacing8),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing6,
                    ),
                    child: Text(
                      'LEADERBOARD',
                      style: TypographyTokens.monolithFont(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ColorTokens.onSurfaceVariant,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: SpacingTokens.spacing4),
                ),
                if (_leaderboard.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing6,
                      ),
                      child: GlassCard(
                        animate: false,
                        child: Text(
                          'No supporter rankings are available yet.',
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = _leaderboard[index];
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          SpacingTokens.spacing6,
                          0,
                          SpacingTokens.spacing6,
                          index == _leaderboard.length - 1
                              ? SpacingTokens.spacing20
                              : SpacingTokens.spacing2,
                        ),
                        child: GlassCard(
                          animate: false,
                          child: Row(
                            children: [
                              Text(
                                '#${(index + 1).toString().padLeft(2, '0')}',
                                style: TypographyTokens.monolithFont(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: index == 0
                                      ? primary
                                      : ColorTokens.onSurface,
                                ),
                              ),
                              const SizedBox(width: SpacingTokens.spacing4),
                              Expanded(
                                child: Text(
                                  '#${entry['alias']}',
                                  style: TypographyTokens.numericAlias(
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                '${entry['points']} XP',
                                style: TypographyTokens.monolithFont(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: ColorTokens.clubAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: _leaderboard.length),
                  ),
              ],
            ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TypographyTokens.monolithFont(
            fontSize: 24,
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

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: BorderTokens.ghost(),
        ),
        child: Text(
          label,
          style: TypographyTokens.editorialFont(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurface,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
