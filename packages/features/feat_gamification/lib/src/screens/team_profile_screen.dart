import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';

/// Team Profile — 5-tab layout matching the fanafrika reference:
/// Overview · Members · Fixtures · Contribute · About
class TeamProfileScreen extends ConsumerStatefulWidget {
  const TeamProfileScreen({super.key, required this.teamSlug});

  final String teamSlug;

  @override
  ConsumerState<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends ConsumerState<TeamProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  TeamCatalogEntry? _team;
  LeagueStandingEntry? _tableRow;
  List<TeamRosterPlayer> _roster = const <TeamRosterPlayer>[];
  List<FixtureSummary> _fixtures = const <FixtureSummary>[];
  int? _activeClubId;
  bool _isActiveClubTeam = false;
  PartnerPaymentRoute? _paymentRoute;
  String? _clubSupportMessage;
  bool _isLoading = true;
  String? _error;
  bool _isDialing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    unawaited(_load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

      final clubContext = await _resolveClubContext(team);

      if (!mounted) {
        return;
      }

      setState(() {
        _team = team;
        _tableRow = tableRow;
        _roster = roster;
        _fixtures = fixtures;
        _activeClubId = clubContext.clubId;
        _isActiveClubTeam = clubContext.isActiveClubTeam;
        _paymentRoute = clubContext.paymentRoute;
        _clubSupportMessage = clubContext.message;
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

  Future<_TeamClubContext> _resolveClubContext(TeamCatalogEntry? team) async {
    final client = ref.read(supabaseClientProvider);
    final resolver = ClubScopeResolver(client: client);
    final scope = await resolver.requireResolved();
    final clubId = scope.clubId;
    if (team == null || clubId == null) {
      return const _TeamClubContext(
        message: 'Supporter activity is only available for the active club.',
      );
    }

    try {
      final club = await client
          .from('african_football_clubs')
          .select('club_slug, club_name')
          .eq('id', clubId)
          .maybeSingle();
      final isActiveClubTeam = _matchesActiveClub(
        team,
        clubSlug: club?['club_slug']?.toString(),
        clubName: club?['club_name']?.toString(),
      );
      if (!isActiveClubTeam) {
        return _TeamClubContext(
          clubId: clubId,
          isActiveClubTeam: false,
          message:
              'Supporter registry and contribution routing are available for the current app club only.',
        );
      }

      var routeQuery = client
          .from('partner_payment_routes')
          .select()
          .eq('status', 'active');
      routeQuery = resolver.apply(routeQuery, scope);
      final routeRows = await routeQuery.limit(1);

      return _TeamClubContext(
        clubId: clubId,
        isActiveClubTeam: true,
        paymentRoute: routeRows.isEmpty
            ? null
            : PartnerPaymentRoute.fromJson(
                Map<String, dynamic>.from(routeRows.first),
              ),
        message: routeRows.isEmpty
            ? 'This club has not published an active contribution route yet.'
            : null,
      );
    } catch (_) {
      return _TeamClubContext(
        clubId: clubId,
        isActiveClubTeam: false,
        message: 'Club supporter data is temporarily unavailable.',
      );
    }
  }

  bool _matchesActiveClub(
    TeamCatalogEntry team, {
    String? clubSlug,
    String? clubName,
  }) {
    final normalizedClubSlug = _normalizeClubValue(clubSlug);
    final normalizedClubName = _normalizeClubValue(clubName);
    final normalizedHomeTeam = _normalizeClubValue(
      RuntimeBranding.displayHomeTeamName,
    );
    final candidates = <String>{
      _normalizeClubValue(team.sourceClubSlug),
      _normalizeClubValue(team.sourceClubName),
      _normalizeClubValue(team.name),
      _normalizeClubValue(team.shortName),
    }..removeWhere((value) => value.isEmpty);

    return candidates.contains(normalizedClubSlug) ||
        candidates.contains(normalizedClubName) ||
        candidates.contains(normalizedHomeTeam);
  }

  String _normalizeClubValue(String? value) {
    return (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _dialMomoUssd() async {
    if (!_isActiveClubTeam) {
      _showMessage(
        _clubSupportMessage ??
            'Contributions are only available for the active club in this app.',
      );
      return;
    }

    final route = _paymentRoute;
    if (route == null || route.recipientCode.trim().isEmpty) {
      _showMessage(
        _clubSupportMessage ??
            'No active contribution route is configured yet.',
      );
      return;
    }

    final amount = await _promptContributionAmount(route);
    if (amount == null || amount <= 0) {
      return;
    }

    setState(() => _isDialing = true);

    try {
      final launched = await MomoDialerService.launchMomoUssd(
        recipient: route.recipientCode,
        amount: amount,
        country: route.country,
        recipientType: PaymentRecipientType.code,
      );
      if (!launched) {
        _showMessage('Could not open the phone dialer.');
      }
    } catch (_) {
      _showMessage('Dialer launch failed.');
    } finally {
      if (mounted) {
        setState(() => _isDialing = false);
      }
    }
  }

  Future<int?> _promptContributionAmount(PartnerPaymentRoute route) async {
    final controller = TextEditingController();
    final amount = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter contribution amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You will pay ${route.payToLabel} via ${route.providerLabel}.',
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount (${route.country.currencyCode})',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          AfriButton(
            label: 'Dial now',
            onTap: () {
              final parsed = int.tryParse(
                controller.text.replaceAll(RegExp(r'[^0-9]'), ''),
              );
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount.')),
                );
                return;
              }
              Navigator.of(dialogContext).pop(parsed);
            },
            fullWidth: false,
          ),
        ],
      ),
    );
    controller.dispose();
    return amount;
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
          icon: const Icon(AfriIcons.back),
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
          : NestedScrollView(
              physics: const BouncingScrollPhysics(),
              headerSliverBuilder: (context, innerBoxScrolled) => [
                // ── Hero Card ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    child: ClayCard(
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
                  ),
                ),

