import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Calendar Date Strip – scrollable horizontal date selector with dots
// ══════════════════════════════════════════════════════════════════════════════

/// Horizontal scrollable date selector bar for the fixtures browser.
class FixturesCalendarStrip extends StatefulWidget {
  const FixturesCalendarStrip({
    super.key,
    required this.selectedDate,
    required this.dateSummary,
    required this.onDateSelected,
    required this.controller,
  });

  final DateTime selectedDate;
  final Map<String, int> dateSummary;
  final ValueChanged<DateTime> onDateSelected;
  final ScrollController controller;

  @override
  State<FixturesCalendarStrip> createState() => _FixturesCalendarStripState();
}

class _FixturesCalendarStripState extends State<FixturesCalendarStrip> {
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
          final count = widget.dateSummary[key] ?? 0;
          final hasFixtures = count > 0;
          final hasLive = false;

          return GestureDetector(
            onTap: () => widget.onDateSelected(date),
            child: FixturesCalendarCell(
              date: date,
              isSelected: isSelected,
              isToday: isToday,
              hasFixtures: hasFixtures,
              hasLive: hasLive,
              fixtureCount: count,
            ),
          );
        },
      ),
    );
  }
}

/// Single day cell inside the calendar strip.
class FixturesCalendarCell extends StatelessWidget {
  const FixturesCalendarCell({
    super.key,
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

/// Dashboard stats row (Active / Win Rate / FET).
class PredictionOverviewRow extends StatelessWidget {
  const PredictionOverviewRow({super.key, required this.dashboard});

  final PredictionDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PredictionOverviewMetric(
          label: 'ACTIVE',
          value: '${dashboard.activeCount}',
          accent: dashboard.activeCount > 0,
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        PredictionOverviewMetric(
          label: 'WIN RATE',
          value: '${dashboard.winRate.toStringAsFixed(0)}%',
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        PredictionOverviewMetric(
          label: 'FET',
          value: '+${dashboard.totalFetEarned}',
          accent: dashboard.totalFetEarned > 0,
        ),
      ],
    );
  }
}

/// Single metric card in the prediction overview row.
class PredictionOverviewMetric extends StatelessWidget {
  const PredictionOverviewMetric({
    super.key,
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

/// Competition filter chip (ALL, UCL, EPL, etc.).
class CompetitionFilterChip extends StatelessWidget {
  const CompetitionFilterChip({
    super.key,
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

/// Fixture card displaying match info (teams, score, kickoff, venue).
class FixtureBrowserCard extends StatelessWidget {
  const FixtureBrowserCard({
    super.key,
    required this.fixture,
    required this.onOpen,
  });

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
