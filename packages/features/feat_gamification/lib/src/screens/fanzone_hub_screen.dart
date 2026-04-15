import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../widgets/prediction_slip_widgets.dart';

class FanzoneHubScreen extends ConsumerStatefulWidget {
  const FanzoneHubScreen({super.key});

  @override
  ConsumerState<FanzoneHubScreen> createState() => _FanzoneHubScreenState();
}

class _FanzoneHubScreenState extends ConsumerState<FanzoneHubScreen> {
  PredictionDashboard? _dashboard;
  FetWalletSummary? _wallet;
  List<FixtureSummary> _liveFixtures = const <FixtureSummary>[];
  List<FixtureSummary> _todayFixtures = const <FixtureSummary>[];
  List<FixtureSummary> _upcomingFixtures = const <FixtureSummary>[];
  List<PredictionLeaderboardEntry> _leaderboard =
      const <PredictionLeaderboardEntry>[];
  List<PredictionMarket> _markets = const <PredictionMarket>[];
  List<FetCatalogItem> _challenges = const <FetCatalogItem>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final predictionRepository = ref.read(predictionRepositoryProvider);
      final fetRepository = ref.read(fetRepositoryProvider);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekEnd = today.add(const Duration(days: 7));
      final tomorrow = today.add(const Duration(days: 1));

      final results = await Future.wait<Object?>([
        predictionRepository.loadUserStats(),
        fetRepository.loadWallet(),
        predictionRepository.loadFixtures(status: 'live', limit: 5),
        predictionRepository.loadFixturesByDate(
          dateFrom: today,
          dateTo: today,
        ),
        predictionRepository.loadFixturesByDate(
          dateFrom: tomorrow,
          dateTo: weekEnd,
          limit: 8,
        ),
        predictionRepository.loadLeaderboard(limit: 5),
        predictionRepository.loadMarketCatalog(),
        fetRepository.loadCatalog(),
      ]);

