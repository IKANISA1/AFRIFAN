import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    _baseDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: _pastDays));

    // Scroll to today after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(_pastDays);
    });
  }

  void _scrollToIndex(int index) {
    if (!widget.controller.hasClients) return;
    final target = index * _cellWidth;
    final maxScroll = widget.controller.position.maxScrollExtent;
    unawaited(
      widget.controller.animateTo(
        target.clamp(0, maxScroll),
        duration: AfriMotion.emphasized,
        curve: Curves.easeOut,
      ),
    );
  }

  DateTime _dateForIndex(int index) => _baseDate.add(Duration(days: index));

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SpacingTokens.spacing16 + SpacingTokens.spacing2,
      child: ListView.builder(
        controller: widget.controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6),
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
          final isToday = cellDate == DateTime(now.year, now.month, now.day);
          final key = _dateKey(date);
          final count = widget.dateSummary[key] ?? 0;
          final hasFixtures = count > 0;
          final fixtureSummary = '$count fixtures';

          return AfriPressFeedback(
            onTap: () => widget.onDateSelected(date),
            selected: isSelected,
            tooltip: isToday
                ? 'Today, $fixtureSummary'
                : '${date.day}, $fixtureSummary',
            semanticsLabel: isToday
                ? 'Today, $fixtureSummary'
                : 'Date ${date.day}, $fixtureSummary',
            semanticsHint: isSelected ? 'Selected date' : 'Select date',
            excludeChildSemantics: true,
            child: FixturesCalendarCell(
              date: date,
              isSelected: isSelected,
              isToday: isToday,
              hasFixtures: hasFixtures,
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
    required this.fixtureCount,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool hasFixtures;
  final int fixtureCount;

  static const _dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AfriMotion.standard,
      margin: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing1 / 2,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? ColorTokens.primaryContainer.withValues(alpha: 0.18)
            : ColorTokens.transparent,
        borderRadius: ShapeTokens.aliasPillRadius,
        border: isSelected
            ? BorderTokens.all(
                color: ColorTokens.primaryContainer,
                width: BorderTokens.strong,
              )
            : isToday
            ? BorderTokens.all(
                color: ColorTokens.primaryContainer.withValues(alpha: 0.4),
                width: BorderTokens.standard,
              )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _dayNames[date.weekday - 1],
            style:
                TypographyTokens.labelSmall(
                  isSelected
                      ? ColorTokens.primaryContainer
                      : ColorTokens.onSurfaceVariant,
                ).copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: TypographyTokens.trackingNone,
                ),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            date.day.toString(),
            style:
                TypographyTokens.titleLarge(
                  isSelected
                      ? ColorTokens.primaryContainer
                      : isToday
                      ? ColorTokens.onSurface
                      : hasFixtures
                      ? ColorTokens.onSurface
                      : ColorTokens.onSurfaceVariant.withValues(alpha: 0.4),
                ).copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w600,
                  letterSpacing: TypographyTokens.trackingNone,
                ),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          // Dot indicators
          if (hasFixtures)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FixtureDot(
                  color: isSelected
                      ? ColorTokens.primaryContainer
                      : ColorTokens.onSurfaceVariant,
                ),
                if (fixtureCount > 3) ...[
                  const SizedBox(width: SpacingTokens.spacing1 / 2),
                  _FixtureDot(
                    color:
                        (isSelected
                                ? ColorTokens.primaryContainer
                                : ColorTokens.onSurfaceVariant)
                            .withValues(alpha: 0.5),
                  ),
                ],
              ],
            )
          else
            const SizedBox(
              height: SpacingTokens.spacing1 + SpacingTokens.spacing1 / 4,
            ),
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
          label: context.afriL10n.gameActiveUpper,
          value: dashboard.activeCount.toString(),
          accent: dashboard.activeCount > 0,
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        PredictionOverviewMetric(
          label: context.afriL10n.gameWinRate,
          value: '${dashboard.winRate.toStringAsFixed(0)}%',
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        PredictionOverviewMetric(
          label: context.afriL10n.gameFet,
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
      child: AfriMetricTile(
        label: label,
        value: value,
        accentColor: accent ? ColorTokens.primaryContainer : null,
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
    return AfriChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        unawaited(HapticFeedback.selectionClick());
        onTap();
      },
      labelStyle:
          TypographyTokens.labelSmall(
            isSelected
                ? ColorTokens.primaryContainer
                : ColorTokens.onSurfaceVariant,
          ).copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: TypographyTokens.trackingNone,
          ),
      backgroundColor: ColorTokens.surfaceContainerLow,
      selectedColor: ColorTokens.primaryContainer.withValues(alpha: 0.18),
      side: BorderTokens.side(
        color: isSelected
            ? ColorTokens.primaryContainer
            : ColorTokens.ghostBorder,
        width: isSelected ? BorderTokens.strong : BorderTokens.hairline,
      ),
      shape: RoundedRectangleBorder(borderRadius: ShapeTokens.buttonRadius),
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing1,
        vertical: SpacingTokens.spacing1,
      ),
      labelPadding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
      ),
    );
  }
}

