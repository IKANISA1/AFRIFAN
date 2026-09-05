import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';

class LeagueHubScreen extends ConsumerStatefulWidget {
  const LeagueHubScreen({super.key, this.competitionSlug});

  final String? competitionSlug;

  @override
  ConsumerState<LeagueHubScreen> createState() => _LeagueHubScreenState();
}

class _LeagueHubScreenState extends ConsumerState<LeagueHubScreen> {
  List<CompetitionCatalogItem> _competitions = const <CompetitionCatalogItem>[];
  CompetitionCatalogItem? _competition;
  List<LeagueStandingEntry> _standings = const <LeagueStandingEntry>[];
  List<FixtureSummary> _fixtures = const <FixtureSummary>[];
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
      final resolvedSlug =
          competitionSlug ??
          widget.competitionSlug ??
          competitions.firstOrNull?.slug;

      if (resolvedSlug == null) {
        throw Exception('Competition catalog is pending.');
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final futureEnd = today.add(const Duration(days: 30));

      final results = await Future.wait<Object?>([
        repo.loadCompetition(resolvedSlug),
        repo.loadStandings(competitionSlug: resolvedSlug, limit: 8),
        repo.loadFixturesByDate(
          dateFrom: today,
          dateTo: futureEnd,
          competitionSlug: resolvedSlug,
          limit: 10,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _competitions = competitions;
        _competition = results[0] as CompetitionCatalogItem?;
        _standings = results[1]! as List<LeagueStandingEntry>;
        _fixtures = results[2]! as List<FixtureSummary>;
        _isLoading = false;
        _error = _competition == null
            ? context.afriL10n.gameCompetitionNotFound
            : null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'LeagueHubScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = context.afriL10n.gameLeagueDataTemporarilyUnavailable;
      });
    }
  }

  String _kickoffLabel(BuildContext context, DateTime? value) {
    if (value == null) {
      return context.afriL10n.gameTbd;
    }
    final local = value.toLocal();
    final materialL10n = MaterialLocalizations.of(context);
    return '${materialL10n.formatShortDate(local)} • '
        '${materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final competition = _competition;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          competition?.shortName.toUpperCase() ??
              context.afriL10n.gameLeagueHubTitle,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: TypographyTokens.trackingNone,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.gameBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
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
                  title: context.afriL10n.gameLeagueUnavailable,
                  message: _error!,
                  actionLabel: context.afriL10n.gameRetry,
                  onAction: _load,
                ),
              ),
            )
          : AfriRefreshIndicator(
              onRefresh: () => _load(competition?.slug),
              color: ColorTokens.primaryContainer,
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
                          final selected = item.slug == competition?.slug;
                          return AfriPressFeedback(
                            onTap: () => _load(item.slug),
                            builder: (context, _) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpacingTokens.spacing3,
                                vertical: SpacingTokens.spacing2,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? ColorTokens.primaryContainer.withValues(
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
                                      ? ColorTokens.primaryContainer
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
                          competition?.name ?? context.afriL10n.gameCompetition,
                          style: TypographyTokens.headlineLarge().copyWith(
                            fontWeight: FontWeight.w700,
                            height: TypographyTokens.lineHeightCompact,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          context.afriL10n.gamePair(
                            competition?.region ?? context.afriL10n.gameRegion,
                            competition?.competitionKind ??
                                context.afriL10n.gameLeague,
                          ),
                          style: TypographyTokens.bodyMedium(),
                        ),
                        if (competition?.formatNotes != null) ...[
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            competition!.formatNotes!,
                            style: TypographyTokens.bodySmall(),
                          ),
                        ],
                        const SizedBox(height: SpacingTokens.spacing4),
                        Row(
                          children: [
                            Expanded(
                              child: _LeagueMetric(
                                label: context.afriL10n.gameTeams,
                                value: _standings.length.toString(),
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.spacing3),
                            Expanded(
                              child: _LeagueMetric(
                                label: context.afriL10n.gameFixtures,
                                value: _fixtures.length.toString(),
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.spacing3),
                            Expanded(
                              child: _LeagueMetric(
                                label: context.afriL10n.gameLeader,
                                value:
                                    _standings.firstOrNull?.teamShortName ??
                                    '--',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  _LeagueSectionCard(
                    title: context.afriL10n.gameTopTable,
                    actionLabel: context.afriL10n.gameFullStandings,
                    onAction: competition == null
                        ? null
                        : () => context.push(
                            '/fanzone/standings/${competition.slug}',
                          ),
                    child: Column(
                      children: _standings
                          .take(5)
                          .map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: SpacingTokens.spacing3,
                              ),
                              child: _LeagueStandingRow(
                                entry: entry,
                                onTap: () => context.push(
                                  '/fanzone/team/${entry.teamSlug}',
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  _LeagueSectionCard(
                    title: context.afriL10n.gameFixturesTitle,
                    child: Column(
                      children: _fixtures
                          .take(6)
                          .map((fixture) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: SpacingTokens.spacing3,
                              ),
                              child: AfriPressFeedback(
                                onTap: () => context.push(
                                  '/fanzone/match/${fixture.id}',
                                ),
                                builder: (context, _) => GlassCard(
                                  animate: false,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fixture.fixtureLabel,
                                              style:
                                                  TypographyTokens.titleSmall(),
                                            ),
                                            const SizedBox(
                                              height:
                                                  SpacingTokens.spacing1 / 2,
                                            ),
                                            Text(
                                              _kickoffLabel(
                                                context,
                                                fixture.kickoffAt,
                                              ),
                                              style:
                                                  TypographyTokens.bodySmall(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        fixture.isLive &&
                                                fixture.homeScore != null &&
                                                fixture.awayScore != null
                                            ? '${fixture.homeScore}-${fixture.awayScore}'
                                            : fixture.isFinished
                                            ? '${fixture.homeScore ?? 0}-${fixture.awayScore ?? 0}'
                                            : context.afriL10n.gameOpenUpper,
                                        style: TypographyTokens.titleMedium(
                                          fixture.isLive
                                              ? ColorTokens.success
                                              : ColorTokens.primaryContainer,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LeagueMetric extends StatelessWidget {
  const _LeagueMetric({required this.label, required this.value});

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
            label,
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            value,
            style: TypographyTokens.titleLarge().copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeagueSectionCard extends StatelessWidget {
  const _LeagueSectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: TypographyTokens.titleLarge()),
              ),
              if (actionLabel != null && onAction != null)
                AfriTextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          child,
        ],
      ),
    );
  }
}

class _LeagueStandingRow extends StatelessWidget {
  const _LeagueStandingRow({required this.entry, required this.onTap});

  final LeagueStandingEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      builder: (context, _) => GlassCard(
        animate: false,
        child: Row(
          children: [
            SizedBox(
              width: SpacingTokens.spacing7,
              child: Text(
                entry.position.toString(),
                style: TypographyTokens.titleMedium(
                  entry.position <= 3
                      ? ColorTokens.primaryContainer
                      : ColorTokens.onSurface,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.teamName, style: TypographyTokens.titleSmall()),
                  const SizedBox(height: SpacingTokens.spacing1 / 2),
                  Text(
                    context.afriL10n.gameLeagueStandingRecord(
                      entry.played,
                      entry.won,
                      entry.drawn,
                      entry.lost,
                    ),
                    style: TypographyTokens.bodySmall(),
                  ),
                ],
              ),
            ),
            Text(
              context.afriL10n.gamePointBalance(entry.points),
              style: TypographyTokens.titleMedium().copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