      if (!mounted) return;
      setState(() {
        _dashboard = results[0] as PredictionDashboard;
        _wallet = results[1] as FetWalletSummary?;
        _liveFixtures = results[2]! as List<FixtureSummary>;
        _todayFixtures = results[3]! as List<FixtureSummary>;
        _upcomingFixtures = results[4]! as List<FixtureSummary>;
        _leaderboard = results[5]! as List<PredictionLeaderboardEntry>;
        _markets = results[6]! as List<PredictionMarket>;
        _challenges = results[7]! as List<FetCatalogItem>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Fanzone is temporarily unavailable.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openSlip() async {
    await showPredictionSlipSheet(context, ref, onSubmitted: _loadData);
  }

  void _showOverflow() {
    showAfriActionSheet(
      context: context,
      title: 'Fanzone',
      actions: [
        AfriSheetAction(
          icon: AfriIcons.myPicks,
          label: 'My predictions',
          onTap: () => context.push('/fanzone/my'),
        ),
        AfriSheetAction(
          icon: AfriIcons.notifications,
          label: 'Alerts',
          onTap: () => context.push('/fanzone/notifications'),
        ),
        AfriSheetAction(
          icon: AfriIcons.wallet,
          label: 'FET wallet',
          onTap: () => context.push('/fanzone/wallet'),
        ),
        AfriSheetAction(
          icon: AfriIcons.rewards,
          label: 'Rewards store',
          onTap: () => context.push('/fanzone/rewards'),
        ),
        AfriSheetAction(
          icon: AfriIcons.history,
          label: 'Token history',
          onTap: () => context.push('/fanzone/history'),
        ),
        AfriSheetAction(
          icon: AfriIcons.friend,
          label: 'Friends',
          onTap: () => context.push('/fanzone/friends'),
        ),
        AfriSheetAction(
          icon: AfriIcons.versus,
          label: 'Challenge a friend',
          onTap: () => context.push('/fanzone/challenge'),
        ),
        AfriSheetAction(
          icon: AfriIcons.share,
          label: 'Share card',
          onTap: () => context.push('/fanzone/share'),
        ),
        AfriSheetAction(
          icon: AfriIcons.clubZone,
          label: 'Club zone',
          onTap: () => context.push('/fanzone/club-zone'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        title: Text(
          'FANZONE',
          style: TypographyTokens.monolithFont(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showOverflow,
            tooltip: 'More options',
            icon: const Icon(AfriIcons.more),
          ),
        ],
      ),
      bottomNavigationBar: PredictionSlipBar(onTap: _openSlip),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.screenPadding),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                child: AfriStateView.offline(
                  title: 'Fanzone unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadData,
                ),
              ),
            )
          : GradientBackground(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: ColorTokens.clubAccent,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // ── Hero stats ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.screenPadding,
                          SpacingTokens.spacing4,
                          SpacingTokens.screenPadding,
                          0,
                        ),
                        child: _HeroStats(
                          dashboard: _dashboard,
                          wallet: _wallet,
                        ),
                      ),
                    ),

                    // ── Quick routes (capped at 6) ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.screenPadding,
                          SpacingTokens.spacing4,
                          SpacingTokens.screenPadding,
                          0,
                        ),
                        child: _QuickRoutes(onMore: _showOverflow),
                      ),
                    ),

                    // ── Live matches ──
                    if (_liveFixtures.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            SpacingTokens.screenPadding,
                            SpacingTokens.sectionGap,
                            SpacingTokens.screenPadding,
                            0,
                          ),
                          child: AfriSectionCard(
                            title: 'Live Now',
                            child: Column(
                              children: _liveFixtures
                                  .map(
                                    (fixture) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: SpacingTokens.listItemGap,
                                      ),
                                      child: _HubFixtureRow(
                                        fixture: fixture,
                                        isLive: true,
                                        onTap: () => context.push(
                                          '/fanzone/match/${fixture.id}',
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                      ),

                    // ── Today's fixtures ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.screenPadding,
                          SpacingTokens.sectionGap,
                          SpacingTokens.screenPadding,
                          0,
                        ),
                        child: AfriSectionCard(
                          title: 'Today',
                          trailingLabel: 'Calendar',
                          onTrailingTap: () =>
                              context.push('/fanzone/fixtures'),
                          child: _todayFixtures.isEmpty
                              ? const AfriEmptyView(
                                  compact: true,
                                  title: 'No matches today',
                                  icon: AfriIcons.fixture,
                                )
                              : Column(
                                  children: _todayFixtures
                                      .map(
                                        (fixture) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: SpacingTokens.listItemGap,
                                          ),
                                          child: _HubFixtureRow(
                                            fixture: fixture,
                                            onTap: () => context.push(
                                              '/fanzone/match/${fixture.id}',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                        ),
                      ),
                    ),

                    // ── Upcoming fixtures (next 7 days) ──
                    if (_upcomingFixtures.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            SpacingTokens.screenPadding,
                            SpacingTokens.sectionGap,
                            SpacingTokens.screenPadding,
                            0,
                          ),
                          child: AfriSectionCard(
                            title: 'This Week',
                            trailingLabel: 'Browse',
                            onTrailingTap: () =>
                                context.push('/fanzone/fixtures'),
                            child: Column(
                              children: _upcomingFixtures
                                  .map(
                                    (fixture) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: SpacingTokens.listItemGap,
                                      ),
                                      child: _HubFixtureRow(
                                        fixture: fixture,
                                        showDate: true,
                                        onTap: () => context.push(
                                          '/fanzone/match/${fixture.id}',
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                      ),

                    // ── Markets ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.screenPadding,
                          SpacingTokens.sectionGap,
                          SpacingTokens.screenPadding,
                          0,
                        ),
                        child: AfriSectionCard(
                          title: 'Markets',
                          child: Wrap(
                            spacing: SpacingTokens.inlineGap,
                            runSpacing: SpacingTokens.inlineGap,
                            children: _markets
                                .take(8)
                                .map(
                                  (market) => AfriInfoChip(
                                    label:
                                        '${market.shortName} +${market.defaultFetValue}',
                                    color: ColorTokens.onSurfaceVariant,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),

                    // ── Leaderboard ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.screenPadding,
                          SpacingTokens.sectionGap,
                          SpacingTokens.screenPadding,
                          0,
                        ),
                        child: AfriSectionCard(
                          title: 'Leaderboard',
                          trailingLabel: 'Open',
                          onTrailingTap: () =>
                              context.push('/fanzone/leaderboard'),
                          child: Column(
                            children: _leaderboard
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: SpacingTokens.listItemGap,
                                    ),
                                    child: _LeaderboardRow(entry: entry),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),

                    // ── Challenges ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.screenPadding,
                          SpacingTokens.sectionGap,
                          SpacingTokens.screenPadding,
                          120,
                        ),
                        child: AfriSectionCard(
                          title: 'Challenges',
                          trailingLabel: 'Open',
                          onTrailingTap: () =>
                              context.push('/fanzone/challenges'),
                          child: Column(
                            children: _challenges
                                .take(4)
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: SpacingTokens.listItemGap,
                                    ),
                                    child: _ChallengeRow(item: item),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Hero stats — metrics only, no marketing copy ──
class _HeroStats extends StatelessWidget {
  const _HeroStats({required this.dashboard, required this.wallet});

  final PredictionDashboard? dashboard;
  final FetWalletSummary? wallet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status chips ──
        Wrap(
          spacing: SpacingTokens.inlineGap,
          children: [
            AfriInfoChip(
              label: 'LIVE ${dashboard?.activeCount ?? 0}',
              color: ColorTokens.success,
            ),
            AfriInfoChip(
              label: '${wallet?.balance ?? 0} FET',
              color: ColorTokens.clubAccent,
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        // ── Stat row ──
        AfriStatRow(
          stats: [
            AfriStat(
              label: 'Win rate',
              value: '${dashboard?.winRate.toStringAsFixed(0) ?? '0'}%',
            ),
            AfriStat(
              label: 'Streak',
              value: '${dashboard?.currentStreak ?? 0}',
            ),
            AfriStat(
              label: 'Balance',
              value: '${wallet?.balance ?? 0}',
              accentColor: ColorTokens.clubAccent,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Quick routes — capped at 6, rest goes to overflow ──
class _QuickRoutes extends StatelessWidget {
  const _QuickRoutes({required this.onMore});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, String route})>[
      (
        label: 'Fixtures',
        icon: AfriIcons.fixture,
        route: '/fanzone/fixtures',
      ),
      (
        label: 'My Picks',
        icon: AfriIcons.myPicks,
        route: '/fanzone/my',
      ),
      (
        label: 'Leaderboard',
        icon: AfriIcons.leaderboard,
        route: '/fanzone/leaderboard',
      ),
      (
        label: 'Wallet',
        icon: AfriIcons.wallet,
        route: '/fanzone/wallet',
      ),
      (
        label: 'Jackpot',
        icon: AfriIcons.rank,
        route: '/fanzone/jackpot',
      ),
      (
        label: 'League',
        icon: AfriIcons.league,
        route: '/fanzone/league',
      ),
    ];

    return Wrap(
      spacing: SpacingTokens.inlineGap,
      runSpacing: SpacingTokens.inlineGap,
      children: [
        ...items.map(
          (item) => AfriPressFeedback(
            onTap: () => context.push(item.route),
            tooltip: item.label,
            semanticsLabel: item.label,
            excludeChildSemantics: true,
            builder: (context, state) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing3,
                vertical: SpacingTokens.inlineGap,
              ),
              decoration: BoxDecoration(
                color: ColorTokens.surfaceContainerHigh.withValues(
                  alpha: state.isPressed ? 0.92 : 0.78,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: AfriIcons.sizeChip,
                    color: ColorTokens.primaryContainer,
                  ),
                  const SizedBox(width: SpacingTokens.inlineGap),
                  Text(item.label, style: TypographyTokens.labelSmall()),
                ],
              ),
            ),
          ),
        ),
        // ── More chip ──
        AfriPressFeedback(
          onTap: onMore,
          tooltip: 'More options',
          semanticsLabel: 'More options',
          excludeChildSemantics: true,
          builder: (context, state) => Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing3,
              vertical: SpacingTokens.inlineGap,
            ),
            decoration: BoxDecoration(
              color: ColorTokens.surfaceContainerHigh.withValues(
                alpha: state.isPressed ? 0.92 : 0.78,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AfriIcons.more,
                  size: AfriIcons.sizeChip,
                  color: ColorTokens.onSurfaceVariant,
                ),
                const SizedBox(width: SpacingTokens.inlineGap),
                Text(
                  'More',
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HubFixtureRow extends StatelessWidget {
  const _HubFixtureRow({
    required this.fixture,
    required this.onTap,
    this.isLive = false,
    this.showDate = false,
  });

  final FixtureSummary fixture;
  final VoidCallback onTap;
  final bool isLive;
  final bool showDate;

  String _kickoffTime() {
    final kickoff = fixture.kickoffAt;
    if (kickoff == null) return 'TBD';
    final local = kickoff.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _dateLabel() {
    final kickoff = fixture.kickoffAt;
    if (kickoff == null) return '';
    final local = kickoff.toLocal();
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${dayNames[local.weekday - 1]} ${local.day}/${local.month}';
  }

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      tooltip: fixture.fixtureLabel,
      semanticsLabel: fixture.fixtureLabel,
      excludeChildSemantics: true,
      builder: (context, state) => GlassCard(
        animate: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fixture.fixtureLabel,
                    style: TypographyTokens.titleSmall(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    showDate
                        ? '${fixture.competitionName}  ·  ${_dateLabel()} ${_kickoffTime()}'
                        : '${fixture.competitionName}  ·  ${_kickoffTime()}',
                    style: TypographyTokens.bodySmall(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (fixture.homeScore != null && fixture.awayScore != null)
              Text(
                '${fixture.homeScore} - ${fixture.awayScore}',
                style: TypographyTokens.monolithFont(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              AfriInfoChip(
                label: isLive ? 'LIVE' : 'PREDICT',
                color: isLive ? ColorTokens.success : ColorTokens.clubAccent,
              ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final PredictionLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            '#${entry.rank}',
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: entry.rank == 1
                  ? ColorTokens.clubAccent
                  : ColorTokens.onSurface,
            ),
          ),
        ),
        const SizedBox(width: SpacingTokens.inlineGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.displayName, style: TypographyTokens.titleSmall()),
              Text(
                '${entry.winRate.toStringAsFixed(0)}% · ${entry.totalSettled} settled',
                style: TypographyTokens.bodySmall(),
              ),
            ],
          ),
        ),
        Text(
          '+${entry.totalFetEarned}',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ColorTokens.clubAccent,
          ),
        ),
      ],
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({required this.item});

  final FetCatalogItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ColorTokens.clubAccent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            AfriIcons.earn,
            size: 18,
            color: ColorTokens.clubAccent,
          ),
        ),
        const SizedBox(width: SpacingTokens.listItemGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.itemName, style: TypographyTokens.titleSmall()),
              const SizedBox(height: SpacingTokens.spacing1),
              Text(
                item.description.isEmpty
                    ? item.triggerCondition
                    : item.description,
                style: TypographyTokens.bodySmall(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Text(
          '+${item.fetValue}',
          style: TypographyTokens.monolithFont(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ColorTokens.clubAccent,
          ),
        ),
      ],
    );
  }
}
