import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';

class FixturesBrowserScreen extends ConsumerStatefulWidget {
  const FixturesBrowserScreen({
    super.key,
    this.statusFilter,
    this.title = 'FIXTURES',
    this.showBackButton = true,
  });

  final String? statusFilter;
  final String title;
  final bool showBackButton;

  @override
  ConsumerState<FixturesBrowserScreen> createState() =>
      _FixturesBrowserScreenState();
}

class _FixturesBrowserScreenState extends ConsumerState<FixturesBrowserScreen> {
  List<FixtureSummary> _fixtures = const <FixtureSummary>[];
  List<CompetitionCatalogItem> _competitions = const <CompetitionCatalogItem>[];
  Map<String, FixtureDateSummary> _dateSummary =
      const <String, FixtureDateSummary>{};
  PredictionDashboard? _dashboard;
  String? _selectedCompetition;
  bool _isLoading = true;
  String? _error;

  /// Currently selected date.
  late DateTime _selectedDate;

  /// Scroll controller for the calendar strip.
  final ScrollController _calendarController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadData();
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(predictionRepositoryProvider);

      // Load date summary for the calendar (±30 days)
      final now = DateTime.now();
      final summaryFrom = now.subtract(const Duration(days: 7));
      final summaryTo = now.add(const Duration(days: 60));

      final results = await Future.wait<Object?>([
        repo.loadFixturesByDate(
          dateFrom: _selectedDate,
          dateTo: _selectedDate,
          competitionSlug: _selectedCompetition,
          status: widget.statusFilter,
        ),
        repo.loadCompetitionCatalog(),
        repo.loadUserStats(),
        repo.loadFixtureDateSummary(
          dateFrom: summaryFrom,
          dateTo: summaryTo,
          competitionSlug: _selectedCompetition,
        ),
      ]);

      if (!mounted) return;

      final summaryList = results[3]! as List<FixtureDateSummary>;
      final summaryMap = <String, FixtureDateSummary>{};
      for (final s in summaryList) {
        final key = _dateKey(s.matchDate);
        summaryMap[key] = s;
      }

