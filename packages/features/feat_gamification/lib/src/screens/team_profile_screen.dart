import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fanzone_models.dart';
import '../models/prediction_models.dart';
import '../models/team_profile_models.dart';
import '../prediction_providers.dart';
import '../widgets/team_profile_tabs.dart';
import '../widgets/team_profile_widgets.dart';

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
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'TeamProfileScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Team profile is temporarily unavailable.';
      });
    }
  }

  Future<TeamClubContext> _resolveClubContext(TeamCatalogEntry? team) async {
    final client = ref.read(supabaseClientProvider);
    final resolver = ClubScopeResolver(client: client);
    final scope = await resolver.requireResolved();
    final clubId = scope.clubId;
    if (team == null || clubId == null) {
      return const TeamClubContext(
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
        return TeamClubContext(
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

      return TeamClubContext(
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
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'TeamProfileScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      return TeamClubContext(
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
      _showMessage(_clubSupportMessage ?? 'Contribution route unavailable.');
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
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'TeamProfileScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
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
      builder: (dialogContext) => AfriAlertDialog(
        title: const Text('Enter contribution amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You will pay ${route.payToLabel} via ${route.providerLabel}.',
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriInputField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              label: 'Amount (${route.country.currencyCode})',
            ),
          ],
        ),
        actions: [
          AfriTextButton(
            onPressed: () => dialogContext.pop(),
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
              dialogContext.pop(parsed);
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
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          team?.shortName.toUpperCase() ?? 'TEAM PROFILE',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
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
                    child: AfriSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team?.name.toUpperCase() ?? 'TEAM',
                            style: TypographyTokens.headlineLarge().copyWith(
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
                                child: TeamMetric(
                                  label: 'Table',
                                  value: _tableRow == null
                                      ? '--'
                                      : '#${_tableRow!.position}',
                                ),
                              ),
                              const SizedBox(width: SpacingTokens.spacing3),
                              Expanded(
                                child: TeamMetric(
                                  label: 'Points',
                                  value: _tableRow == null
                                      ? '--'
                                      : '${_tableRow!.points}',
                                ),
                              ),
                              const SizedBox(width: SpacingTokens.spacing3),
                              Expanded(
                                child: TeamMetric(
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

                SliverPersistentHeader(
                  pinned: true,
                  delegate: TeamTabBarDelegate(
                    tabBar: AfriTabBar.line(
                      controller: _tabController,
                      isScrollable: true,
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
                  TeamOverviewTab(
                    team: team,
                    tableRow: _tableRow,
                    paymentRoute: _paymentRoute,
                    isActiveClubTeam: _isActiveClubTeam,
                    clubSupportMessage: _clubSupportMessage,
                  ),
                  TeamMembersTab(
                    clubId: _activeClubId,
                    isActiveClubTeam: _isActiveClubTeam,
                  ),
                  TeamFixturesTab(
                    fixtures: _fixtures,
                    kickoffLabel: _kickoffLabel,
                  ),
                  TeamContributeTab(
                    isDialing: _isDialing,
                    onDial: _dialMomoUssd,
                    paymentRoute: _paymentRoute,
                    isActiveClubTeam: _isActiveClubTeam,
                    clubSupportMessage: _clubSupportMessage,
                  ),
                  TeamAboutTab(team: team),
                ],
              ),
            ),
    );
  }
}

// Demo data removed — all content is now loaded dynamically from FetRepository.
