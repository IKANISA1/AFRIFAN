import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fanzone_slip_providers.dart';
import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../widgets/community_prediction_bar.dart';
import '../widgets/h2h_tab_body.dart';
import '../widgets/lineups_tab_body.dart';
import '../widgets/market_option_pill.dart';
import '../widgets/market_selector_sheet.dart';
import '../widgets/prediction_slip_widgets.dart';
import '../widgets/stats_panel.dart';

class MatchDetailScreen extends ConsumerStatefulWidget {
  const MatchDetailScreen({super.key, required this.fixtureId});

  final String fixtureId;

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  FixtureSummary? _fixture;
  List<FixtureMarket> _markets = const <FixtureMarket>[];
  Map<String, List<CommunityPick>> _communityPicks =
      const <String, List<CommunityPick>>{};
  List<H2hEncounter> _h2hEncounters = const <H2hEncounter>[];
  List<LineupPlayer> _homeLineup = const <LineupPlayer>[];
  List<LineupPlayer> _awayLineup = const <LineupPlayer>[];
  bool _isLoading = true;
  String? _error;

  late final TabController _tabController;

  static const _tabLabels = <String>['PREDICT', 'STATS', 'H2H', 'LINEUPS'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(predictionRepositoryProvider);
      final results = await Future.wait<Object?>([
        repo.loadFixture(widget.fixtureId),
        repo.loadFixtureMarkets(widget.fixtureId),
        repo.loadFixtureCommunityPicks(widget.fixtureId),
      ]);

      if (!mounted) return;

      final communityRows = results[2]! as List<CommunityPick>;
      final communityPicks = <String, List<CommunityPick>>{};
      for (final row in communityRows) {
        communityPicks
            .putIfAbsent(row.fixtureMarketId, () => <CommunityPick>[])
            .add(row);
      }

      setState(() {
        _fixture = results[0] as FixtureSummary?;
        _markets = results[1]! as List<FixtureMarket>;
        _communityPicks = communityPicks;
        _isLoading = false;
        _error = _fixture == null ? 'Fixture not found.' : null;
      });

      // Load H2H + Lineups in background (non-blocking).
      if (_fixture != null) {
        _loadH2hAndLineups(_fixture!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load match details right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadH2hAndLineups(FixtureSummary fixture) async {
    final repo = ref.read(predictionRepositoryProvider);

    try {
      // H2H: query finished fixtures for matching team slugs.
      final h2hRaw = await repo.loadH2hEncounters(
        homeTeamSlug: fixture.homeTeamSlug,
        awayTeamSlug: fixture.awayTeamSlug,
        limit: 10,
      );
      if (mounted) {
        setState(() {
          _h2hEncounters = h2hRaw
              .map((row) => H2hEncounter(
                    homeTeam: row['home_team_name']?.toString() ?? '',
                    awayTeam: row['away_team_name']?.toString() ?? '',
                    homeScore: (row['home_score'] as num?)?.toInt() ?? 0,
                    awayScore: (row['away_score'] as num?)?.toInt() ?? 0,
                    date: row['kickoff_at']?.toString(),
                    competition: row['competition_name']?.toString(),
                  ))
              .toList(growable: false);
        });
      }
    } catch (_) {
      // Silently fail — H2H is supplementary data.
    }

    try {
      // Lineups: use roster catalog as proxy.
      final lineupsRaw = await repo.loadFixtureLineups(
        homeTeamSlug: fixture.homeTeamSlug,
        awayTeamSlug: fixture.awayTeamSlug,
      );
      if (mounted) {
        setState(() {
          _homeLineup = _parseLineupPlayers(lineupsRaw['home'] ?? []);
          _awayLineup = _parseLineupPlayers(lineupsRaw['away'] ?? []);
        });
      }
    } catch (_) {
      // Silently fail — lineups are supplementary data.
    }
  }

  List<LineupPlayer> _parseLineupPlayers(
    List<Map<String, dynamic>> rows,
  ) {
    return rows
        .map((row) => LineupPlayer(
              name: row['player_name']?.toString() ?? 'Unknown',
              number: (row['squad_number'] as num?)?.toInt(),
              position: row['position']?.toString(),
              isStarter: true, // Roster proxy — all shown as starters.
            ))
        .toList(growable: false);
  }

  Future<void> _openSlip() async {
    await showPredictionSlipSheet(context, ref, onSubmitted: _loadData);
  }

  String _formatKickoff() {
    final kickoff = _fixture?.kickoffAt;
    if (kickoff == null) return 'KICKOFF TBD';
    final local = kickoff.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const monthNames = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${dayNames[local.weekday - 1]} ${local.day} ${monthNames[local.month - 1]}  •  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ColorTokens.background,
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(SpacingTokens.spacing6),
            child: AfriSkeletonList(),
          ),
        ),
      );
    }