                // ── Tab Bar ──
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    tabBar: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: ColorTokens.clubAccent,
                      unselectedLabelColor: ColorTokens.onSurfaceVariant,
                      indicatorColor: ColorTokens.clubAccent,
                      indicatorWeight: 2,
                      labelStyle: TypographyTokens.editorialFont(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Members'),
                        Tab(text: 'Fixtures'),
                        Tab(text: 'Contribute'),
                        Tab(text: 'About'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(
                    team: team,
                    tableRow: _tableRow,
                    paymentRoute: _paymentRoute,
                    isActiveClubTeam: _isActiveClubTeam,
                    clubSupportMessage: _clubSupportMessage,
                  ),
                  _MembersTab(
                    clubId: _activeClubId,
                    isActiveClubTeam: _isActiveClubTeam,
                  ),
                  _FixturesTab(
                    fixtures: _fixtures,
                    kickoffLabel: _kickoffLabel,
                  ),
                  _ContributeTab(
                    isDialing: _isDialing,
                    onDial: _dialMomoUssd,
                    paymentRoute: _paymentRoute,
                    isActiveClubTeam: _isActiveClubTeam,
                    clubSupportMessage: _clubSupportMessage,
                  ),
                  _AboutTab(team: team),
                ],
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TABS
// ═══════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.team,
    required this.tableRow,
    required this.paymentRoute,
    required this.isActiveClubTeam,
    required this.clubSupportMessage,
  });

  final TeamCatalogEntry? team;
  final LeagueStandingEntry? tableRow;
  final PartnerPaymentRoute? paymentRoute;
  final bool isActiveClubTeam;
  final String? clubSupportMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      physics: const BouncingScrollPhysics(),
      children: [
        // MoMo Contribution Code — dynamic per team
        Container(
              padding: const EdgeInsets.all(SpacingTokens.spacing4),
              decoration: BoxDecoration(
                color: ColorTokens.clubAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: BorderTokens.all(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActiveClubTeam
                        ? 'MOMO CONTRIBUTION ROUTE'
                        : 'CLUB CONTRIBUTIONS',
                    style: TypographyTokens.editorialFont(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: ColorTokens.clubAccent,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    paymentRoute != null
                        ? paymentRoute!.payToLabel
                        : isActiveClubTeam
                        ? 'Contribution route not configured'
                        : 'Supporter routing unavailable',
                    style: TypographyTokens.monolithFont(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ColorTokens.clubAccent,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    paymentRoute != null
                        ? (paymentRoute!.reconciliationLabel.trim().isNotEmpty
                              ? paymentRoute!.reconciliationLabel
                              : 'Use ${paymentRoute!.providerLabel} to contribute to ${team?.name ?? 'this club'}.')
                        : (clubSupportMessage ??
                              'Contribution instructions will appear when the club publishes a route.'),
                    style: TypographyTokens.bodySmall(),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.04, end: 0, duration: 400.ms),

        const SizedBox(height: SpacingTokens.spacing5),

        // Standings card if available
        if (tableRow != null)
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEAGUE POSITION',
                  style: TypographyTokens.editorialFont(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MiniStat(label: 'Pos', value: '#${tableRow!.position}'),
                    _MiniStat(label: 'P', value: '${tableRow!.played}'),
                    _MiniStat(label: 'W', value: '${tableRow!.won}'),
                    _MiniStat(label: 'D', value: '${tableRow!.drawn}'),
                    _MiniStat(label: 'L', value: '${tableRow!.lost}'),
                    _MiniStat(
                      label: 'GD',
                      value: '${tableRow!.goalDifference}',
                    ),
                    _MiniStat(label: 'Pts', value: '${tableRow!.points}'),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MembersTab extends ConsumerStatefulWidget {
  const _MembersTab({required this.clubId, required this.isActiveClubTeam});

  final int? clubId;
  final bool isActiveClubTeam;

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  List<_ClubMemberEntry> _contributors = const <_ClubMemberEntry>[];
  bool _isLoading = true;
  String? _message;

  int _legendCount = 0;
  int _ultraCount = 0;
  int _memberCount = 0;
  int _supporterCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!widget.isActiveClubTeam || widget.clubId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _message =
            'Supporter registry is available only for the current app club.';
      });
      return;
    }

    try {
      final client = ref.read(supabaseClientProvider);
      final currentUserId = client.auth.currentUser?.id;
      final clubId = widget.clubId!;
      final results = await Future.wait<Object?>([
        client
            .from('fan_memberships')
            .select('user_id, display_name, membership_number, points, tier')
            .eq('club_id', clubId)
            .order('points', ascending: false)
            .order('joined_at', ascending: true)
            .limit(10),
        client
            .from('fan_memberships')
            .select('id')
            .eq('club_id', clubId)
            .eq('tier', 'platinum')
            .count(CountOption.exact),
        client
            .from('fan_memberships')
            .select('id')
            .eq('club_id', clubId)
            .eq('tier', 'gold')
            .count(CountOption.exact),
        client
            .from('fan_memberships')
            .select('id')
            .eq('club_id', clubId)
            .eq('tier', 'bronze')
            .count(CountOption.exact),
        client
            .from('fan_memberships')
            .select('id')
            .eq('club_id', clubId)
            .eq('tier', 'fan')
            .count(CountOption.exact),
      ]);

      final topRows = List<Map<String, dynamic>>.from(results[0]! as List);
      final contributors = topRows
          .map(
            (row) => _ClubMemberEntry(
              userId: row['user_id']?.toString() ?? '',
              displayLabel: _memberLabel(
                displayName: row['display_name']?.toString(),
                membershipNumber: row['membership_number']?.toString(),
              ),
              tier: row['tier']?.toString() ?? 'fan',
              points: (row['points'] as num?)?.toInt() ?? 0,
              isCurrentUser:
                  currentUserId != null && row['user_id'] == currentUserId,
            ),
          )
          .toList(growable: false);

      setState(() {
        _contributors = contributors;
        _legendCount = ((results[1] as dynamic).count as int?) ?? 0;
        _ultraCount = ((results[2] as dynamic).count as int?) ?? 0;
        _memberCount = ((results[3] as dynamic).count as int?) ?? 0;
        _supporterCount = ((results[4] as dynamic).count as int?) ?? 0;
        _isLoading = false;
        _message = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _message = 'Club supporter data is temporarily unavailable.';
      });
    }
  }

  String _memberLabel({String? displayName, String? membershipNumber}) {
    final trimmedDisplay = displayName?.trim() ?? '';
    if (trimmedDisplay.isNotEmpty) {
      return trimmedDisplay;
    }
    final trimmedNumber = membershipNumber?.trim() ?? '';
    if (trimmedNumber.isNotEmpty) {
      return '#$trimmedNumber';
    }
    return '#------';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(SpacingTokens.spacing6),
        child: AfriSkeletonList(),
      );
    }

    if (_message != null && _contributors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriEmptyView(
            compact: true,
            title: 'Members unavailable',
            message: _message!,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      physics: const BouncingScrollPhysics(),
      children: [
        Text(
          'CLUB MEMBERS',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),

        // ── Tier Breakdown Grid (dynamic counts) ──
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: SpacingTokens.spacing3,
          mainAxisSpacing: SpacingTokens.spacing3,
          childAspectRatio: 1.5,
          children: [
            _TierCountCard(icon: '👑', label: 'Legends', count: _legendCount),
            _TierCountCard(icon: '🔥', label: 'Ultras', count: _ultraCount),
            _TierCountCard(icon: '🏅', label: 'Members', count: _memberCount),
            _TierCountCard(
              icon: '⚽',
              label: 'Supporters',
              count: _supporterCount,
            ),
          ],
        ),

        const SizedBox(height: SpacingTokens.spacing6),

        Text(
          'TOP CONTRIBUTORS',
          style: TypographyTokens.editorialFont(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),

        if (_contributors.isEmpty)
          AfriEmptyView(
            compact: true,
            title: 'No contributors yet',
            message:
                _message ?? 'Top contributors will appear as supporters join.',
          )
        else
          ..._contributors
              .take(10)
              .toList()
              .asMap()
              .entries
              .map(
                (entry) => _MemberRow(
                  rank: entry.key + 1,
                  fanId: entry.value.displayLabel,
                  tier: entry.value.tier.toUpperCase(),
                  fetLabel: '${entry.value.points} FET',
                  isMe: entry.value.isCurrentUser,
                ),
              ),
      ],
    );
  }
}

class _FixturesTab extends StatelessWidget {
  const _FixturesTab({required this.fixtures, required this.kickoffLabel});

  final List<FixtureSummary> fixtures;
  final String Function(DateTime?) kickoffLabel;

  @override
  Widget build(BuildContext context) {
    if (fixtures.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriEmptyView(
            title: 'No fixtures available',
            message: 'Upcoming and recent matches will appear here.',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      physics: const BouncingScrollPhysics(),
      itemCount: fixtures.length,
      itemBuilder: (context, index) {
        final fixture = fixtures[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
          child: AfriPressFeedback(
            onTap: () => context.push('/fanzone/match/${fixture.id}'),
            builder: (context, _) => GlassCard(
              animate: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fixture.fixtureLabel,
                          style: TypographyTokens.titleSmall(),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${fixture.competitionName} · ${kickoffLabel(fixture.kickoffAt)}',
                          style: TypographyTokens.bodySmall(),
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
      },
    );
  }
}

class _ContributeTab extends StatelessWidget {
  const _ContributeTab({
    required this.isDialing,
    required this.onDial,
    required this.paymentRoute,
    required this.isActiveClubTeam,
    required this.clubSupportMessage,
  });

  final bool isDialing;
  final VoidCallback onDial;
  final PartnerPaymentRoute? paymentRoute;
  final bool isActiveClubTeam;
  final String? clubSupportMessage;

  @override
  Widget build(BuildContext context) {
    if (!isActiveClubTeam) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriEmptyView(
            title: 'Contributions unavailable',
            message:
                clubSupportMessage ??
                'Contribution routing is only available for the active club in this app.',
          ),
        ),
      );
    }

    if (paymentRoute == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriEmptyView(
            title: 'No contribution route',
            message:
                clubSupportMessage ??
                'This club has not published an active contribution route yet.',
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      physics: const BouncingScrollPhysics(),
      children: [
        Text(
          'MOMO CONTRIBUTION',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing5),

        GlassCard(
          animate: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paymentRoute!.payToLabel,
                style: TypographyTokens.titleMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                paymentRoute!.reconciliationLabel.trim().isNotEmpty
                    ? paymentRoute!.reconciliationLabel
                    : 'Use ${paymentRoute!.providerLabel} in ${paymentRoute!.country.name} to contribute to this club.',
                style: TypographyTokens.bodyMedium(),
              ),
            ],
          ),
        ),

        const SizedBox(height: SpacingTokens.spacing5),

        ClayCard(
          child: Column(
            children: [
              _ContributeStep(
                stepNumber: 1,
                title: 'Enter amount',
                description:
                    'Choose how much you want to send through ${paymentRoute!.providerLabel}.',
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              _ContributeStep(
                stepNumber: 2,
                title: 'Confirm in dialer',
                description:
                    'We will open the mobile money dialer for code ${paymentRoute!.recipientCode}.',
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              const _ContributeStep(
                stepNumber: 3,
                title: 'Reconciliation',
                description:
                    'Your contribution is matched back to your club activity once payment is confirmed.',
              ),
            ],
          ),
        ),

        const SizedBox(height: SpacingTokens.spacing5),

        AfriButton(
              label: isDialing ? 'Opening dialer…' : 'Enter amount & dial',
              onTap: onDial,
              isLoading: isDialing,
              enabled: !isDialing,
            )
            .animate()
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .slideY(begin: 0.06, end: 0, duration: 400.ms),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.team});

  final TeamCatalogEntry? team;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      physics: const BouncingScrollPhysics(),
      children: [
        Text(
          'ABOUT ${team?.name.toUpperCase() ?? 'THIS CLUB'}',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        ClayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (team?.city != null) _InfoRow('Location', team!.city!),
              if (team?.countryName != null)
                _InfoRow('Country', team!.countryName!),
              if (team?.foundedYear != null)
                _InfoRow('Founded', '${team!.foundedYear}'),
              if (team?.teamType != null) _InfoRow('Type', team!.teamType!),
              if (team?.sourceClubName != null)
                _InfoRow('Affiliated Club', team!.sourceClubName!),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _TeamClubContext {
  const _TeamClubContext({
    this.clubId,
    this.isActiveClubTeam = false,
    this.paymentRoute,
    this.message,
  });

  final int? clubId;
  final bool isActiveClubTeam;
  final PartnerPaymentRoute? paymentRoute;
  final String? message;
}

class _ClubMemberEntry {
  const _ClubMemberEntry({
    required this.userId,
    required this.displayLabel,
    required this.tier,
    required this.points,
    required this.isCurrentUser,
  });

  final String userId;
  final String displayLabel;
  final String tier;
  final int points;
  final bool isCurrentUser;
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: ColorTokens.background, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TypographyTokens.monolithFont(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TierCountCard extends StatelessWidget {
  const _TierCountCard({
    required this.icon,
    required this.label,
    required this.count,
  });

  final String icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            '$count',
            style: TypographyTokens.monolithFont(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TypographyTokens.editorialFont(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ColorTokens.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributeStep extends StatelessWidget {
  const _ContributeStep({
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  final int stepNumber;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ColorTokens.clubAccent.withValues(alpha: 0.12),
            border: BorderTokens.all(
              color: ColorTokens.clubAccent.withValues(alpha: 0.3),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$stepNumber',
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TypographyTokens.titleSmall()),
              const SizedBox(height: 2),
              Text(description, style: TypographyTokens.bodySmall()),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.rank,
    required this.fanId,
    required this.tier,
    required this.fetLabel,
    this.isMe = false,
  });

  final int rank;
  final String fanId;
  final String tier;
  final String fetLabel;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.spacing3),
        decoration: BoxDecoration(
          color: isMe
              ? ColorTokens.clubAccent.withValues(alpha: 0.10)
              : ColorTokens.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: isMe
              ? BorderTokens.all(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.3),
                )
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '$rank',
                style: TypographyTokens.monolithFont(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing2),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorTokens.surfaceContainerHigh,
              ),
              alignment: Alignment.center,
              child: const Text('👤', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: SpacingTokens.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(fanId, style: TypographyTokens.titleSmall()),
                      if (isMe) ...[
                        const SizedBox(width: SpacingTokens.spacing2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ColorTokens.clubAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'YOU',
                            style: TypographyTokens.editorialFont(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: ColorTokens.background,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    tier,
                    style: TypographyTokens.editorialFont(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: ColorTokens.clubAccent,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              fetLabel,
              style: TypographyTokens.monolithFont(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ColorTokens.clubAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label.toUpperCase(),
              style: TypographyTokens.editorialFont(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorTokens.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(child: Text(value, style: TypographyTokens.bodyMedium())),
        ],
      ),
    );
  }
}

// Demo data removed — all content is now loaded dynamically from FetRepository.
