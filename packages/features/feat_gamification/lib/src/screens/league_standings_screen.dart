import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fanzone_models.dart';
import '../prediction_providers.dart';

class LeagueStandingsScreen extends ConsumerStatefulWidget {
  const LeagueStandingsScreen({super.key, required this.competitionSlug});

  final String competitionSlug;

  @override
  ConsumerState<LeagueStandingsScreen> createState() =>
      _LeagueStandingsScreenState();
}

class _LeagueStandingsScreenState extends ConsumerState<LeagueStandingsScreen> {
  CompetitionCatalogItem? _competition;
  List<LeagueStandingEntry> _standings = const <LeagueStandingEntry>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(predictionRepositoryProvider);
      final results = await Future.wait<Object?>([
        repo.loadCompetition(widget.competitionSlug),
        repo.loadStandings(competitionSlug: widget.competitionSlug, limit: 32),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _competition = results[0] as CompetitionCatalogItem?;
        _standings = results[1]! as List<LeagueStandingEntry>;
        _isLoading = false;
        _error = _competition == null ? 'Competition not found.' : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Standings are temporarily unavailable.';
      });
    }
  }

  Color _formColor(String token) {
    return switch (token.toUpperCase()) {
      'W' => ColorTokens.success,
      'D' => ColorTokens.warning,
      'L' => ColorTokens.error,
      _ => ColorTokens.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          _competition?.shortName.toUpperCase() ?? 'STANDINGS',
          style: TypographyTokens.monolithFont(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
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
                  title: 'Standings unavailable',
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
                    child: Row(
                      children: [
                        const SizedBox(width: 32, child: Text('POS')),
                        Expanded(
                          child: Text(
                            'TEAM',
                            style: TypographyTokens.labelMedium(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 42,
                          child: Text('PTS', textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ..._standings.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: SpacingTokens.spacing3,
                      ),
                      child: AfriPressFeedback(
                        onTap: () =>
                            context.push('/fanzone/team/${entry.teamSlug}'),
                        builder: (context, _) => GlassCard(
                          animate: false,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '${entry.position}',
                                      style: TypographyTokens.monolithFont(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: entry.position <= 3
                                            ? ColorTokens.clubAccent
                                            : ColorTokens.onSurface,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.teamName,
                                          style: TypographyTokens.titleSmall(),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${entry.played}P · ${entry.goalsFor}:${entry.goalsAgainst} · GD ${entry.goalDifference}',
                                          style: TypographyTokens.bodySmall(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: SpacingTokens.spacing3),
                                  Text(
                                    '${entry.points}',
                                    style: TypographyTokens.monolithFont(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              if (entry.formTokens.isNotEmpty) ...[
                                const SizedBox(height: SpacingTokens.spacing3),
                                Row(
                                  children: entry.formTokens
                                      .take(5)
                                      .map((token) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: SpacingTokens.spacing1,
                                          ),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: _formColor(
                                                token,
                                              ).withValues(alpha: 0.18),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              token,
                                              style:
                                                  TypographyTokens.labelSmall(
                                                    _formColor(token),
                                                  ),
                                            ),
                                          ),
                                        );
                                      })
                                      .toList(growable: false),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
