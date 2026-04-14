import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/prediction_models.dart';
import '../prediction_providers.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List<PredictionLeaderboardEntry> _rows = const <PredictionLeaderboardEntry>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final leaderboard = await ref
          .read(predictionRepositoryProvider)
          .loadLeaderboard(limit: 25);

      if (!mounted) return;
      setState(() {
        _rows = leaderboard;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Leaderboard is temporarily unavailable.';
      });
    }
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
                  title: 'Leaderboard unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadLeaderboard,
                ),
              ),
            )
          : _rows.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriEmptyView(
                  title: 'No ranks yet',
                  message: 'The board fills as predictions settle.',
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
                          entry: podium.length > 1 ? podium[1] : null,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: _PodiumCard(entry: podium.first, featured: true),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: _PodiumCard(
                          entry: podium.length > 2 ? podium[2] : null,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: SpacingTokens.spacing6),
                ..._rows.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: SpacingTokens.spacing3,
                    ),
                    child: GlassCard(
                      animate: false,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            child: Text(
                              '#${entry.rank.toString().padLeft(2, '0')}',
                              style: TypographyTokens.monolithFont(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: entry.rank == 1
                                    ? ColorTokens.clubAccent
                                    : ColorTokens.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: SpacingTokens.spacing3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.displayName,
                                  style: TypographyTokens.titleSmall(),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${entry.winRate.toStringAsFixed(1)}% accuracy · ${entry.wins} wins',
                                  style: TypographyTokens.bodySmall(),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${entry.totalFetEarned} FET',
                                style: TypographyTokens.monolithFont(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: ColorTokens.clubAccent,
                                ),
                              ),
                              Text(
                                '${entry.totalSettled} settled',
                                style: TypographyTokens.bodySmall(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.entry, this.featured = false});

  final PredictionLeaderboardEntry? entry;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        children: [
          Text(
            entry == null ? '--' : '#${entry!.rank.toString().padLeft(2, '0')}',
            style: TypographyTokens.monolithFont(
              fontSize: featured ? 28 : 22,
              fontWeight: FontWeight.w800,
              color: featured
                  ? ColorTokens.clubAccent
                  : ColorTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry?.displayName ?? 'No rank',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.bodyMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            entry == null ? '0 FET' : '+${entry!.totalFetEarned} FET',
            style: TypographyTokens.monolithFont(
              fontSize: featured ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
        ],
      ),
    );
  }
}
