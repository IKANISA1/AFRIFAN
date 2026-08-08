import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../widgets/fixtures_browser_widgets.dart';

class FixturesBrowserScreen extends ConsumerStatefulWidget {
  const FixturesBrowserScreen({
    super.key,
    this.title,
    this.showBackButton = false,
    this.statusFilter,
  });

  final String? title;
  final bool showBackButton;
  final String? statusFilter;

  @override
  ConsumerState<FixturesBrowserScreen> createState() =>
      _FixturesBrowserScreenState();
}

class _FixturesBrowserScreenState extends ConsumerState<FixturesBrowserScreen> {
  final ScrollController _calendarController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCompetition;

  List<FixtureSummary> _fixtures = [];
  List<CompetitionCatalogItem> _competitions = [];
  PredictionDashboard? _dashboard;
  Map<String, int> _dateSummary = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(predictionRepositoryProvider);
      final results = await Future.wait([
        repo.loadFixturesByDate(
          dateFrom: _selectedDate,
          dateTo: _selectedDate,
          competitionSlug: _selectedCompetition,
          status: widget.statusFilter,
        ),
        repo.loadCompetitionCatalog(),
        repo.loadUserStats(),
        repo.loadFixtureDateSummary(
          dateFrom: _selectedDate.subtract(const Duration(days: 7)),
          dateTo: _selectedDate.add(const Duration(days: 7)),
          competitionSlug: _selectedCompetition,
        ),
      ]);

      final summaryList = results[3] as List<FixtureDateSummary>;
      final summaryMap = <String, int>{};
      for (final item in summaryList) {
        final d =
            '${item.matchDate.year}-${item.matchDate.month.toString().padLeft(2, '0')}-${item.matchDate.day.toString().padLeft(2, '0')}';
        summaryMap[d] = item.fixtureCount;
      }

      if (!mounted) return;
      setState(() {
        _fixtures = results[0] as List<FixtureSummary>;
        _competitions = results[1] as List<CompetitionCatalogItem>;
        _dashboard = results[2] as PredictionDashboard;
        _dateSummary = summaryMap;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'FixturesBrowserScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _error = context.afriL10n.gameFixturesCouldNotLoad;
        _isLoading = false;
      });
    }
  }

  Future<void> _onFilterChanged(String? slug) async {
    setState(() => _selectedCompetition = slug);
    await _loadData();
  }

  void _onDateSelected(DateTime date) {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _selectedDate = date);
    unawaited(_loadData());
  }

  Map<String, List<FixtureSummary>> _groupByCompetition() {
    final grouped = <String, List<FixtureSummary>>{};
    for (final fixture in _fixtures) {
      final key = fixture.competitionName;
      grouped.putIfAbsent(key, () => <FixtureSummary>[]).add(fixture);
    }
    return grouped;
  }

  String _selectedDateLabel(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final diff = sel.difference(today).inDays;

    final dateStr = MaterialLocalizations.of(context).formatMediumDate(sel);

    if (diff == 0) {
      return context.afriL10n.gameRelativeDate(
        context.afriL10n.gameToday,
        dateStr,
      );
    }
    if (diff == 1) {
      return context.afriL10n.gameRelativeDate(
        context.afriL10n.gameTomorrow,
        dateStr,
      );
    }
    if (diff == -1) {
      return context.afriL10n.gameRelativeDate(
        context.afriL10n.gameYesterday,
        dateStr,
      );
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          widget.title ?? context.afriL10n.gameFixturesTitle,
          style: TypographyTokens.headlineSmall(),
        ),
        leading: widget.showBackButton
            ? AfriIconButton(
                icon: AfriIcons.back,
                onTap: () => context.pop(),
                tooltip: context.afriL10n.gameBack,
              )
            : null,
        actions: [
          AfriIconButton(
            icon: AfriIcons.myPicks,
            onTap: () => unawaited(context.push('/fanzone/my')),
            tooltip: context.afriL10n.gamePredictions,
          ),
        ],
      ),
      scrollable: false,
      constrainContent: false,
      child: SafeArea(
        child: Column(
          children: [
            if (_dashboard != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing2,
                  SpacingTokens.spacing6,
                  0,
                ),
                child: PredictionOverviewRow(dashboard: _dashboard!),
              ),
            Padding(
              padding: const EdgeInsets.only(top: SpacingTokens.spacing4),
              child: FixturesCalendarStrip(
                selectedDate: _selectedDate,
                dateSummary: _dateSummary,
                onDateSelected: _onDateSelected,
                controller: _calendarController,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing6,
                SpacingTokens.spacing3,
                SpacingTokens.spacing6,
                0,
              ),
              child: Row(
                children: [
                  Icon(
                    AfriIcons.calendar,
                    size: SpacingTokens.spacing4,
                    color: ColorTokens.clubAccent,
                  ),
                  const SizedBox(width: SpacingTokens.spacing2),
                  Expanded(
                    child: Text(
                      _selectedDateLabel(context),
                      style: TypographyTokens.titleSmall(),
                    ),
                  ),
                  AfriStatusChip(
                    label: context.afriL10n.gameMatchCount(_fixtures.length),
                    tone: AfriStatusTone.live,
                  ),
                ],
              ),
            ),
            if (_competitions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: SpacingTokens.spacing4),
                child: SizedBox(
                  height: SpacingTokens.spacing10 - SpacingTokens.spacing1 / 2,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing6,
                    ),
                    itemCount: _competitions.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: SpacingTokens.spacing2),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return CompetitionFilterChip(
                          label: context.afriL10n.gameAll,
                          isSelected: _selectedCompetition == null,
                          onTap: () => _onFilterChanged(null),
                        );
                      }
                      final competition = _competitions[index - 1];
                      return CompetitionFilterChip(
                        label: competition.shortName,
                        isSelected: _selectedCompetition == competition.slug,
                        onTap: () => _onFilterChanged(competition.slug),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: SpacingTokens.spacing4),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(SpacingTokens.spacing6),
        child: AfriSkeletonList(),
      );
    }

    if (_error != null && _fixtures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriStateView.offline(
            title: context.afriL10n.gameFixturesUnavailable,
            message: _error!,
            actionLabel: context.afriL10n.gameRetry,
            onAction: _loadData,
          ),
        ),
      );
    }

    final grouped = _groupByCompetition();

    if (grouped.isEmpty) {
      return const SizedBox.shrink();
    }

    final competitionKeys = grouped.keys.toList(growable: false);

    return AfriRefreshIndicator(
      onRefresh: _loadData,
      color: ColorTokens.clubAccent,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.spacing6,
          0,
          SpacingTokens.spacing6,
          SpacingTokens.spacing20,
        ),
        itemCount: competitionKeys.length,
        itemBuilder: (context, sectionIndex) {
          final compName = competitionKeys[sectionIndex];
          final fixtures = grouped[compName]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sectionIndex > 0)
                const SizedBox(height: SpacingTokens.spacing5),
              AfriSectionHeader(
                title: compName,
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              ),
              ...fixtures.asMap().entries.map((entry) {
                final index = entry.key;
                final fixture = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < fixtures.length - 1
                        ? SpacingTokens.spacing3
                        : 0,
                  ),
                  child:
                      FixtureBrowserCard(
                            fixture: fixture,
                            onOpen: () {
                              unawaited(HapticFeedback.lightImpact());
                              unawaited(
                                context.push('/fanzone/match/${fixture.id}'),
                              );
                            },
                          )
                          .afriAnimate(context, delay: (index * 50).ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.04, end: 0, duration: 300.ms),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
