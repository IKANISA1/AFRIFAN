import 'dart:async';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
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

/// Team Profile — Overview · Members · Fixtures · About, with the legacy
/// direct-contribution tab available only in an unenforced development build.
class TeamProfileScreen extends ConsumerStatefulWidget {
  const TeamProfileScreen({super.key, required this.teamSlug});

  final String teamSlug;

  @override
  ConsumerState<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends ConsumerState<TeamProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final bool _allowsUnreconciledExternalPaymentLaunch;

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
    _allowsUnreconciledExternalPaymentLaunch = ref
        .read(storeReleasePolicyProvider)
        .allowsUnreconciledExternalPaymentLaunch;
    _tabController = TabController(
      length: _allowsUnreconciledExternalPaymentLaunch ? 5 : 4,
      vsync: this,
    );
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

      if (!mounted) {
        return;
      }
      final clubContext = await _resolveClubContext(team, context.afriL10n);

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
        _error = team == null ? context.afriL10n.gameTeamNotFound : null;
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
        _error = context.afriL10n.gameTeamProfileTemporarilyUnavailable;
      });
    }
  }

  Future<TeamClubContext> _resolveClubContext(
    TeamCatalogEntry? team,
    AfriLocalizations l10n,
  ) async {
    final client = ref.read(supabaseClientProvider);
    final resolver = ClubScopeResolver(client: client);
    final scope = await resolver.requireResolved();
    final clubId = scope.clubId;
    if (team == null || clubId == null) {
      return TeamClubContext(message: l10n.gameSupporterActivityActiveClubOnly);
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
          message: l10n.gameSupporterRoutingCurrentClubOnly,
        );
      }

      if (!_allowsUnreconciledExternalPaymentLaunch) {
        return TeamClubContext(clubId: clubId, isActiveClubTeam: true);
      }

      var routeQuery = client
          .from('partner_payment_routes')
          .select(
            'id,partner_id,club_id,partner_name,partner_slug,country,provider,'
            'recipient_code,reconciliation_label,status',
          )
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
            ? l10n.gameContributionRouteNotPublished
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
        message: l10n.gameClubSupporterDataUnavailable,
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
    AfriToast.info(context, message);
  }

  Future<void> _dialMomoUssd() async {
    if (!_allowsUnreconciledExternalPaymentLaunch) {
      return;
    }

    if (!_isActiveClubTeam) {
      _showMessage(
        _clubSupportMessage ?? context.afriL10n.gameContributionsActiveClubOnly,
      );
      return;
    }

    final route = _paymentRoute;
    if (route == null || route.recipientCode.trim().isEmpty) {
      _showMessage(
        _clubSupportMessage ??
            context.afriL10n.gameContributionRouteUnavailable,
      );
      return;
    }

    final amount = await _promptContributionAmount(route);
    if (amount == null || amount <= 0) {
      return;
    }
    if (!mounted) {
      return;
    }

    final l10n = context.afriL10n;
    setState(() => _isDialing = true);

    try {
      final launched = await MomoDialerService.launchMomoUssd(
        recipient: route.recipientCode,
        amount: amount,
        country: route.country,
        recipientType: PaymentRecipientType.code,
      );
      if (!launched) {
        _showMessage(l10n.gameCouldNotOpenDialer);
      }
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'TeamProfileScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      _showMessage(l10n.gameDialerLaunchFailed);
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
        title: Text(dialogContext.afriL10n.gameEnterContributionAmount),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dialogContext.afriL10n.gamePaymentRouteDescription(
                route.payToLabel,
                route.providerLabel,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriInputField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              label: dialogContext.afriL10n.gameAmountCurrency(
                route.country.currencyCode,
              ),
            ),
          ],
        ),
        actions: [
          AfriTextButton(
            onPressed: () => dialogContext.pop(),
            child: Text(dialogContext.afriL10n.gameCancel),
          ),
          AfriButton(
            label: dialogContext.afriL10n.gameDialNow,
            onTap: () {
              final parsed = int.tryParse(
                controller.text.replaceAll(RegExp(r'[^0-9]'), ''),
              );
              if (parsed == null || parsed <= 0) {
                AfriToast.error(
                  dialogContext,
                  dialogContext.afriL10n.gameEnterValidAmount,
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

  String _kickoffLabel(BuildContext context, DateTime? value) {
    if (value == null) {
      return context.afriL10n.gameTbd;
    }
    final local = value.toLocal();
    final materialL10n = MaterialLocalizations.of(context);
    return '${materialL10n.formatShortDate(local)} • '
        '${materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final team = _team;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          team?.shortName.toUpperCase() ??
              context.afriL10n.gameTeamProfileTitle,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.gameBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: context.afriL10n.gameTeamUnavailable,
                  message: _error!,
                  actionLabel: context.afriL10n.gameRetry,
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
                            team?.name.toUpperCase() ??
                                context.afriL10n.gameTeamUpper,
                            style: TypographyTokens.headlineLarge().copyWith(
                              fontWeight: FontWeight.w900,
                              height: TypographyTokens.lineHeightCompact,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          Text(
                            [
                                  team?.city,
                                  team?.countryName,
                                  if (team?.foundedYear != null)
                                    context.afriL10n.gameFoundedYear(
                                      team!.foundedYear!,
                                    ),
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
                                  label: context.afriL10n.gameTable,
                                  value: _tableRow == null
                                      ? '--'
                                      : '#${_tableRow!.position}',
                                ),
                              ),
                              const SizedBox(width: SpacingTokens.spacing3),
                              Expanded(
                                child: TeamMetric(
                                  label: context.afriL10n.gamePointsShort,
                                  value: _tableRow == null
                                      ? '--'
                                      : '${_tableRow!.points}',
                                ),
                              ),
                              const SizedBox(width: SpacingTokens.spacing3),
                              Expanded(
                                child: TeamMetric(
                                  label: context.afriL10n.gameSquad,
                                  value: _roster.length.toString(),
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
                      tabs: [
                        Tab(text: context.afriL10n.gameOverview),
                        Tab(text: context.afriL10n.gameMembers),
                        Tab(text: context.afriL10n.gameFixtures),
                        if (_allowsUnreconciledExternalPaymentLaunch)
                          Tab(text: context.afriL10n.gameContribute),
                        Tab(text: context.afriL10n.gameAbout),
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
                    allowsUnreconciledExternalPaymentLaunch:
                        _allowsUnreconciledExternalPaymentLaunch,
                  ),
                  TeamMembersTab(
                    clubId: _activeClubId,
                    isActiveClubTeam: _isActiveClubTeam,
                  ),
                  TeamFixturesTab(
                    fixtures: _fixtures,
                    kickoffLabel: (value) => _kickoffLabel(context, value),
                  ),
                  if (_allowsUnreconciledExternalPaymentLaunch)
                    TeamContributeTab(
                      isDialing: _isDialing,
                      onDial: _dialMomoUssd,
                      paymentRoute: _paymentRoute,
                      isActiveClubTeam: _isActiveClubTeam,
                      clubSupportMessage: _clubSupportMessage,
                      allowsUnreconciledExternalPaymentLaunch:
                          _allowsUnreconciledExternalPaymentLaunch,
                    ),
                  TeamAboutTab(team: team),
                ],
              ),
            ),
    );
  }
}

// Demo data removed — all content is now loaded dynamically from FetRepository.