    if (_fixture == null) {
      return Scaffold(
        backgroundColor: ColorTokens.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(AfriIcons.back),
                    ),
                  ],
                ),
                const Spacer(),
                AfriErrorView(
                  compact: true,
                  message: _error,
                  onRetry: _loadData,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

    final fixture = _fixture!;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      bottomNavigationBar: PredictionSlipBar(onTap: _openSlip),
      body: GradientBackground(
        child: SafeArea(
          child: NestedScrollView(
            physics: const BouncingScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ── Back + actions row ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing6,
                    0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(AfriIcons.back),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _markets.isEmpty
                            ? null
                            : () => showMarketSelectorSheet(
                                context: context,
                                fixture: fixture,
                                markets: _markets,
                              ),
                        icon: const Icon(Icons.tune_rounded),
                        tooltip: 'All markets',
                      ),
                    ],
                  ),
                ),
              ),
              // ── Match hero card ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: ClayCard(
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    child: Column(
                      children: [
                        Text(
                          fixture.competitionName.toUpperCase(),
                          style: TypographyTokens.labelMedium(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          fixture.homeTeamName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TypographyTokens.monolithFont(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: ColorTokens.onSurface,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            fixture.isLive &&
                                    fixture.homeScore != null &&
                                    fixture.awayScore != null
                                ? '${fixture.homeScore} - ${fixture.awayScore}'
                                : 'VS',
                            style: TypographyTokens.monolithFont(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ColorTokens.clubAccent,
                            ),
                          ),
                        ),
                        Text(
                          fixture.awayTeamName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TypographyTokens.monolithFont(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: ColorTokens.onSurface,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Text(
                          _formatKickoff(),
                          style: TypographyTokens.editorialFont(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ColorTokens.onSurfaceVariant,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (fixture.venueName != null &&
                            fixture.venueName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            fixture.venueName!.toUpperCase(),
                            style: TypographyTokens.editorialFont(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: ColorTokens.onSurfaceVariant,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                        const SizedBox(height: SpacingTokens.spacing4),
                        Wrap(
                          spacing: SpacingTokens.spacing2,
                          runSpacing: SpacingTokens.spacing2,
                          children: [
                            if (fixture.competitionSlug.isNotEmpty)
                              _HeaderLinkChip(
                                label: 'League Hub',
                                onTap: () => context.push(
                                  '/fanzone/league/${fixture.competitionSlug}',
                                ),
                              ),
                            if (fixture.homeTeamSlug.isNotEmpty)
                              _HeaderLinkChip(
                                label: fixture.homeTeamShort.toUpperCase(),
                                onTap: () => context.push(
                                  '/fanzone/team/${fixture.homeTeamSlug}',
                                ),
                              ),
                            if (fixture.awayTeamSlug.isNotEmpty)
                              _HeaderLinkChip(
                                label: fixture.awayTeamShort.toUpperCase(),
                                onTap: () => context.push(
                                  '/fanzone/team/${fixture.awayTeamSlug}',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Tab bar ──
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  tabBar: TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    indicatorColor: ColorTokens.clubAccent,
                    indicatorWeight: 2.5,
                    labelColor: ColorTokens.clubAccent,
                    unselectedLabelColor: ColorTokens.onSurfaceVariant,
                    labelStyle: TypographyTokens.editorialFont(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                    unselectedLabelStyle: TypographyTokens.editorialFont(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: _tabLabels
                        .map((label) => Tab(text: label))
                        .toList(growable: false),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                // ── Predict tab ──
                _PredictTabBody(
                  fixture: fixture,
                  markets: _markets,
                  communityPicks: _communityPicks,
                ),
                // ── Stats tab ──
                _StatsTabBody(fixture: fixture),
                // ── H2H tab ──
                H2hTabBody(
                  homeTeamName: fixture.homeTeamName,
                  awayTeamName: fixture.awayTeamName,
                  homeTeamShort: fixture.homeTeamShort,
                  awayTeamShort: fixture.awayTeamShort,
                  encounters: _h2hEncounters,
                ),
                // ── Lineups tab ──
                LineupsTabBody(
                  homeTeamName: fixture.homeTeamName,
                  awayTeamName: fixture.awayTeamName,
                  homeTeamShort: fixture.homeTeamShort,
                  awayTeamShort: fixture.awayTeamShort,
                  homeLineup: _homeLineup,
                  awayLineup: _awayLineup,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab bar persistent header delegate ─────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: ColorTokens.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ── Predict tab body ───────────────────────────────────────────────────

class _PredictTabBody extends StatelessWidget {
  const _PredictTabBody({
    required this.fixture,
    required this.markets,
    required this.communityPicks,
  });

  final FixtureSummary fixture;
  final List<FixtureMarket> markets;
  final Map<String, List<CommunityPick>> communityPicks;

  @override
  Widget build(BuildContext context) {
    final featuredMarkets = markets.take(4).toList(growable: false);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
              vertical: SpacingTokens.spacing4,
            ),
            child: Row(
              children: [
                Text(
                  'TOP MARKETS',
                  style: TypographyTokens.monolithFont(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: markets.isEmpty
                      ? null
                      : () => showMarketSelectorSheet(
                          context: context,
                          fixture: fixture,
                          markets: markets,
                        ),
                  icon: const Icon(Icons.grid_view_rounded, size: 16),
                  label: const Text('All markets'),
                ),
              ],
            ),
          ),
        ),
        SliverList.separated(
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
            ),
            child: _MarketCard(
              fixture: fixture,
              market: featuredMarkets[index],
              communityPicks:
                  communityPicks[featuredMarkets[index].fixtureMarketId] ??
                  const <CommunityPick>[],
            ),
          ),
          separatorBuilder: (_, __) =>
              const SizedBox(height: SpacingTokens.spacing3),
          itemCount: featuredMarkets.length,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ── Stats tab body ─────────────────────────────────────────────────────

class _StatsTabBody extends StatelessWidget {
  const _StatsTabBody({required this.fixture});

  final FixtureSummary fixture;

  @override
  Widget build(BuildContext context) {
    // Build stats from actual match data when scores are available.
    final hasScores = fixture.homeScore != null && fixture.awayScore != null;

    if (!hasScores) {
      // No live or final stats available — show informative empty state.
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          const SizedBox(height: SpacingTokens.spacing8),
          const AfriEmptyView(
            compact: true,
            title: 'Stats not yet available',
            message:
                'Match statistics will appear here once the match is live or has been completed.',
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          GlassCard(
            animate: false,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: ColorTokens.onSurfaceVariant,
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Expanded(
                  child: Text(
                    'Live stats update automatically during the match.',
                    style: TypographyTokens.bodySmall(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Show score-based summary stats for live or completed matches.
    final homeGoals = fixture.homeScore ?? 0;
    final awayGoals = fixture.awayScore ?? 0;
    final totalGoals = homeGoals + awayGoals;

    final liveStats = <MatchStatRow>[
      MatchStatRow(
        label: 'Goals',
        leftValue: homeGoals,
        rightValue: awayGoals,
        leftDisplay: '$homeGoals',
        rightDisplay: '$awayGoals',
      ),
      MatchStatRow(
        label: 'Total Goals',
        leftValue: totalGoals,
        rightValue: totalGoals,
        leftDisplay: '$totalGoals',
        rightDisplay: '$totalGoals',
      ),
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        StatsPanel(
          stats: liveStats,
          homeLabel: fixture.homeTeamShort,
          awayLabel: fixture.awayTeamShort,
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        GlassCard(
          animate: false,
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: ColorTokens.onSurfaceVariant,
              ),
              const SizedBox(width: SpacingTokens.spacing2),
              Expanded(
                child: Text(
                  fixture.isLive
                      ? 'Live stats update automatically during the match.'
                      : 'Final match statistics.',
                  style: TypographyTokens.bodySmall(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Market card (unchanged) ────────────────────────────────────────────

class _MarketCard extends ConsumerWidget {
  const _MarketCard({
    required this.fixture,
    required this.market,
    required this.communityPicks,
  });

  final FixtureSummary fixture;
  final FixtureMarket market;
  final List<CommunityPick> communityPicks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slip = ref.watch(fanzoneSlipProvider);
    final selected = slip.items
        .where((item) => item.fixtureMarketId == market.fixtureMarketId)
        .toList(growable: false);
    final selectedOutcomeKey = selected.isEmpty
        ? null
        : selected.first.outcomeKey;

    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      market.marketName,
                      style: TypographyTokens.titleMedium(),
                    ),
                    if (market.description.isNotEmpty) ...[
                      const SizedBox(height: SpacingTokens.spacing1),
                      Text(
                        market.description,
                        style: TypographyTokens.bodySmall(),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing2,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+${market.fetValue} FET',
                  style: TypographyTokens.labelSmall(ColorTokens.clubAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (market.isLocked)
            Text(
              'Market locked for live/finished match state.',
              style: TypographyTokens.bodySmall(),
            )
          else
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: market.outcomes
                  .map((outcome) {
                    return MarketOptionPill(
                      label: outcome.label,
                      isSelected: selectedOutcomeKey == outcome.key,
                      trailing: selectedOutcomeKey == outcome.key
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: ColorTokens.clubAccent,
                            )
                          : null,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(fanzoneSlipProvider.notifier)
                            .addFromMarket(
                              fixture: fixture,
                              market: market,
                              outcome: outcome,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${outcome.label} added to your slip.',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    );
                  })
                  .toList(growable: false),
            ),
          if (communityPicks.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            CommunityPredictionBar(
              picks: communityPicks,
              userSelection:
                  selectedOutcomeKey ?? market.userPrediction?.selectedOutcome,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderLinkChip extends StatelessWidget {
  const _HeaderLinkChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing3,
          vertical: SpacingTokens.spacing2,
        ),
        decoration: BoxDecoration(
          color: ColorTokens.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
      ),
    );
  }
}