class _FixtureActionPill extends StatelessWidget {
  const _FixtureActionPill({
    required this.label,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return AfriChip(
      label: Text(label),
      backgroundColor: emphasized
          ? color.withValues(alpha: 0.14)
          : ColorTokens.surfaceContainerHigh,
      side: BorderTokens.side(
        color: emphasized ? color : ColorTokens.ghostBorder,
        opacity: emphasized ? 0.42 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: ShapeTokens.aliasPillRadius),
      labelStyle: TypographyTokens.labelSmall(color).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: TypographyTokens.trackingNone,
        height: TypographyTokens.lineHeightSolid,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing1,
        vertical: SpacingTokens.spacing1,
      ),
      labelPadding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing2,
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SpacingTokens.spacing2 - SpacingTokens.spacing1 / 2,
      height: SpacingTokens.spacing2 - SpacingTokens.spacing1 / 2,
      margin: margin,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ColorTokens.success,
      ),
    );
  }
}

class _FixtureDot extends StatelessWidget {
  const _FixtureDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SpacingTokens.spacing1 + SpacingTokens.spacing1 / 4,
      height: SpacingTokens.spacing1 + SpacingTokens.spacing1 / 4,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({required this.homeScore, required this.awayScore});

  final int homeScore;
  final int awayScore;

  @override
  Widget build(BuildContext context) {
    final scoreStyle = TypographyTokens.headlineMedium().copyWith(
      fontWeight: FontWeight.w700,
      height: TypographyTokens.lineHeightSolid,
    );

    return Column(
      children: [
        Text(homeScore.toString(), style: scoreStyle),
        const SizedBox(height: SpacingTokens.spacing1),
        Text(awayScore.toString(), style: scoreStyle),
      ],
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

  String _semanticStatusLabel() {
    return switch (fixture.status) {
      'live' => 'Live match',
      'finished' => 'Finished match',
      'postponed' => 'Postponed match',
      'cancelled' => 'Cancelled match',
      _ => 'Scheduled match',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isLive = fixture.isLive;
    final isFinished = fixture.isFinished;
    final hasScore = fixture.homeScore != null && fixture.awayScore != null;

    return AfriPressFeedback(
      onTap: onOpen,
      semanticsLabel:
          '${fixture.homeTeamName} vs ${fixture.awayTeamName}. '
          '${_semanticStatusLabel()}',
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
                    style:
                        TypographyTokens.labelSmall(
                          ColorTokens.onSurfaceVariant,
                        ).copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: TypographyTokens.trackingNone,
                        ),
                  ),
                ),
                if (isLive || isFinished)
                  AfriInfoChip(
                    label: _statusLabel(),
                    color: isLive
                        ? ColorTokens.success
                        : ColorTokens.onSurfaceVariant,
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
                        fixture.homeTeamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypographyTokens.titleMedium().copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing1),
                      Text(
                        fixture.awayTeamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypographyTokens.titleMedium().copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasScore)
                  _ScoreColumn(
                    homeScore: fixture.homeScore!,
                    awayScore: fixture.awayScore!,
                  )
                else
                  _FixtureActionPill(
                    label: fixture.isPredictable ? 'PREDICT' : _formatKickoff(),
                    color: fixture.isPredictable
                        ? ColorTokens.primaryContainer
                        : ColorTokens.onSurfaceVariant,
                    emphasized: fixture.isPredictable,
                  ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Row(
              children: [
                if (isLive) const _LiveDot(margin: EdgeInsets.only(right: 6)),
                Text(
                  fixture.matchday != null
                      ? '${_formatKickoff()}  ·  ${fixture.venueName ?? ''}'
                      : fixture.venueName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TypographyTokens.labelSmall(
                        ColorTokens.onSurfaceVariant,
                      ).copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: TypographyTokens.trackingNone,
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
