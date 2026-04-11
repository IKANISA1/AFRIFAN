import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/leaderboard/league_table_widget.dart';
import 'package:africlub_fantasy/features/leaderboard/rank_row_widget.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/models/entry_gameweek_score.dart';
import 'package:africlub_fantasy/models/fantasy_entry.dart';
import 'package:africlub_fantasy/models/fantasy_league.dart';
import 'package:africlub_fantasy/models/league_h2h_fixture.dart';
import 'package:africlub_fantasy/models/league_member.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:africlub_fantasy/providers/league_providers.dart';
import 'package:africlub_fantasy/providers/squad_providers.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  FantasyLeague? _selectedLeague;
  bool _leagueActionInFlight = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final competitionAsync = ref.watch(competitionProvider(widget.slug));

    return FantasyScaffold(
      title: 'Leaderboard',
      appBarBottom: TabBar(
        controller: _tabController,
        labelColor: FantasyColors.textPrimary,
        unselectedLabelColor: FantasyColors.textSecondary,
        indicatorColor: FantasyColors.successGreen,
        tabs: const <Tab>[
          Tab(text: 'Global'),
          Tab(text: 'My Leagues'),
        ],
      ),
      child: competitionAsync.when(
        data: (competition) {
          final currentGwAsync = ref.watch(
            currentGameweekProvider(competition.id),
          );
          final entryAsync = ref.watch(myEntryProvider(competition.id));

          return currentGwAsync.when(
            data: (gameweek) {
              final globalAsync = ref.watch(
                globalLeaderboardProvider((
                  competitionId: competition.id,
                  gameweekId: gameweek?.id,
                )),
              );
              final leaguesAsync = ref.watch(myLeaguesProvider(competition.id));

              return TabBarView(
                controller: _tabController,
                children: <Widget>[
                  globalAsync.when(
                    data: (rows) => _GlobalLeaderboardTab(
                      rows: rows,
                      myEntryId: entryAsync.valueOrNull?.id,
                    ),
                    loading: () =>
                        const Center(child: FantasyStateCard.loading()),
                    error: (error, _) => Center(
                      child: FantasyStateCard.error(
                        title: 'Leaderboard failed to load',
                        message: error.toString(),
                      ),
                    ),
                  ),
                  leaguesAsync.when(
                    data: (leagues) {
                      final selected = _resolveSelectedLeague(leagues);
                      final tableAsync = gameweek == null || selected == null
                          ? const AsyncValue<List<EntryGameweekScore>>.data(
                              <EntryGameweekScore>[],
                            )
                          : ref.watch(
                              leagueTableProvider((
                                leagueId: selected.id,
                                gameweekId: gameweek.id,
                              )),
                            );
                      final membersAsync = selected == null
                          ? const AsyncValue<List<LeagueMember>>.data(
                              <LeagueMember>[],
                            )
                          : ref.watch(leagueMembersProvider(selected.id));
                      final h2hAsync =
                          selected == null ||
                              selected.type != FantasyLeagueType.headToHead
                          ? const AsyncValue<List<LeagueH2HFixture>>.data(
                              <LeagueH2HFixture>[],
                            )
                          : ref.watch(leagueH2HFixturesProvider(selected.id));

                      return ListView(
                        padding: const EdgeInsets.all(FantasySpacing.md),
                        children: <Widget>[
                          _LeagueActionsCard(
                            disabled:
                                _leagueActionInFlight ||
                                entryAsync.valueOrNull == null,
                            onCreate: () => _showCreateLeagueSheet(
                              context: context,
                              competitionId: competition.id,
                              entry: entryAsync.valueOrNull,
                            ),
                            onJoin: () => _showJoinLeagueSheet(
                              context: context,
                              competitionId: competition.id,
                              entry: entryAsync.valueOrNull,
                            ),
                          ),
                          const SizedBox(height: FantasySpacing.md),
                          if (entryAsync.valueOrNull == null)
                            const FantasyStateCard.empty(
                              title: 'Build a squad first',
                              message:
                                  'Create your fantasy entry before joining or creating private leagues.',
                            )
                          else if (leagues.isEmpty)
                            const FantasyStateCard.empty(
                              title: 'No leagues joined',
                              message:
                                  'Create or join a league to track private standings.',
                            )
                          else ...<Widget>[
                            Wrap(
                              spacing: FantasySpacing.sm,
                              runSpacing: FantasySpacing.sm,
                              children: leagues
                                  .map(
                                    (league) => FantasyChipChoice(
                                      label: league.name,
                                      selected: selected?.id == league.id,
                                      onTap: () => setState(
                                        () => _selectedLeague = league,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                            const SizedBox(height: FantasySpacing.md),
                            FantasyGlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  FantasySectionHeader(
                                    title: selected!.name,
                                    subtitle:
                                        'Code ${selected.code} · ${selected.memberCount} members',
                                    trailing: FantasyStatusBadge(
                                      label:
                                          selected.type ==
                                              FantasyLeagueType.headToHead
                                          ? 'H2H'
                                          : 'Classic',
                                      color:
                                          selected.type ==
                                              FantasyLeagueType.headToHead
                                          ? FantasyColors.wcGold
                                          : FantasyColors.successGreen,
                                    ),
                                  ),
                                  const SizedBox(height: FantasySpacing.md),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: AfriButton(
                                          label:
                                              'Share invite code ${selected.code}',
                                          onTap: () {
                                            AfriToast.success(
                                              context,
                                              'Share code ${selected.code} with other managers.',
                                            );
                                          },
                                          variant: AfriButtonVariant.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: FantasySpacing.sm),
                                      IconButton(
                                        tooltip: 'Leave league',
                                        onPressed: _leagueActionInFlight
                                            ? null
                                            : () => _leaveLeague(
                                                context: context,
                                                competitionId: competition.id,
                                                league: selected,
                                                entry: entryAsync.valueOrNull,
                                              ),
                                        icon: const Icon(
                                          Icons.exit_to_app_rounded,
                                        ),
                                        color: FantasyColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: FantasySpacing.md),
                                  membersAsync.when(
                                    data: (members) => _LeagueMembersCard(
                                      members: members,
                                      highlightEntryId:
                                          entryAsync.valueOrNull?.id,
                                    ),
                                    loading: () =>
                                        const FantasySkeletonCard(height: 120),
                                    error: (error, _) => FantasyStateCard.error(
                                      title: 'Members failed to load',
                                      message: error.toString(),
                                    ),
                                  ),
                                  const SizedBox(height: FantasySpacing.md),
                                  tableAsync.when(
                                    data: (rows) => LeagueTableWidget(
                                      rows: rows,
                                      highlightEntryId:
                                          entryAsync.valueOrNull?.id,
                                    ),
                                    loading: () =>
                                        const FantasySkeletonCard(height: 260),
                                    error: (error, _) => FantasyStateCard.error(
                                      title: 'League table failed to load',
                                      message: error.toString(),
                                    ),
                                  ),
                                  if (selected.type ==
                                      FantasyLeagueType.headToHead) ...<Widget>[
                                    const SizedBox(height: FantasySpacing.md),
                                    h2hAsync.when(
                                      data: (fixtures) => _HeadToHeadCard(
                                        fixtures: fixtures,
                                        highlightEntryId:
                                            entryAsync.valueOrNull?.id,
                                      ),
                                      loading: () => const FantasySkeletonCard(
                                        height: 220,
                                      ),
                                      error: (error, _) =>
                                          FantasyStateCard.error(
                                            title:
                                                'Head-to-head failed to load',
                                            message: error.toString(),
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: FantasyStateCard.loading()),
                    error: (error, _) => Center(
                      child: FantasyStateCard.error(
                        title: 'Leagues failed to load',
                        message: error.toString(),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: FantasyStateCard.loading()),
            error: (error, _) => Center(
              child: FantasyStateCard.error(
                title: 'Gameweek failed to load',
                message: error.toString(),
              ),
            ),
          );
        },
        loading: () => const Center(child: FantasyStateCard.loading()),
        error: (error, _) => Center(
          child: FantasyStateCard.error(
            title: 'Competition failed to load',
            message: error.toString(),
          ),
        ),
      ),
    );
  }

  FantasyLeague? _resolveSelectedLeague(List<FantasyLeague> leagues) {
    if (leagues.isEmpty) {
      return null;
    }
    final selectedId = _selectedLeague?.id;
    for (final league in leagues) {
      if (league.id == selectedId) {
        return league;
      }
    }
    return leagues.first;
  }

  Future<void> _showCreateLeagueSheet({
    required BuildContext context,
    required String competitionId,
    required FantasyEntry? entry,
  }) async {
    if (entry == null) {
      AfriToast.error(context, 'Build a squad first before creating a league.');
      return;
    }

    final input = await showModalBottomSheet<_CreateLeagueInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateLeagueSheet(),
    );
    if (input == null || !mounted) {
      return;
    }

    setState(() => _leagueActionInFlight = true);
    try {
      final league = await ref
          .read(leagueRepositoryProvider)
          .createLeague(
            competitionId: competitionId,
            entryId: entry.id,
            name: input.name,
            type: input.type,
            isPublic: input.isPublic,
          );
      ref.invalidate(myLeaguesProvider(competitionId));
      if (mounted) {
        setState(() => _selectedLeague = league);
        AfriToast.success(
          context,
          '${league.name} created. Share code ${league.code}.',
        );
      }
    } catch (error) {
      if (mounted) {
        AfriToast.error(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _leagueActionInFlight = false);
      }
    }
  }

  Future<void> _showJoinLeagueSheet({
    required BuildContext context,
    required String competitionId,
    required FantasyEntry? entry,
  }) async {
    if (entry == null) {
      AfriToast.error(context, 'Build a squad first before joining a league.');
      return;
    }

    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _JoinLeagueSheet(),
    );
    if (code == null || !mounted) {
      return;
    }

    setState(() => _leagueActionInFlight = true);
    try {
      final league = await ref
          .read(leagueRepositoryProvider)
          .joinLeague(leagueCode: code, entry: entry);
      ref.invalidate(myLeaguesProvider(competitionId));
      if (mounted) {
        setState(() => _selectedLeague = league);
        AfriToast.success(
          context,
          'Joined ${league.name}. League code ${league.code}.',
        );
      }
    } catch (error) {
      if (mounted) {
        AfriToast.error(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _leagueActionInFlight = false);
      }
    }
  }

  Future<void> _leaveLeague({
    required BuildContext context,
    required String competitionId,
    required FantasyLeague league,
    required FantasyEntry? entry,
  }) async {
    if (entry == null) {
      return;
    }

    setState(() => _leagueActionInFlight = true);
    try {
      await ref
          .read(leagueRepositoryProvider)
          .leaveLeague(leagueId: league.id, entry: entry);
      ref.invalidate(myLeaguesProvider(competitionId));
      ref.invalidate(leagueMembersProvider(league.id));
      ref.invalidate(leagueH2HFixturesProvider(league.id));
      if (mounted) {
        setState(() => _selectedLeague = null);
        AfriToast.success(context, 'Left ${league.name}.');
      }
    } catch (error) {
      if (mounted) {
        AfriToast.error(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _leagueActionInFlight = false);
      }
    }
  }
}

class _GlobalLeaderboardTab extends StatelessWidget {
  const _GlobalLeaderboardTab({required this.rows, required this.myEntryId});

  final List<EntryGameweekScore> rows;
  final String? myEntryId;

  @override
  Widget build(BuildContext context) {
    EntryGameweekScore? myRow;
    if (myEntryId != null) {
      for (final row in rows) {
        if (row.entryId == myEntryId) {
          myRow = row;
          break;
        }
      }
    }

    return Stack(
      children: <Widget>[
        ListView(
          padding: const EdgeInsets.fromLTRB(
            FantasySpacing.md,
            FantasySpacing.md,
            FantasySpacing.md,
            120,
          ),
          children: <Widget>[
            LeagueTableWidget(rows: rows.take(100).toList(growable: false)),
          ],
        ),
        if (myRow != null)
          Positioned(
            left: FantasySpacing.md,
            right: FantasySpacing.md,
            bottom: FantasySpacing.md,
            child: RankRowWidget(entry: myRow, highlight: true),
          ),
      ],
    );
  }
}

class _LeagueActionsCard extends StatelessWidget {
  const _LeagueActionsCard({
    required this.disabled,
    required this.onCreate,
    required this.onJoin,
  });

  final bool disabled;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return FantasyGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const FantasySectionHeader(
            title: 'Private leagues',
            subtitle: 'Create classic tables or head-to-head schedules.',
          ),
          const SizedBox(height: FantasySpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: AfriButton(
                  label: 'Create league',
                  onTap: onCreate,
                  enabled: !disabled,
                  variant: AfriButtonVariant.accent,
                ),
              ),
              const SizedBox(width: FantasySpacing.sm),
              Expanded(
                child: AfriButton(
                  label: 'Join with code',
                  onTap: onJoin,
                  enabled: !disabled,
                  variant: AfriButtonVariant.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeagueMembersCard extends StatelessWidget {
  const _LeagueMembersCard({
    required this.members,
    required this.highlightEntryId,
  });

  final List<LeagueMember> members;
  final String? highlightEntryId;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const FantasyStateCard.empty(
        title: 'No members yet',
        message: 'Invite more managers to activate this league table.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'League members',
          style: FantasyTypography.body.copyWith(
            color: FantasyColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: FantasySpacing.sm),
        Wrap(
          spacing: FantasySpacing.sm,
          runSpacing: FantasySpacing.sm,
          children: members
              .map(
                (member) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FantasySpacing.sm,
                    vertical: FantasySpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: member.entryId == highlightEntryId
                        ? FantasyColors.successGreen.withValues(alpha: 0.18)
                        : FantasyColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: member.entryId == highlightEntryId
                          ? FantasyColors.successGreen
                          : FantasyColors.border,
                    ),
                  ),
                  child: Text(
                    member.overallRank == null
                        ? member.teamName
                        : '${member.teamName} · #${member.overallRank}',
                    style: FantasyTypography.caption.copyWith(
                      color: FantasyColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _HeadToHeadCard extends StatelessWidget {
  const _HeadToHeadCard({
    required this.fixtures,
    required this.highlightEntryId,
  });

  final List<LeagueH2HFixture> fixtures;
  final String? highlightEntryId;

  @override
  Widget build(BuildContext context) {
    if (fixtures.isEmpty) {
      return const FantasyStateCard.empty(
        title: 'Schedule pending',
        message: 'Head-to-head pairings will appear once enough managers join.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Head-to-head schedule',
          style: FantasyTypography.body.copyWith(
            color: FantasyColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: FantasySpacing.sm),
        ...fixtures
            .take(10)
            .map(
              (fixture) => Container(
                margin: const EdgeInsets.only(bottom: FantasySpacing.sm),
                padding: const EdgeInsets.all(FantasySpacing.md),
                decoration: BoxDecoration(
                  color: fixture.involvesEntry(highlightEntryId ?? '')
                      ? FantasyColors.wcGold.withValues(alpha: 0.14)
                      : FantasyColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: fixture.involvesEntry(highlightEntryId ?? '')
                        ? FantasyColors.wcGold
                        : FantasyColors.border,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'GW${fixture.gameweekNumber} · ${fixture.gameweekName}',
                            style: FantasyTypography.label.copyWith(
                              color: FantasyColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: FantasySpacing.xs),
                          Text(
                            '${fixture.homeTeamName} vs ${fixture.awayTeamName}',
                            style: FantasyTypography.body.copyWith(
                              color: FantasyColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          fixture.scoreLabel(),
                          style: FantasyTypography.h3.copyWith(
                            color: FantasyColors.textPrimary,
                          ),
                        ),
                        Text(
                          fixture.isFinished
                              ? 'Final'
                              : fixture.isLive
                              ? 'Live'
                              : 'Upcoming',
                          style: FantasyTypography.label.copyWith(
                            color: fixture.isFinished || fixture.isLive
                                ? FantasyColors.successGreen
                                : FantasyColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _CreateLeagueInput {
  const _CreateLeagueInput({
    required this.name,
    required this.type,
    required this.isPublic,
  });

  final String name;
  final FantasyLeagueType type;
  final bool isPublic;
}

class _CreateLeagueSheet extends StatefulWidget {
  const _CreateLeagueSheet();

  @override
  State<_CreateLeagueSheet> createState() => _CreateLeagueSheetState();
}

class _CreateLeagueSheetState extends State<_CreateLeagueSheet> {
  final TextEditingController _nameController = TextEditingController();
  FantasyLeagueType _type = FantasyLeagueType.classic;
  bool _isPublic = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FantasySpacing.md,
        FantasySpacing.lg,
        FantasySpacing.md,
        bottomInset + FantasySpacing.md,
      ),
      child: FantasyGlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Create league',
              style: FantasyTypography.h2.copyWith(
                color: FantasyColors.textPrimary,
              ),
            ),
            const SizedBox(height: FantasySpacing.md),
            FantasySearchField(
              controller: _nameController,
              hintText: 'League name',
            ),
            const SizedBox(height: FantasySpacing.md),
            Wrap(
              spacing: FantasySpacing.sm,
              children: <Widget>[
                FantasyChipChoice(
                  label: 'Classic',
                  selected: _type == FantasyLeagueType.classic,
                  onTap: () =>
                      setState(() => _type = FantasyLeagueType.classic),
                ),
                FantasyChipChoice(
                  label: 'Head-to-head',
                  selected: _type == FantasyLeagueType.headToHead,
                  onTap: () =>
                      setState(() => _type = FantasyLeagueType.headToHead),
                ),
              ],
            ),
            const SizedBox(height: FantasySpacing.sm),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Visible in public league directory',
                style: FantasyTypography.body.copyWith(
                  color: FantasyColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Keep this off for invite-only leagues.',
                style: FantasyTypography.caption.copyWith(
                  color: FantasyColors.textSecondary,
                ),
              ),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
            const SizedBox(height: FantasySpacing.md),
            AfriButton(
              label: 'Create league',
              onTap: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(
                  _CreateLeagueInput(
                    name: name,
                    type: _type,
                    isPublic: _isPublic,
                  ),
                );
              },
              variant: AfriButtonVariant.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinLeagueSheet extends StatefulWidget {
  const _JoinLeagueSheet();

  @override
  State<_JoinLeagueSheet> createState() => _JoinLeagueSheetState();
}

class _JoinLeagueSheetState extends State<_JoinLeagueSheet> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FantasySpacing.md,
        FantasySpacing.lg,
        FantasySpacing.md,
        bottomInset + FantasySpacing.md,
      ),
      child: FantasyGlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Join league',
              style: FantasyTypography.h2.copyWith(
                color: FantasyColors.textPrimary,
              ),
            ),
            const SizedBox(height: FantasySpacing.md),
            FantasySearchField(
              controller: _codeController,
              hintText: 'Invite code',
            ),
            const SizedBox(height: FantasySpacing.md),
            AfriButton(
              label: 'Join',
              onTap: () {
                final code = _codeController.text.trim().toUpperCase();
                if (code.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(code);
              },
              variant: AfriButtonVariant.accent,
            ),
          ],
        ),
      ),
    );
  }
}
