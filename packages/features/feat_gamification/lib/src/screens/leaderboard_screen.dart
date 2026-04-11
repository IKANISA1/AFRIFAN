import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List<Map<String, dynamic>> _rows = const <Map<String, dynamic>>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final memberships = await client
          .from('fan_memberships')
          .select('user_id, points')
          .order('points', ascending: false)
          .limit(25);

      final userIds = memberships
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final aliases = <String, String>{};
      if (userIds.isNotEmpty) {
        try {
          final profiles = await client
              .from('profiles')
              .select('id, public_user_id')
              .inFilter('id', userIds);
          for (final profile in profiles) {
            final id = profile['id']?.toString();
            final alias = profile['public_user_id']?.toString();
            if (id != null && alias != null && alias.isNotEmpty) {
              aliases[id] = alias;
            }
          }
        } catch (_) {
          // Alias lookup is best-effort only.
        }
      }

      if (!mounted) return;
      setState(() {
        _rows = memberships
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final row = entry.value;
              final userId = row['user_id']?.toString() ?? '';
              return <String, dynamic>{
                'rank': index + 1,
                'alias': aliases[userId] ?? _aliasFromUserId(userId),
                'xp': (row['points'] as num?)?.toInt() ?? 0,
                'isCurrentUser': userId == client.auth.currentUser?.id,
              };
            })
            .toList(growable: false);
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

  String _formatXp(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final podium = _rows.take(3).toList(growable: false);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'LEADERBOARD',
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () => showAfriFilterSortSheet(
              context: context,
              title: 'Leaderboard Filters',
              sortOptions: const [
                AfriFilterOption(value: 'season_xp', label: 'Season XP'),
                AfriFilterOption(value: 'all_time_xp', label: 'All Time XP'),
              ],
              typeOptions: const [
                AfriFilterOption(value: 'all', label: 'All Supporters'),
                AfriFilterOption(value: 'top_10', label: 'Top 10'),
              ],
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _rows.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: GlassCard(
                  animate: false,
                  child: Text(
                    'No rankings yet. Board fills as XP syncs.',
                    style: TypographyTokens.bodyMedium(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              children: [
                if (podium.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _PodiumCard(
                          rank: podium.length > 1 ? '#02' : '--',
                          alias: podium.length > 1
                              ? '#${podium[1]['alias']}'
                              : 'No fan',
                          xp: podium.length > 1
                              ? _formatXp(podium[1]['xp'] as int)
                              : '0',
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: _PodiumCard(
                          rank: '#01',
                          alias: '#${podium[0]['alias']}',
                          xp: _formatXp(podium[0]['xp'] as int),
                          featured: true,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: _PodiumCard(
                          rank: podium.length > 2 ? '#03' : '--',
                          alias: podium.length > 2
                              ? '#${podium[2]['alias']}'
                              : 'No fan',
                          xp: podium.length > 2
                              ? _formatXp(podium[2]['xp'] as int)
                              : '0',
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: SpacingTokens.spacing6),
                ..._rows.map((row) {
                  final rank = row['rank'] as int;
                  final alias = row['alias']?.toString() ?? '000000';
                  final xp = row['xp'] as int? ?? 0;
                  final isCurrentUser = row['isCurrentUser'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: SpacingTokens.spacing3,
                    ),
                    child: GlassCard(
                      animate: false,
                      child: Row(
                        children: [
                          Text(
                            '#${rank.toString().padLeft(2, '0')}',
                            style: TypographyTokens.monolithFont(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: isCurrentUser
                                  ? Theme.of(context).colorScheme.primary
                                  : ColorTokens.onSurface,
                            ),
                          ),
                          const SizedBox(width: SpacingTokens.spacing4),
                          Expanded(
                            child: Text(
                              '#$alias',
                              style: TypographyTokens.numericAlias(
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            '${_formatXp(xp)} XP',
                            style: TypographyTokens.monolithFont(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: ColorTokens.clubAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.rank,
    required this.alias,
    required this.xp,
    this.featured = false,
  });

  final String rank;
  final String alias;
  final String xp;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        children: [
          Text(
            rank,
            style: TypographyTokens.monolithFont(
              fontSize: featured ? 28 : 22,
              fontWeight: FontWeight.w800,
              color: featured
                  ? ColorTokens.clubAccent
                  : ColorTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(alias, style: TypographyTokens.numericAlias(fontSize: 15)),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            '$xp XP',
            style: TypographyTokens.bodySmall(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
