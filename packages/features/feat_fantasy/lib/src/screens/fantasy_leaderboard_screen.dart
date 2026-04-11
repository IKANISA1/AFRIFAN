import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/fantasy_providers.dart';

class FantasyLeaderboardScreen extends ConsumerWidget {
  const FantasyLeaderboardScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(fantasyLeaderboardProvider(slug));

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Fantasy leaderboard'),
      ),
      body: GradientBackground(
        child: SafeArea(
          top: false,
          child: leaderboardAsync.when(
            data: (rows) => ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: SpacingTokens.spacing3),
              itemBuilder: (context, index) {
                final row = rows[index];
                return GlassCard(
                  child: Row(
                    children: [
                      Text(
                        '#${row.rank}',
                        style: TypographyTokens.monolithFont(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: row.isCurrentUser
                              ? ColorTokens.clubAccent
                              : ColorTokens.onSurface,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing4),
                      Expanded(
                        child: Text(
                          row.teamName,
                          style: TypographyTokens.titleMedium().copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${row.points} pts',
                        style: TypographyTokens.labelLarge().copyWith(
                          color: ColorTokens.clubAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(itemCount: 6),
            ),
            error: (_, __) =>
                const Center(child: Text('Leaderboard failed to load.')),
          ),
        ),
      ),
    );
  }
}
