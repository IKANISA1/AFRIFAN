import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';

class TeamProfileScreen extends ConsumerStatefulWidget {
  const TeamProfileScreen({super.key, required this.teamSlug});

  final String teamSlug;

  @override
  ConsumerState<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends ConsumerState<TeamProfileScreen> {
  TeamCatalogEntry? _team;
  LeagueStandingEntry? _tableRow;
  List<TeamRosterPlayer> _roster = const <TeamRosterPlayer>[];
  List<FixtureSummary> _fixtures = const <FixtureSummary>[];
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
        repo.loadTeam(widget.teamSlug),
        repo.loadTeamRoster(widget.teamSlug),
        repo.loadTeamFixtures(widget.teamSlug, limit: 8),
      ]);

      final team = results[0] as TeamCatalogEntry?;
      final roster = results[1]! as List<TeamRosterPlayer>;
      final fixtures = results[2]! as List<FixtureSummary>;
      LeagueStandingEntry? tableRow;

      final competitionSlug = fixtures.firstOrNull?.competitionSlug;
      if (competitionSlug != null && competitionSlug.isNotEmpty) {
        final standings = await repo.loadStandings(
          competitionSlug: competitionSlug,
          limit: 32,
        );
        tableRow = standings.cast<LeagueStandingEntry?>().firstWhere(
          (entry) => entry?.teamSlug == widget.teamSlug,
          orElse: () => null,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _team = team;
        _tableRow = tableRow;
        _roster = roster;
        _fixtures = fixtures;
        _isLoading = false;
        _error = team == null ? 'Team not found.' : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Team profile is temporarily unavailable.';
      });
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
    final team = _team;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          team?.shortName.toUpperCase() ?? 'TEAM PROFILE',
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
                  title: 'Team unavailable',
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
                        Text(
                          team?.name.toUpperCase() ?? 'TEAM',
                          style: TypographyTokens.monolithFont(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          [
                                team?.city,
                                team?.countryName,
                                if (team?.foundedYear != null)
                                  'Founded ${team!.foundedYear}',
                              ]
                              .whereType<String>()
                              .where((value) => value.isNotEmpty)
                              .join(' · '),
                          style: TypographyTokens.bodyMedium(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Row(
                          children: [
                            Expanded(
                              child: _TeamMetric(
                                label: 'Table',
                                value: _tableRow == null
                                    ? '--'
                                    : '#${_tableRow!.position}',
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.spacing3),
                            Expanded(
                              child: _TeamMetric(
                                label: 'Points',
                                value: _tableRow == null
                                    ? '--'
                                    : '${_tableRow!.points}',
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.spacing3),
                            Expanded(
                              child: _TeamMetric(
                                label: 'Squad',
                                value: '${_roster.length}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  ClayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FIXTURES', style: TypographyTokens.titleLarge()),
                        const SizedBox(height: SpacingTokens.spacing3),
                        if (_fixtures.isEmpty)
                          const Text('No fixtures available for this team.')
                        else
                          ..._fixtures.map((fixture) {
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
                                            const SizedBox(height: 2),
                                            Text(
                                              '${fixture.competitionName} · ${_kickoffLabel(fixture.kickoffAt)}',
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
                                            : 'OPEN',
                                        style: TypographyTokens.monolithFont(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: fixture.isLive
                                              ? ColorTokens.success
                                              : ColorTokens.clubAccent,
                                        ),
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
                  ClayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SQUAD', style: TypographyTokens.titleLarge()),
                        const SizedBox(height: SpacingTokens.spacing3),
                        if (_roster.isEmpty)
                          const Text('Roster data is not available yet.')
                        else
                          Wrap(
                            spacing: SpacingTokens.spacing2,
                            runSpacing: SpacingTokens.spacing2,
                            children: _roster
                                .take(24)
                                .map((player) {
                                  final label = [
                                    if (player.squadNumber != null)
                                      '#${player.squadNumber}',
                                    player.playerShortName.isEmpty
                                        ? player.playerName
                                        : player.playerShortName,
                                    if (player.position != null)
                                      player.position,
                                  ].join(' · ');
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: SpacingTokens.spacing3,
                                      vertical: SpacingTokens.spacing2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ColorTokens.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      label,
                                      style: TypographyTokens.labelSmall(),
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TeamMetric extends StatelessWidget {
  const _TeamMetric({required this.label, required this.value});

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
            label.toUpperCase(),
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
