import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../widgets/badge_grid.dart';
import '../widgets/xp_arc.dart';

/// FET Dashboard — the FANZONE rewards hub.
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
  String _tier = 'FAN';
  String _nextTier = 'BRONZE';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final context = await ref
          .read(fetRepositoryProvider)
          .loadExperienceContext(leaderboardLimit: 10);
      final achievements = context.catalog
          .map(
            (item) => <String, dynamic>{
              'title': item.itemName,
              'icon_key': item.iconKey,
              'is_earned': context.earnedCodes.contains(item.code),
            },
          )
          .toList(growable: false);
      final leaderboard = context.leaderboard
          .map(
            (entry) => <String, dynamic>{
              'alias': entry.supporterAlias,
              'points': entry.totalFet,
            },
          )
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _currentXp = context.currentFet;
        _weeklyXp = context.weeklyFet;
        _fanRank = context.fanRank;
        _tier = context.tier;
        _nextTier = context.nextTier;
        _leaderboard = leaderboard;
        _achievements = achievements;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'FET stats are temporarily unavailable.';
      });
    }
  }

  int _nextTierThreshold(int xp) {
    if (xp >= 5000) return 5000;
    if (xp >= 2000) return 5000;
    if (xp >= 1000) return 2000;
    return 1000;
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
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: 'Gamification unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadData,
                ),
              ),
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
                          label: 'PREDICT',
                          onTap: () => context.push('/fanzone/fixtures'),
                        ),
                        _RouteChip(
                          label: 'CHALLENGES',
                          onTap: () => context.push('/fanzone/challenges'),
                        ),
                        _RouteChip(
                          label: 'LEADERBOARD',
                          onTap: () => context.push('/fanzone/leaderboard'),
                        ),
                        _RouteChip(
                          label: 'WALLET',
                          onTap: () => context.push('/fanzone/wallet'),
                        ),
                        _RouteChip(
                          label: 'STORE',
                          onTap: () => context.push('/fanzone/rewards'),
                        ),
                        _RouteChip(
                          label: 'HISTORY',
                          onTap: () => context.push('/fanzone/history'),
                        ),
                        _RouteChip(
                          label: 'BADGES',
                          onTap: () => context.push('/fanzone/badges'),
                        ),
                        _RouteChip(
                          label: 'STREAK',
                          onTap: () => context.push('/fanzone/streak'),
                        ),
                        _RouteChip(
                          label: 'JACKPOT',
                          onTap: () => context.push('/fanzone/jackpot'),
                        ),
                        _RouteChip(
                          label: 'FRIENDS',
                          onTap: () => context.push('/fanzone/friends'),
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
                                '${entry['points']} FET',
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
