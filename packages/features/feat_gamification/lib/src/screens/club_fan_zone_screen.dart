import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';

class ClubFanZoneScreen extends ConsumerStatefulWidget {
  const ClubFanZoneScreen({super.key});

  @override
  ConsumerState<ClubFanZoneScreen> createState() => _ClubFanZoneScreenState();
}

class _ClubFanZoneScreenState extends ConsumerState<ClubFanZoneScreen> {
  List<CompetitionCatalogItem> _competitions = const <CompetitionCatalogItem>[];
  CompetitionCatalogItem? _selectedCompetition;
  List<LeagueStandingEntry> _standings = const <LeagueStandingEntry>[];
  List<_FixturePulse> _pulse = const <_FixturePulse>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load([String? competitionSlug]) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(predictionRepositoryProvider);
      final competitions = await repo.loadCompetitionCatalog();
      final selectedSlug =
          competitionSlug ??
          _selectedCompetition?.slug ??
          (competitions.isEmpty ? null : competitions.first.slug);

      if (selectedSlug == null) {
        throw Exception('Competition catalog is pending.');
      }

      final selectedCompetition = competitions
          .cast<CompetitionCatalogItem?>()
          .firstWhere((item) => item?.slug == selectedSlug, orElse: () => null);

      final standings = await repo.loadStandings(
        competitionSlug: selectedSlug,
        limit: 6,
      );
      final now = DateTime.now();
      final twoWeeks = now.add(const Duration(days: 14));

      final fixtures = await repo.loadFixturesByDate(
        dateFrom: now,
        dateTo: twoWeeks,
        competitionSlug: selectedSlug,
        status: 'scheduled',
        limit: 3,
      );
      final communityResults = await Future.wait<List<CommunityPick>>(
        fixtures.map((fixture) => repo.loadFixtureCommunityPicks(fixture.id)),
      );

      final pulse = <_FixturePulse>[];
      for (var index = 0; index < fixtures.length; index++) {
        final picks = communityResults[index];
        if (picks.isEmpty) {
          continue;
        }
        final strongest = picks.first;
        pulse.add(
          _FixturePulse(
            fixture: fixtures[index],
            marketName: strongest.marketShortName.isEmpty
                ? strongest.marketName
                : strongest.marketShortName,
            leadingOutcome: strongest.selectedOutcome,
            leadingPercentage: strongest.pickPercentage,
          ),
        );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _competitions = competitions;
        _selectedCompetition = selectedCompetition;
        _standings = standings;
        _pulse = pulse;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ClubFanZoneScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Club fan zone is temporarily unavailable.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'CLUB FAN ZONE',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      scrollable: false,
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: 'Fan zone unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                ),
              ),
            )
          : AfriRefreshIndicator(
              onRefresh: () => _load(_selectedCompetition?.slug),
              color: ColorTokens.clubAccent,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  if (_competitions.isNotEmpty)
                    SizedBox(
                      height: SpacingTokens.spacing10,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _competitions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: SpacingTokens.spacing2),
                        itemBuilder: (context, index) {
                          final item = _competitions[index];
                          final selected =
                              item.slug == _selectedCompetition?.slug;
                          return AfriPressFeedback(
                            onTap: () => _load(item.slug),
                            builder: (context, _) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpacingTokens.spacing3,
                                vertical: SpacingTokens.spacing2,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? ColorTokens.clubAccent.withValues(
                                        alpha: 0.16,
                                      )
                                    : ColorTokens.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  ShapeTokens.radiusFull,
                                ),
                              ),
                              child: Text(
                                item.shortName.toUpperCase(),
                                style: TypographyTokens.labelSmall(
                                  selected
                                      ? ColorTokens.clubAccent
                                      : ColorTokens.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCompetition?.name.toUpperCase() ??
                              'SUPPORTER PULSE',
                          style: TypographyTokens.headlineLarge().copyWith(
                            fontWeight: FontWeight.w900,
                            height: TypographyTokens.lineHeightCompact,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          'Real supporter momentum around active competitions, fixture picks, and top clubs.',
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOP CLUBS', style: TypographyTokens.titleLarge()),
                        const SizedBox(height: SpacingTokens.spacing3),
                        ..._standings.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: SpacingTokens.spacing3,
                            ),
                            child: AfriPressFeedback(
                              onTap: () => context.push(
                                '/fanzone/team/${entry.teamSlug}',
                              ),
                              builder: (context, _) => GlassCard(
                                animate: false,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: SpacingTokens.spacing7,
                                      child: Text(
                                        '#${entry.position}',
                                        style: TypographyTokens.titleSmall()
                                            .copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.teamName,
                                        style: TypographyTokens.titleSmall(),
                                      ),
                                    ),
                                    Text(
                                      '${entry.points} pts',
                                      style: TypographyTokens.titleSmall(
                                        ColorTokens.clubAccent,
                                      ).copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SUPPORTER LEANS',
                          style: TypographyTokens.titleLarge(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        if (_pulse.isEmpty)
                          Text(
                            'Community pick distribution will appear once this competition has active ${RuntimeBranding.displayAppName} predictions.',
                          )
                        else
                          ..._pulse.map((pulse) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: SpacingTokens.spacing3,
                              ),
                              child: AfriPressFeedback(
                                onTap: () => context.push(
                                  '/fanzone/match/${pulse.fixture.id}',
                                ),
                                builder: (context, _) => GlassCard(
                                  animate: false,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pulse.fixture.fixtureLabel,
                                        style: TypographyTokens.titleSmall(),
                                      ),
                                      const SizedBox(
                                        height: SpacingTokens.spacing1 / 2,
                                      ),
                                      Text(
                                        '${pulse.marketName.toUpperCase()} · ${pulse.leadingOutcome.toUpperCase()}',
                                        style: TypographyTokens.bodySmall(),
                                      ),
                                      const SizedBox(
                                        height: SpacingTokens.spacing3,
                                      ),
                                      AfriLinearProgressIndicator(
                                        value: (pulse.leadingPercentage / 100)
                                            .clamp(0.0, 1.0),
                                        minHeight:
                                            SpacingTokens.spacing3 -
                                            (SpacingTokens.spacing1 / 2),
                                        borderRadius: BorderRadius.circular(
                                          ShapeTokens.radiusFull,
                                        ),
                                        color: ColorTokens.clubAccent,
                                        backgroundColor:
                                            ColorTokens.surfaceContainerHighest,
                                      ),
                                      const SizedBox(
                                        height:
                                            SpacingTokens.spacing1 +
                                            (SpacingTokens.spacing1 / 2),
                                      ),
                                      Text(
                                        '${pulse.leadingPercentage.toStringAsFixed(1)}% of supporters currently lean this way.',
                                        style: TypographyTokens.bodySmall(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FixturePulse {
  const _FixturePulse({
    required this.fixture,
    required this.marketName,
    required this.leadingOutcome,
    required this.leadingPercentage,
  });

  final FixtureSummary fixture;
  final String marketName;
  final String leadingOutcome;
  final double leadingPercentage;
}