      setState(() {
        _fixtures = results[0]! as List<FixtureSummary>;
        _competitions = results[1]! as List<CompetitionCatalogItem>;
        _dashboard = results[2] as PredictionDashboard;
        _dateSummary = summaryMap;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load fixtures right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _onFilterChanged(String? slug) async {
    setState(() => _selectedCompetition = slug);
    await _loadData();
  }

  void _onDateSelected(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() => _selectedDate = date);
    _loadData();
  }

  /// Groups fixtures by competition for the selected day.
  Map<String, List<FixtureSummary>> _groupByCompetition() {
    final grouped = <String, List<FixtureSummary>>{};
    for (final fixture in _fixtures) {
      final key = fixture.competitionName;
      grouped.putIfAbsent(key, () => <FixtureSummary>[]).add(fixture);
    }
    return grouped;
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _selectedDateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final diff = sel.difference(today).inDays;

    const monthNames = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    final dateStr =
        '${dayNames[sel.weekday - 1]}, ${monthNames[sel.month - 1]} ${sel.day}';

    if (diff == 0) return 'TODAY  ·  $dateStr';
    if (diff == 1) return 'TOMORROW  ·  $dateStr';
    if (diff == -1) return 'YESTERDAY  ·  $dateStr';
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Title bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing4,
                  SpacingTokens.spacing4,
                  SpacingTokens.spacing6,
                  0,
                ),
                child: Row(
                  children: [
                    if (widget.showBackButton)
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(AfriIcons.back),
                      ),
                    if (!widget.showBackButton)
                      const SizedBox(width: SpacingTokens.spacing4),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TypographyTokens.monolithFont(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: ColorTokens.onSurface,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push('/fanzone/my'),
                      icon: Icon(
                        Icons.receipt_long_rounded,
                        color: ColorTokens.onSurfaceVariant,
                      ),
                      tooltip: 'My Predictions',
                    ),
                  ],
                ),
              ),
              // ── Dashboard overview ──
              if (_dashboard != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing6,
                    0,
                  ),
                  child: _PredictionOverviewRow(dashboard: _dashboard!),
                ),
              // ── Calendar date strip ──
              Padding(
                padding: const EdgeInsets.only(top: SpacingTokens.spacing4),
                child: _CalendarStrip(
                  selectedDate: _selectedDate,
                  dateSummary: _dateSummary,
                  onDateSelected: _onDateSelected,
                  controller: _calendarController,
                ),
              ),

              // ── Selected date label ──
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
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: ColorTokens.clubAccent,
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Expanded(
                      child: Text(
                        _selectedDateLabel(),
                        style: TypographyTokens.monolithFont(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ColorTokens.onSurface,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    // Fixture count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ColorTokens.clubAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_fixtures.length} ${_fixtures.length == 1 ? 'match' : 'matches'}',
                        style: TypographyTokens.editorialFont(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ColorTokens.clubAccent,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Competition filter rail ──
              if (_competitions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: SpacingTokens.spacing4),
                  child: SizedBox(
                    height: 36,
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
                          return _FilterChip(
                            label: 'ALL',
                            isSelected: _selectedCompetition == null,
                            onTap: () => _onFilterChanged(null),
                          );
                        }
                        final competition = _competitions[index - 1];
                        return _FilterChip(
                          label: competition.shortName.toUpperCase(),
                          isSelected:
                              _selectedCompetition == competition.slug,
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
            title: 'Fixtures unavailable',
            message: _error!,
            actionLabel: 'Retry',
            onAction: _loadData,
          ),
        ),
      );
    }

    final grouped = _groupByCompetition();

    if (grouped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriEmptyView(
            title: 'No fixtures on this date',
            message:
                'Try selecting another day on the calendar or change the league filter.',
          ),
        ),
      );
    }

    final competitionKeys = grouped.keys.toList(growable: false);

    return RefreshIndicator(
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
              Padding(
                padding: const EdgeInsets.only(
                  bottom: SpacingTokens.spacing3,
                  left: SpacingTokens.spacing1,
                ),
                child: Text(
                  compName.toUpperCase(),
                  style: TypographyTokens.editorialFont(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
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
                  child: _FixtureCard(
                        fixture: fixture,
                        onOpen: () {
                          HapticFeedback.lightImpact();
                          context.push('/fanzone/match/${fixture.id}');
                        },
                      )
                      .animate(delay: (index * 50).ms)
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

// ══════════════════════════════════════════════════════════════════════════════
// Calendar Date Strip – scrollable horizontal date selector with dots
// ══════════════════════════════════════════════════════════════════════════════

class _CalendarStrip extends StatefulWidget {
  const _CalendarStrip({
    required this.selectedDate,
    required this.dateSummary,
    required this.onDateSelected,
    required this.controller,
  });

  final DateTime selectedDate;
  final Map<String, FixtureDateSummary> dateSummary;
  final ValueChanged<DateTime> onDateSelected;
  final ScrollController controller;

  @override
  State<_CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<_CalendarStrip> {
  static const int _pastDays = 7;
  static const int _futureDays = 60;
  static const int _totalDays = _pastDays + 1 + _futureDays; // 68 days
  static const double _cellWidth = 52;

  late final DateTime _baseDate; // 7 days ago

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _baseDate = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: _pastDays));

    // Scroll to today after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(_pastDays);
    });
  }

  void _scrollToIndex(int index) {
    if (!widget.controller.hasClients) return;
    final target = index * _cellWidth;
    final maxScroll = widget.controller.position.maxScrollExtent;
    widget.controller.animateTo(
      target.clamp(0, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  DateTime _dateForIndex(int index) =>
      _baseDate.add(Duration(days: index));

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        controller: widget.controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing6,
        ),
        itemCount: _totalDays,
        itemExtent: _cellWidth,
        itemBuilder: (context, index) {
          final date = _dateForIndex(index);
          final sel = DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
          );
          final cellDate = DateTime(date.year, date.month, date.day);
          final isSelected = cellDate == sel;
          final now = DateTime.now();
          final isToday =
              cellDate == DateTime(now.year, now.month, now.day);
          final key = _dateKey(date);
          final summary = widget.dateSummary[key];
          final hasFixtures = summary != null && summary.fixtureCount > 0;
          final hasLive = summary?.hasLive ?? false;

          return GestureDetector(
            onTap: () => widget.onDateSelected(date),
            child: _CalendarCell(
              date: date,
              isSelected: isSelected,
              isToday: isToday,
              hasFixtures: hasFixtures,
              hasLive: hasLive,
              fixtureCount: summary?.fixtureCount ?? 0,
            ),
          );
        },
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.hasFixtures,
    required this.hasLive,
    required this.fixtureCount,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool hasFixtures;
  final bool hasLive;
  final int fixtureCount;

  static const _dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? ColorTokens.clubAccent.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: isSelected
            ? BorderTokens.all(color: ColorTokens.clubAccent, width: 1.5)
            : isToday
                ? BorderTokens.all(
                    color: ColorTokens.clubAccent.withValues(alpha: 0.4),
                    width: 1,
                  )
                : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _dayNames[date.weekday - 1],
            style: TypographyTokens.editorialFont(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? ColorTokens.clubAccent
                  : ColorTokens.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${date.day}',
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? ColorTokens.clubAccent
                  : isToday
                      ? ColorTokens.onSurface
                      : hasFixtures
                          ? ColorTokens.onSurface
                          : ColorTokens.onSurfaceVariant
                              .withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          // Dot indicators
          if (hasFixtures)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasLive
                        ? ColorTokens.success
                        : isSelected
                            ? ColorTokens.clubAccent
                            : ColorTokens.onSurfaceVariant,
                  ),
                ),
                if (fixtureCount > 3) ...[
                  const SizedBox(width: 2),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isSelected
                              ? ColorTokens.clubAccent
                              : ColorTokens.onSurfaceVariant)
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            )
          else
            const SizedBox(height: 5),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Supporting widgets
