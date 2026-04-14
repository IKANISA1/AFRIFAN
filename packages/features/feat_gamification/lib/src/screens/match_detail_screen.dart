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
import '../widgets/market_option_pill.dart';
import '../widgets/market_selector_sheet.dart';
import '../widgets/prediction_slip_widgets.dart';

class MatchDetailScreen extends ConsumerStatefulWidget {
  const MatchDetailScreen({super.key, required this.fixtureId});

  final String fixtureId;

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  FixtureSummary? _fixture;
  List<FixtureMarket> _markets = const <FixtureMarket>[];
  Map<String, List<CommunityPick>> _communityPicks =
      const <String, List<CommunityPick>>{};
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load match details right now.';
        _isLoading = false;
      });
    }
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
                      icon: const Icon(Icons.arrow_back_rounded),
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
    final featuredMarkets = _markets.take(4).toList(growable: false);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      bottomNavigationBar: PredictionSlipBar(onTap: _openSlip),
      body: GradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
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
                        icon: const Icon(Icons.arrow_back_rounded),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing6,
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
                        onPressed: _markets.isEmpty
                            ? null
                            : () => showMarketSelectorSheet(
                                context: context,
                                fixture: fixture,
                                markets: _markets,
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
                        _communityPicks[featuredMarkets[index]
                            .fixtureMarketId] ??
                        const <CommunityPick>[],
                  ),
                ),
                separatorBuilder: (_, __) =>
                    const SizedBox(height: SpacingTokens.spacing3),
                itemCount: featuredMarkets.length,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

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
