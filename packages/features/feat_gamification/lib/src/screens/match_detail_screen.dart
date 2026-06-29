import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/partner_pool_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../widgets/fanzone_hub_widgets.dart';
import '../widgets/h2h_tab_body.dart';
import '../widgets/lineups_tab_body.dart';
import '../widgets/match_detail_widgets.dart';
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
  List<PartnerPredictionPool> _partnerPools = const <PartnerPredictionPool>[];
  List<MatchStatRow> _stats = const <MatchStatRow>[];
  List<H2hEncounter> _h2hEncounters = const <H2hEncounter>[];
  List<LineupPlayer> _homeLineup = const <LineupPlayer>[];
  List<LineupPlayer> _awayLineup = const <LineupPlayer>[];
  bool _isLoading = true;
  String? _error;

  late final TabController _tabController;

  static const _tabLabels = <String>['Pools', 'Stats', 'H2H', 'Lineups'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    unawaited(_loadData());
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
      final partnerPoolRepo = ref.read(partnerPoolRepositoryProvider);
      final results = await Future.wait<Object?>([
        repo.loadFixture(widget.fixtureId),
        repo.loadMatchCenter(widget.fixtureId),
        partnerPoolRepo.loadPools(limit: 50),
      ]);

      if (!mounted) {
        return;
      }

      final matchCenter = results[1] as PredictionMatchCenter?;
      final partnerPools = (results[2]! as List<PartnerPredictionPool>)
          .where((pool) => pool.fixtureId == widget.fixtureId)
          .toList(growable: false);

      setState(() {
        _fixture = results[0] as FixtureSummary?;
        _partnerPools = partnerPools;
        _stats =
            matchCenter?.stats
                .map(
                  (stat) => MatchStatRow(
                    label: stat.label,
                    leftValue: stat.leftValue,
                    rightValue: stat.rightValue,
                    leftDisplay: stat.leftDisplay,
                    rightDisplay: stat.rightDisplay,
                  ),
                )
                .toList(growable: false) ??
            const <MatchStatRow>[];
        _h2hEncounters =
            matchCenter?.h2h
                .map(
                  (row) => H2hEncounter(
                    homeTeam: row.homeTeam,
                    awayTeam: row.awayTeam,
                    homeScore: row.homeScore,
                    awayScore: row.awayScore,
                    date: row.date,
                    competition: row.competition,
                  ),
                )
                .toList(growable: false) ??
            const <H2hEncounter>[];
        _homeLineup = _toLineupPlayers(matchCenter?.homeLineup);
        _awayLineup = _toLineupPlayers(matchCenter?.awayLineup);
        _isLoading = false;
        _error = _fixture == null ? 'Fixture not found.' : null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'MatchDetailScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not load match details right now.';
        _isLoading = false;
      });
    }
  }

  List<LineupPlayer> _toLineupPlayers(MatchCenterLineup? lineup) {
    if (lineup == null) {
      return const <LineupPlayer>[];
    }
    final ordered = <MatchCenterLineupPlayer>[
      ...lineup.starters,
      ...lineup.substitutes,
    ];
    return ordered
        .map(
          (row) => LineupPlayer(
            name: row.name,
            number: row.number,
            position: row.position,
            isStarter: row.isStarter,
          ),
        )
        .toList(growable: false);
  }

  String _formatKickoff() {
    final kickoff = _fixture?.kickoffAt;
    if (kickoff == null) {
      return 'Kickoff TBD';
    }
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
    return '${dayNames[local.weekday - 1]} ${local.day} ${monthNames[local.month - 1]} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          backgroundColor: ColorTokens.transparent,
          leading: AfriIconButton(
            icon: AfriIcons.back,
            onTap: () => context.pop(),
            tooltip: 'Back',
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriSkeletonList(),
        ),
      );
    }

    if (_fixture == null) {
      return Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          backgroundColor: ColorTokens.transparent,
          leading: AfriIconButton(
            icon: AfriIcons.back,
            onTap: () => context.pop(),
            tooltip: 'Back',
          ),
          title: Text(
            'Match',
            style: TypographyTokens.headlineSmall().copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            child: AfriErrorView(
              compact: true,
              message: _error,
              onRetry: _loadData,
            ),
          ),
        ),
      );
    }

    final fixture = _fixture!;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          '${fixture.homeTeamShort} vs ${fixture.awayTeamShort}',
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
        actions: [
          AfriIconButton(
            icon: AfriIcons.predict,
            onTap: () => context.go('/fanzone'),
            tooltip: 'Partner pools',
          ),
        ],
        bottom: AfriTabBar.line(
          controller: _tabController,
          tabs: _tabLabels
              .map((label) => Tab(text: label))
              .toList(growable: false),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.spacing6,
              SpacingTokens.spacing4,
              SpacingTokens.spacing6,
              0,
            ),
            child: AfriSurfaceCard(
              child: Column(
                children: [
                  Text(
                    fixture.competitionName,
                    style: TypographyTokens.labelMedium(
                      ColorTokens.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fixture.homeTeamShort.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TypographyTokens.titleLarge(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.spacing3,
                        ),
                        child: Text(
                          fixture.isLive &&
                                  fixture.homeScore != null &&
                                  fixture.awayScore != null
                              ? '${fixture.homeScore} - ${fixture.awayScore}'
                              : 'VS',
                          style: TypographyTokens.titleLarge(
                            ColorTokens.clubAccent,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          fixture.awayTeamShort.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TypographyTokens.titleLarge(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    _formatKickoff(),
                    style: TypographyTokens.bodySmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (fixture.venueName != null &&
                      fixture.venueName!.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing1 / 2),
                    Text(
                      fixture.venueName!,
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (fixture.competitionSlug.isNotEmpty ||
                      fixture.homeTeamSlug.isNotEmpty ||
                      fixture.awayTeamSlug.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    Wrap(
                      spacing: SpacingTokens.spacing2,
                      runSpacing: SpacingTokens.spacing2,
                      alignment: WrapAlignment.center,
                      children: [
                        if (fixture.competitionSlug.isNotEmpty)
                          MatchMetaLink(
                            label: 'League',
                            onTap: () {
                              unawaited(
                                context.push(
                                  '/fanzone/league/${fixture.competitionSlug}',
                                ),
                              );
                            },
                          ),
                        if (fixture.homeTeamSlug.isNotEmpty)
                          MatchMetaLink(
                            label: fixture.homeTeamShort,
                            onTap: () {
                              unawaited(
                                context.push(
                                  '/fanzone/team/${fixture.homeTeamSlug}',
                                ),
                              );
                            },
                          ),
                        if (fixture.awayTeamSlug.isNotEmpty)
                          MatchMetaLink(
                            label: fixture.awayTeamShort,
                            onTap: () {
                              unawaited(
                                context.push(
                                  '/fanzone/team/${fixture.awayTeamSlug}',
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MatchPartnerPoolsTabBody(
                  fixture: fixture,
                  pools: _partnerPools,
                  onJoin: (pool) => _showPartnerPoolJoinSheet(pool),
                ),
                MatchStatsTabBody(fixture: fixture, stats: _stats),
                H2hTabBody(
                  homeTeamName: fixture.homeTeamName,
                  awayTeamName: fixture.awayTeamName,
                  homeTeamShort: fixture.homeTeamShort,
                  awayTeamShort: fixture.awayTeamShort,
                  encounters: _h2hEncounters,
                ),
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
        ],
      ),
    );
  }

  Future<void> _showPartnerPoolJoinSheet(PartnerPredictionPool pool) {
    const outcomes = <PartnerPoolOutcome>[
      PartnerPoolOutcome.homeWin,
      PartnerPoolOutcome.draw,
      PartnerPoolOutcome.awayWin,
    ];

    var selectedOutcome = PartnerPoolOutcome.homeWin;
    var isSubmitting = false;

    return showAfriBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setSheetState) {
            Future<void> submit() async {
              if (isSubmitting) return;
              setSheetState(() => isSubmitting = true);

              final result = await ref
                  .read(partnerPoolRepositoryProvider)
                  .joinPool(
                    poolId: pool.id,
                    selectedOutcome: selectedOutcome.rpcValue,
                    idempotencyKey:
                        '${pool.id}-${selectedOutcome.rpcValue}-${DateTime.now().microsecondsSinceEpoch}',
                  );

              if (!sheetContext.mounted) return;

              if (result.status == 'error') {
                setSheetState(() => isSubmitting = false);
                AfriToast.error(
                  sheetContext,
                  'Pool entry could not be recorded.',
                );
                return;
              }

              closeAfriBottomSheet(sheetContext);
              await _loadData();

              if (!mounted) return;
              AfriToast.success(
                context,
                '${selectedOutcome.label} joined for ${pool.fanEntryFet} FET.',
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(pool.title, style: TypographyTokens.sectionTitle()),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  '${pool.partnerName} funds ${pool.partnerStakeFet} FET. '
                  'Your fixed entry is ${pool.fanEntryFet} FET.',
                  style: TypographyTokens.bodyMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  pool.eligibilityLabel,
                  style: TypographyTokens.labelMedium(ColorTokens.clubAccent),
                ),
                const SizedBox(height: SpacingTokens.spacing5),
                ...outcomes.map(
                  (outcome) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: SpacingTokens.spacing3,
                    ),
                    child: PartnerPoolOutcomeOption(
                      outcome: outcome,
                      isSelected: selectedOutcome == outcome,
                      onTap: () =>
                          setSheetState(() => selectedOutcome = outcome),
                    ),
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                AfriButton(
                  label: 'Stake ${pool.fanEntryFet} FET',
                  icon: AfriIcons.predict,
                  isLoading: isSubmitting,
                  onTap: submit,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MatchPartnerPoolsTabBody extends StatelessWidget {
  const _MatchPartnerPoolsTabBody({
    required this.fixture,
    required this.pools,
    required this.onJoin,
  });

  final FixtureSummary fixture;
  final List<PartnerPredictionPool> pools;
  final ValueChanged<PartnerPredictionPool> onJoin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: [
        AfriSectionCard(
          title: 'Partner WDW Pools',
          child: pools.isEmpty
              ? AfriEmptyView(
                  compact: true,
                  title: 'No partner pool for this match',
                  message:
                      'Football predictions open only when a partner creates a fixed-entry WDW pool for this fixture.',
                  icon: AfriIcons.predict,
                  actionLabel: 'View Fanzone',
                  onAction: () => context.go('/fanzone'),
                )
              : Column(
                  children: pools
                      .map(
                        (pool) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.listItemGap,
                          ),
                          child: HubPartnerPoolRow(
                            pool: pool,
                            onJoin: () => onJoin(pool),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        AfriSurfaceCard(
          child: Row(
            children: [
              Icon(
                AfriIcons.statusInfo,
                size: SpacingTokens.spacing4,
                color: ColorTokens.onSurfaceVariant,
              ),
              const SizedBox(width: SpacingTokens.spacing2),
              Expanded(
                child: Text(
                  '${fixture.homeTeamShort} vs ${fixture.awayTeamShort} uses partner-funded WDW pools only.',
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
