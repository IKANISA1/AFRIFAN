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
import '../models/team_profile_models.dart';
import 'team_profile_widgets.dart';

// ═══════════════════════════════════════════════════════════════════
// TEAM PROFILE TABS
// ═══════════════════════════════════════════════════════════════════

/// Overview tab — MoMo route banner + league standings card.
class TeamOverviewTab extends StatelessWidget {
  const TeamOverviewTab({
    super.key,
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
                    MiniStat(label: 'Pos', value: '#${tableRow!.position}'),
                    MiniStat(label: 'P', value: '${tableRow!.played}'),
                    MiniStat(label: 'W', value: '${tableRow!.won}'),
                    MiniStat(label: 'D', value: '${tableRow!.drawn}'),
                    MiniStat(label: 'L', value: '${tableRow!.lost}'),
                    MiniStat(
                      label: 'GD',
                      value: '${tableRow!.goalDifference}',
                    ),
                    MiniStat(label: 'Pts', value: '${tableRow!.points}'),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Members tab — tier breakdown grid + top contributors list.
class TeamMembersTab extends ConsumerStatefulWidget {
  const TeamMembersTab({
    super.key,
    required this.clubId,
    required this.isActiveClubTeam,
  });

  final int? clubId;
  final bool isActiveClubTeam;

  @override
  ConsumerState<TeamMembersTab> createState() => _TeamMembersTabState();
}

class _TeamMembersTabState extends ConsumerState<TeamMembersTab> {
  List<ClubMemberEntry> _contributors = const <ClubMemberEntry>[];
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
            (row) => ClubMemberEntry(
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
            TierCountCard(icon: '👑', label: 'Legends', count: _legendCount),
            TierCountCard(icon: '🔥', label: 'Ultras', count: _ultraCount),
            TierCountCard(icon: '🏅', label: 'Members', count: _memberCount),
            TierCountCard(
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
                (entry) => MemberRow(
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

/// Fixtures tab — scrollable list of upcoming/recent matches.
class TeamFixturesTab extends StatelessWidget {
  const TeamFixturesTab({
    super.key,
    required this.fixtures,
    required this.kickoffLabel,
  });

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

/// Contribute tab — MoMo contribution instructions + dialer CTA.
class TeamContributeTab extends StatelessWidget {
  const TeamContributeTab({
    super.key,
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
              ContributeStep(
                stepNumber: 1,
                title: 'Enter amount',
                description:
                    'Choose how much you want to send through ${paymentRoute!.providerLabel}.',
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              ContributeStep(
                stepNumber: 2,
                title: 'Confirm in dialer',
                description:
                    'We will open the mobile money dialer for code ${paymentRoute!.recipientCode}.',
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              const ContributeStep(
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

/// About tab — basic team info (location, founded, type).
class TeamAboutTab extends StatelessWidget {
  const TeamAboutTab({super.key, required this.team});

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
              if (team?.city != null) TeamInfoRow('Location', team!.city!),
              if (team?.countryName != null)
                TeamInfoRow('Country', team!.countryName!),
              if (team?.foundedYear != null)
                TeamInfoRow('Founded', '${team!.foundedYear}'),
              if (team?.teamType != null) TeamInfoRow('Type', team!.teamType!),
              if (team?.sourceClubName != null)
                TeamInfoRow('Affiliated Club', team!.sourceClubName!),
            ],
          ),
        ),
      ],
    );
  }
}
