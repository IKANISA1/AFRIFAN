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

      final results = await Future.wait<Object?>([
        predictionRepository.loadUserStats(),
        fetRepository.loadWallet(),
        predictionRepository.loadFixtures(status: 'live', limit: 2),
        predictionRepository.loadFixtures(status: 'scheduled', limit: 4),
        predictionRepository.loadLeaderboard(limit: 5),
        predictionRepository.loadMarketCatalog(),
        fetRepository.loadCatalog(),
      ]);

      if (!mounted) return;
      setState(() {
        _dashboard = results[0] as PredictionDashboard;
        _wallet = results[1] as FetWalletSummary?;
        _liveFixtures = results[2]! as List<FixtureSummary>;
        _upcomingFixtures = results[3]! as List<FixtureSummary>;
        _leaderboard = results[4]! as List<PredictionLeaderboardEntry>;
        _markets = results[5]! as List<PredictionMarket>;
        _challenges = results[6]! as List<FetCatalogItem>;
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
            onPressed: () => context.push('/fanzone/my'),
            tooltip: 'My predictions',
            icon: const Icon(Icons.receipt_long_rounded),
          ),
          IconButton(
            onPressed: () => context.push('/fanzone/notifications'),
            tooltip: 'Prediction alerts',
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            onPressed: () => context.push('/fanzone/wallet'),
            tooltip: 'FET wallet',
            icon: const Icon(Icons.account_balance_wallet_rounded),
          ),
        ],
      ),
      bottomNavigationBar: PredictionSlipBar(onTap: _openSlip),
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
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing4,
                          SpacingTokens.spacing6,
                          0,
                        ),
                        child: _HeroCard(
                          dashboard: _dashboard,
                          wallet: _wallet,
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
                        child: _QuickRoutes(),
                      ),
                    ),
                    if (_liveFixtures.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            SpacingTokens.spacing6,
                            SpacingTokens.spacing6,
                            SpacingTokens.spacing6,
                            0,
                          ),
                          child: _SectionCard(
                            title: 'Live Matches',
                            subtitle:
                                'Fixtures already in play and ready for live follow-up.',
                            child: Column(
                              children: _liveFixtures
                                  .map(
                                    (fixture) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: SpacingTokens.spacing3,
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
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing6,
                          0,
                        ),
                        child: _SectionCard(
                          title: 'Upcoming Fixtures',
                          subtitle:
                              'Quick entry into the first prediction loop.',
                          actionLabel: 'Browse all',
                          onAction: () => context.push('/fanzone/fixtures'),
                          child: _upcomingFixtures.isEmpty
                              ? const Text('No upcoming fixtures loaded.')
                              : Column(
                                  children: _upcomingFixtures
                                      .map(
                                        (fixture) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: SpacingTokens.spacing3,
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
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing6,
                          0,
                        ),
                        child: _SectionCard(
                          title: 'Market Stack',
                          subtitle:
                              'Top launch markets, powered by the live catalog.',
                          child: Wrap(
                            spacing: SpacingTokens.spacing2,
                            runSpacing: SpacingTokens.spacing2,
                            children: _markets
                                .take(8)
                                .map(
                                  (market) => _MarketChip(
                                    label: market.shortName,
                                    value: market.defaultFetValue,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing6,
                          0,
                        ),
                        child: _SectionCard(
                          title: 'Leaderboard',
                          subtitle:
                              'Prediction rank ordered by FET earned and win rate.',
                          actionLabel: 'Open',
                          onAction: () => context.push('/fanzone/leaderboard'),
                          child: Column(
                            children: _leaderboard
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: SpacingTokens.spacing3,
                                    ),
                                    child: _LeaderboardRow(entry: entry),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing6,
                          SpacingTokens.spacing6,
                          120,
                        ),
                        child: _SectionCard(
                          title: 'Challenges',
                          subtitle:
                              'Current FET actions and engagement loops already configured.',
                          actionLabel: 'Open',
                          onAction: () => context.push('/fanzone/challenges'),
                          child: Column(
                            children: _challenges
                                .take(4)
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: SpacingTokens.spacing3,
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.dashboard, required this.wallet});

  final PredictionDashboard? dashboard;
  final FetWalletSummary? wallet;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing3,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: ColorTokens.success.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'LIVE ${dashboard?.activeCount ?? 0}',
                  style: TypographyTokens.labelSmall(ColorTokens.success),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing3,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${wallet?.balance ?? 0} FET',
                  style: TypographyTokens.labelSmall(ColorTokens.clubAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text(
            'Predict. Earn. Repeat.',
            style: TypographyTokens.monolithFont(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 0.95,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            'One consolidated FANZONE surface for fixtures, picks, rewards, and performance.',
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Win rate',
                  value: '${dashboard?.winRate.toStringAsFixed(0) ?? '0'}%',
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: _HeroMetric(
                  label: 'Current streak',
                  value: '${dashboard?.currentStreak ?? 0}',
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: _HeroMetric(
                  label: 'Wallet',
                  value: '${wallet?.balance ?? 0}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            value,
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickRoutes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, String route})>[
      (
        label: 'Fixtures',
        icon: Icons.calendar_month_rounded,
        route: '/fanzone/fixtures',
      ),
      (label: 'Live', icon: Icons.live_tv_rounded, route: '/fanzone/live'),
      (
        label: 'My Picks',
        icon: Icons.receipt_long_rounded,
        route: '/fanzone/my',
      ),
      (
        label: 'Leaderboard',
        icon: Icons.leaderboard_rounded,
        route: '/fanzone/leaderboard',
      ),
      (
        label: 'Wallet',
        icon: Icons.account_balance_wallet_rounded,
        route: '/fanzone/wallet',
      ),
      (label: 'Rewards', icon: Icons.redeem_rounded, route: '/fanzone/rewards'),
      (
        label: 'History',
        icon: Icons.history_rounded,
        route: '/fanzone/history',
      ),
      (
        label: 'Alerts',
        icon: Icons.notifications_none_rounded,
        route: '/fanzone/notifications',
      ),
      (
        label: 'Jackpot',
        icon: Icons.emoji_events_rounded,
        route: '/fanzone/jackpot',
      ),
      (
        label: 'League Hub',
        icon: Icons.table_chart_rounded,
        route: '/fanzone/league',
      ),
      (
        label: 'Club Zone',
        icon: Icons.groups_rounded,
        route: '/fanzone/club-zone',
      ),
      (
        label: 'Friends',
        icon: Icons.person_search_rounded,
        route: '/fanzone/friends',
      ),
      (
        label: 'Challenge',
        icon: Icons.compare_arrows_rounded,
        route: '/fanzone/challenge',
      ),
      (label: 'Share', icon: Icons.share_rounded, route: '/fanzone/share'),
      (
        label: 'Challenges',
        icon: Icons.flag_rounded,
        route: '/fanzone/challenges',
      ),
    ];

    return Wrap(
      spacing: SpacingTokens.spacing2,
      runSpacing: SpacingTokens.spacing2,
      children: items
          .map(
            (item) => AfriPressFeedback(
              onTap: () => context.push(item.route),
              tooltip: item.label,
              semanticsLabel: item.label,
              excludeChildSemantics: true,
              builder: (context, state) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing3,
                  vertical: SpacingTokens.spacing2,
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
                      size: 16,
                      color: ColorTokens.primaryContainer,
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Text(item.label, style: TypographyTokens.labelSmall()),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: TypographyTokens.titleLarge()),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(subtitle, style: TypographyTokens.bodySmall()),
          const SizedBox(height: SpacingTokens.spacing4),
          child,
        ],
      ),
    );
  }
}

class _HubFixtureRow extends StatelessWidget {
  const _HubFixtureRow({required this.fixture, required this.onTap});

  final FixtureSummary fixture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLive = fixture.isLive;
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
                    fixture.competitionName,
                    style: TypographyTokens.bodySmall(),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing2,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: (isLive ? ColorTokens.success : ColorTokens.clubAccent)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isLive ? 'LIVE' : 'PREDICT',
                  style: TypographyTokens.labelSmall(
                    isLive ? ColorTokens.success : ColorTokens.clubAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MarketChip extends StatelessWidget {
  const _MarketChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label · +$value FET',
        style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
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
        const SizedBox(width: SpacingTokens.spacing2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.displayName, style: TypographyTokens.titleSmall()),
              Text(
                '${entry.winRate.toStringAsFixed(1)}% win rate · ${entry.totalSettled} settled',
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
            Icons.stars_rounded,
            size: 18,
            color: ColorTokens.clubAccent,
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
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
