import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/prediction_models.dart';
import '../prediction_providers.dart';

class FixturesBrowserScreen extends ConsumerStatefulWidget {
  const FixturesBrowserScreen({
    super.key,
    this.statusFilter = 'scheduled',
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
  List<Map<String, dynamic>> _competitions = const <Map<String, dynamic>>[];
  PredictionDashboard? _dashboard;
  String? _selectedCompetition;
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
        repo.loadFixtures(
          competitionSlug: _selectedCompetition,
          status: widget.statusFilter,
        ),
        repo.loadCompetitions(),
        repo.loadUserStats(),
      ]);

      if (!mounted) return;
      setState(() {
        _fixtures = results[0]! as List<FixtureSummary>;
        _competitions = results[1]! as List<Map<String, dynamic>>;
        _dashboard = results[2] as PredictionDashboard;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
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
                        icon: const Icon(Icons.arrow_back_rounded),
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
              if (_competitions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: SpacingTokens.spacing4),
                  child: SizedBox(
                    height: 40,
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
                        final slug = competition['slug']?.toString() ?? '';
                        final shortName =
                            competition['short_name']?.toString() ?? '';
                        return _FilterChip(
                          label: shortName.toUpperCase(),
                          isSelected: _selectedCompetition == slug,
                          onTap: () => _onFilterChanged(slug),
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

    if (_fixtures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriEmptyView(
            title: widget.statusFilter == 'live'
                ? 'No live fixtures right now'
                : 'No fixtures available',
            message: widget.statusFilter == 'live'
                ? 'When matches go live, they will appear here instantly.'
                : 'Try another league or pull to refresh.',
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: ColorTokens.clubAccent,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.spacing6,
          0,
          SpacingTokens.spacing6,
          SpacingTokens.spacing20,
        ),
        itemCount: _fixtures.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: SpacingTokens.spacing3),
        itemBuilder: (context, index) {
          final fixture = _fixtures[index];
          return _FixtureCard(
                fixture: fixture,
                onOpen: () {
                  HapticFeedback.lightImpact();
                  context.push('/fanzone/match/${fixture.id}');
                },
              )
              .animate(delay: (index * 50).ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, end: 0, duration: 300.ms);
        },
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorTokens.clubAccent.withValues(alpha: 0.18)
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? Border.all(color: ColorTokens.clubAccent, width: 1.5)
              : BorderTokens.ghost(),
        ),
        child: Text(
          label,
          style: TypographyTokens.editorialFont(
            fontSize: 13,
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
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final isTomorrow =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day + 1;

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    if (isToday) return 'TODAY  •  $time';
    if (isTomorrow) return 'TOMORROW  •  $time';

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
    return '${dayNames[local.weekday - 1]} ${local.day} ${monthNames[local.month - 1]}  •  $time';
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
                Text(
                  fixture.competitionName.toUpperCase(),
                  style: TypographyTokens.editorialFont(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                if (fixture.matchday != null) ...[
                  Text(
                    '  •  MD ${fixture.matchday}',
                    style: TypographyTokens.editorialFont(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: ColorTokens.onSurfaceVariant,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
                const Spacer(),
                if (isLive || isFinished)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isLive
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
                      fixture.isPredictable ? 'PREDICT' : 'DETAILS',
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
                  _formatKickoff(),
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