// ══════════════════════════════════════════════════════════════════════════════

class _PredictionOverviewRow extends StatelessWidget {
  const _PredictionOverviewRow({required this.dashboard});

  final PredictionDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OverviewMetric(
          label: 'ACTIVE',
          value: '${dashboard.activeCount}',
          accent: dashboard.activeCount > 0,
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        _OverviewMetric(
          label: 'WIN RATE',
          value: '${dashboard.winRate.toStringAsFixed(0)}%',
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        _OverviewMetric(
          label: 'FET',
          value: '+${dashboard.totalFetEarned}',
          accent: dashboard.totalFetEarned > 0,
        ),
      ],
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TypographyTokens.editorialFont(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: ColorTokens.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypographyTokens.monolithFont(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: accent ? ColorTokens.clubAccent : ColorTokens.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorTokens.clubAccent.withValues(alpha: 0.18)
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? BorderTokens.all(color: ColorTokens.clubAccent, width: 1.5)
              : BorderTokens.ghost(),
        ),
        child: Text(
          label,
          style: TypographyTokens.editorialFont(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? ColorTokens.clubAccent
                : ColorTokens.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _FixtureCard extends StatelessWidget {
  const _FixtureCard({required this.fixture, required this.onOpen});

  final FixtureSummary fixture;
  final VoidCallback onOpen;

  String _formatKickoff() {
    final kickoff = fixture.kickoffAt;
    if (kickoff == null) return 'TBD';
    final local = kickoff.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _statusLabel() {
    return switch (fixture.status) {
      'live' => 'LIVE',
      'finished' => 'FT',
      'postponed' => 'PPD',
      'cancelled' => 'OFF',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isLive = fixture.isLive;
    final isFinished = fixture.isFinished;
    final hasScore = fixture.homeScore != null && fixture.awayScore != null;

    return AfriPressFeedback(
      onTap: onOpen,
      semanticsLabel: '${fixture.homeTeamName} vs ${fixture.awayTeamName}',
      semanticsHint: fixture.isPredictable
          ? 'Tap to make a prediction'
          : 'View match details',
      builder: (context, state) => GlassCard(
        animate: false,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fixture.matchday != null
                        ? 'MD ${fixture.matchday}'
                        : _formatKickoff(),
                    style: TypographyTokens.editorialFont(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ColorTokens.onSurfaceVariant,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                if (isLive || isFinished)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (isLive
                              ? ColorTokens.success
                              : ColorTokens.onSurfaceVariant)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(),
                      style: TypographyTokens.editorialFont(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isLive
                            ? ColorTokens.success
                            : ColorTokens.onSurfaceVariant,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fixture.homeTeamName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypographyTokens.monolithFont(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ColorTokens.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fixture.awayTeamName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypographyTokens.monolithFont(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ColorTokens.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasScore)
                  Column(
                    children: [
                      Text(
                        fixture.homeScore.toString(),
                        style: TypographyTokens.monolithFont(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: ColorTokens.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fixture.awayScore.toString(),
                        style: TypographyTokens.monolithFont(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: ColorTokens.onSurface,
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: fixture.isPredictable
                          ? ColorTokens.clubAccent.withValues(alpha: 0.14)
                          : ColorTokens.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      fixture.isPredictable ? 'PREDICT' : _formatKickoff(),
                      style: TypographyTokens.editorialFont(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: fixture.isPredictable
                            ? ColorTokens.clubAccent
                            : ColorTokens.onSurfaceVariant,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Row(
              children: [
                if (isLive)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColorTokens.success,
                    ),
                  ),
                Text(
                  fixture.matchday != null
                      ? '${_formatKickoff()}  ·  ${fixture.venueName ?? ''}'
                      : fixture.venueName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypographyTokens.editorialFont(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ColorTokens.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
