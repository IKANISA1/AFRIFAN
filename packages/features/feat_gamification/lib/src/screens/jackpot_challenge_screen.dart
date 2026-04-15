import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../widgets/market_option_pill.dart';

class JackpotChallengeScreen extends ConsumerStatefulWidget {
  const JackpotChallengeScreen({super.key});

  @override
  ConsumerState<JackpotChallengeScreen> createState() =>
      _JackpotChallengeScreenState();
}

class _JackpotChallengeScreenState
    extends ConsumerState<JackpotChallengeScreen> {
  List<_JackpotFixtureData> _fixtures = const <_JackpotFixtureData>[];
  List<PredictionLeaderboardEntry> _leaders =
      const <PredictionLeaderboardEntry>[];
  final Map<String, String> _selections = <String, String>{};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  String _prizePoolLabel = 'PRIZE POOL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(predictionRepositoryProvider);
      final fetRepo = ref.read(fetRepositoryProvider);

      // Load fixtures via calendar API (next 7 days)
      final now = DateTime.now();
      final weekLater = now.add(const Duration(days: 7));
      final dateFrom = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final dateTo = '${weekLater.year}-${weekLater.month.toString().padLeft(2, '0')}-${weekLater.day.toString().padLeft(2, '0')}';

      final fixtures = await repo.loadFixturesByDate(
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: 'scheduled',
        limit: 10,
      );
      final marketResults = await Future.wait<List<FixtureMarket>>(
        fixtures.map((fixture) => repo.loadFixtureMarkets(fixture.id)),
      );
      final leaders = await repo.loadLeaderboard(limit: 5);

      final jackpotFixtures = <_JackpotFixtureData>[];
      for (var index = 0; index < fixtures.length; index++) {
        final market = _selectJackpotMarket(marketResults[index]);
        if (market != null) {
          jackpotFixtures.add(
            _JackpotFixtureData(fixture: fixtures[index], market: market),
          );
        }
      }

      if (!mounted) {
        return;
      }

      // Compute dynamic prize pool from FET catalog.
      String prizeLabel = 'PRIZE POOL';
      try {
        final catalog = await fetRepo.loadCatalog();
        if (catalog.isNotEmpty) {
          final totalFet = catalog.fold<int>(
            0,
            (sum, item) => sum + item.fetValue,
          );
          prizeLabel = 'PRIZE POOL · ${_formatFet(totalFet)} FET';
        }
      } catch (_) {
        // Keep default label.
      }

      setState(() {
        _fixtures = jackpotFixtures;
        _leaders = leaders;
        _prizePoolLabel = prizeLabel;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Jackpot challenge is temporarily unavailable.';
      });
    }
  }

  FixtureMarket? _selectJackpotMarket(List<FixtureMarket> markets) {
    for (final market in markets) {
      final slug = market.marketSlug.toLowerCase();
      final name = market.marketName.toLowerCase();
      final shortName = market.marketShortName.toLowerCase();
      if (slug.contains('1x2') ||
          shortName == 'ftr' ||
          name.contains('full time result')) {
        return market;
      }
    }
    return markets.cast<FixtureMarket?>().firstWhere(
      (market) =>
          market != null &&
          market.outcomes.length == 3 &&
          market.outcomes.any((outcome) => outcome.label == '1') &&
          market.outcomes.any((outcome) => outcome.label == 'X') &&
          market.outcomes.any((outcome) => outcome.label == '2'),
      orElse: () => null,
    );
  }

  Future<void> _submit() async {
    if (_fixtures.isEmpty ||
        _selections.length != _fixtures.length ||
        _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ref.read(predictionRepositoryProvider);
      final result = await repo.placeAcca(
        _fixtures
            .map((entry) {
              return <String, String>{
                'fixture_market_id': entry.market.fixtureMarketId,
                'selected_outcome':
                    _selections[entry.market.fixtureMarketId] ?? '',
              };
            })
            .toList(growable: false),
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClayCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: ColorTokens.clubAccent,
                  size: 40,
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  'JACKPOT ENTRY LOCKED',
                  textAlign: TextAlign.center,
                  style: TypographyTokens.monolithFont(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  result.message.isEmpty
                      ? 'Your 10-leg jackpot ticket is now live.'
                      : result.message,
                  textAlign: TextAlign.center,
                  style: TypographyTokens.bodyMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                AfriButton(
                  onTap: () => Navigator.of(context).pop(),
                  label: 'Done',
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      context.push('/fanzone/my');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit the jackpot entry right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _kickoffLabel(DateTime? value) {
    if (value == null) {
      return 'TBD';
    }
    final local = value.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final completion = _fixtures.isEmpty
        ? 0.0
        : _selections.length / _fixtures.length;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'JACKPOT CHALLENGE',
          style: TypographyTokens.monolithFont(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.spacing6,
            0,
            SpacingTokens.spacing6,
            SpacingTokens.spacing6,
          ),
          child: AfriButton(
            onTap: _selections.length == _fixtures.length && !_isSubmitting
                ? _submit
                : () {},
            label: _isSubmitting
                ? 'Submitting...'
                : 'Submit Entry · ${_selections.length}/${_fixtures.length}',
            enabled: _selections.length == _fixtures.length && !_isSubmitting,
            isLoading: _isSubmitting,
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
                  title: 'Jackpot unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: ColorTokens.clubAccent,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  ClayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.spacing3,
                            vertical: SpacingTokens.spacing1,
                          ),
                          decoration: BoxDecoration(
                            color: ColorTokens.clubAccent.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _prizePoolLabel,
                            style: TypographyTokens.labelSmall(
                              ColorTokens.clubAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          'Ten fixtures. One shot. Free entry into the current FANZONE mega-ticket.',
                          style: TypographyTokens.bodyMedium(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        LinearProgressIndicator(
                          value: completion,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(999),
                          color: ColorTokens.clubAccent,
                          backgroundColor: ColorTokens.surfaceContainerHighest,
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          '${_selections.length} of ${_fixtures.length} picks done',
                          style: TypographyTokens.bodySmall(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  ..._fixtures.asMap().entries.map((entry) {
                    final data = entry.value;
                    final selection = _selections[data.market.fixtureMarketId];
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: SpacingTokens.spacing3,
                      ),
                      child: ClayCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: ColorTokens.clubAccent.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: TypographyTokens.monolithFont(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: ColorTokens.clubAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: SpacingTokens.spacing3),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data.fixture.fixtureLabel,
                                        style: TypographyTokens.titleSmall(),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${data.fixture.competitionName} · ${_kickoffLabel(data.fixture.kickoffAt)}',
                                        style: TypographyTokens.bodySmall(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: SpacingTokens.spacing3),
                            Wrap(
                              spacing: SpacingTokens.spacing2,
                              runSpacing: SpacingTokens.spacing2,
                              children: data.market.outcomes
                                  .map((outcome) {
                                    return MarketOptionPill(
                                      label: outcome.label,
                                      isSelected: selection == outcome.key,
                                      onTap: () {
                                        setState(() {
                                          _selections[data
                                                  .market
                                                  .fixtureMarketId] =
                                              outcome.key;
                                        });
                                      },
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_leaders.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    ClayCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WEEKLY LEADERS',
                            style: TypographyTokens.titleLarge(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          ..._leaders.take(5).map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: SpacingTokens.spacing3,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '#${entry.rank}',
                                      style: TypographyTokens.monolithFont(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.displayName,
                                      style: TypographyTokens.bodyMedium(),
                                    ),
                                  ),
                                  Text(
                                    '+${entry.totalFetEarned} FET',
                                    style: TypographyTokens.monolithFont(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: ColorTokens.clubAccent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 120),
                ],
              ),
            ),
    );
  }
}

class _JackpotFixtureData {
  const _JackpotFixtureData({required this.fixture, required this.market});

  final FixtureSummary fixture;
  final FixtureMarket market;
}

String _formatFet(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
  }
  return value.toString();
}

