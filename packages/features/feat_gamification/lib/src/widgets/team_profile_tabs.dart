import 'dart:async';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
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
import 'tier_label.dart';

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
    required this.allowsUnreconciledExternalPaymentLaunch,
  });

  final TeamCatalogEntry? team;
  final LeagueStandingEntry? tableRow;
  final PartnerPaymentRoute? paymentRoute;
  final bool isActiveClubTeam;
  final String? clubSupportMessage;
  final bool allowsUnreconciledExternalPaymentLaunch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      physics: const BouncingScrollPhysics(),
      children: [
        if (allowsUnreconciledExternalPaymentLaunch &&
            isActiveClubTeam &&
            paymentRoute != null) ...[
          TeamContributionRouteBanner(team: team, paymentRoute: paymentRoute!),
          const SizedBox(height: SpacingTokens.spacing5),
        ],

        // Standings card if available
        if (tableRow != null)
          AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.afriL10n.gameLeaguePosition,
                  style:
                      TypographyTokens.metricLabel(
                        ColorTokens.onSurfaceVariant,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: TypographyTokens.trackingNone,
                      ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MiniStat(
                      label: context.afriL10n.gamePositionShort,
                      value: context.afriL10n.gameRankHash(tableRow!.position),
                    ),
                    MiniStat(
                      label: context.afriL10n.gamePlayedShort,
                      value: tableRow!.played.toString(),
                    ),
                    MiniStat(
                      label: context.afriL10n.gameWonShort,
                      value: tableRow!.won.toString(),
                    ),
                    MiniStat(
                      label: context.afriL10n.gameDrawnShort,
                      value: tableRow!.drawn.toString(),
                    ),
                    MiniStat(
                      label: context.afriL10n.gameLostShort,
                      value: tableRow!.lost.toString(),
                    ),
                    MiniStat(
                      label: context.afriL10n.gameGoalDifferenceShort,
                      value: tableRow!.goalDifference.toString(),
                    ),
                    MiniStat(
                      label: context.afriL10n.gamePointsShort,
                      value: tableRow!.points.toString(),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class TeamContributionRouteBanner extends StatelessWidget {
  const TeamContributionRouteBanner({
    super.key,
    required this.team,
    required this.paymentRoute,
  });

  final TeamCatalogEntry? team;
  final PartnerPaymentRoute paymentRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.all(SpacingTokens.spacing4),
          decoration: BoxDecoration(
            color: ColorTokens.primaryContainer.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
            border: BorderTokens.all(
              color: ColorTokens.primaryContainer.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.afriL10n.gameMomoContributionRoute,
                style: TypographyTokens.labelSmall(ColorTokens.primaryContainer)
                    .copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: TypographyTokens.trackingNone,
                    ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                paymentRoute.payToLabel,
                style:
                    TypographyTokens.titleMedium(
                      ColorTokens.primaryContainer,
                    ).copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: TypographyTokens.trackingNone,
                    ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                paymentRoute.reconciliationLabel.trim().isNotEmpty
                    ? paymentRoute.reconciliationLabel
                    : context.afriL10n.gameUseProviderForClub(
                        paymentRoute.providerLabel,
                        team?.name ?? context.afriL10n.gameThisClub,
                      ),
                style: TypographyTokens.bodySmall(),
              ),
            ],
          ),
        )
        .afriAnimate(context)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.04, end: 0, duration: 400.ms);
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

  int _goldCount = 0;
  int _silverCount = 0;
  int _bronzeCount = 0;
  int _imenaCount = 0;

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
        _message = context.afriL10n.gameSupporterRegistryCurrentClubOnly;
      });
      return;
    }

    try {
      final client = ref.read(supabaseClientProvider);
      final storePolicy = ref.read(storeReleasePolicyProvider);
      if (!storePolicy.allowsCrossUserText) {
        if (!mounted) {
          return;
        }
        setState(() {
          _contributors = const <ClubMemberEntry>[];
          _goldCount = 0;
          _silverCount = 0;
          _bronzeCount = 0;
          _imenaCount = 0;
          _isLoading = false;
          _message = context.afriL10n.gameClubSupporterDataUnavailable;
        });
        return;
      }
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
            .eq('tier', 'gold')
            .count(CountOption.exact),
        client
            .from('fan_memberships')
            .select('id')
            .eq('club_id', clubId)
            .eq('tier', 'silver')
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
            .eq('tier', 'imena')
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
              tier: row['tier']?.toString() ?? 'imena',
              points: (row['points'] as num?)?.toInt() ?? 0,
              isCurrentUser:
                  currentUserId != null && row['user_id'] == currentUserId,
            ),
          )
          .toList(growable: false);

      setState(() {
        _contributors = contributors;
        _goldCount = ((results[1] as dynamic).count as int?) ?? 0;
        _silverCount = ((results[2] as dynamic).count as int?) ?? 0;
        _bronzeCount = ((results[3] as dynamic).count as int?) ?? 0;
        _imenaCount = ((results[4] as dynamic).count as int?) ?? 0;
        _isLoading = false;
        _message = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'TeamProfileTabs',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _message = context.afriL10n.gameClubSupporterDataUnavailable;
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
            title: context.afriL10n.gameMembersUnavailable,
            message: _message!,
          ),
        ),
      );
    }

    return TeamMembersContent(
      goldCount: _goldCount,
      silverCount: _silverCount,
      bronzeCount: _bronzeCount,
      imenaCount: _imenaCount,
      contributors: _contributors,
    );
  }
}

class TeamMembersContent extends StatelessWidget {
  const TeamMembersContent({
    super.key,
    required this.goldCount,
    required this.silverCount,
    required this.bronzeCount,
    required this.imenaCount,
    required this.contributors,
  });

  final int goldCount;
  final int silverCount;
  final int bronzeCount;
  final int imenaCount;
  final List<ClubMemberEntry> contributors;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      physics: const BouncingScrollPhysics(),
      children: [
        Text(
          context.afriL10n.gameClubMembers,
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: TypographyTokens.trackingNone,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: SpacingTokens.spacing3,
          mainAxisSpacing: SpacingTokens.spacing3,
          childAspectRatio: 1.5,
          children: [
            TierCountCard(
              icon: AfriIcons.premium,
              label: context.afriL10n.gameTierGold,
              count: goldCount,
            ),
            TierCountCard(
              icon: AfriIcons.streak,
              label: context.afriL10n.gameTierSilver,
              count: silverCount,
            ),
            TierCountCard(
              icon: AfriIcons.badge,
              label: context.afriL10n.gameTierBronze,
              count: bronzeCount,
            ),
            TierCountCard(
              icon: AfriIcons.fanzone,
              label: context.afriL10n.gameTierImena,
              count: imenaCount,
            ),
          ],
        ),
        if (contributors.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.spacing6),
          Text(
            context.afriL10n.gameTopContributors,
            key: const ValueKey<String>('team-members-contributors-title'),
            style: TypographyTokens.metricLabel(ColorTokens.onSurfaceVariant)
                .copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: TypographyTokens.trackingNone,
                ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          ...contributors
              .take(10)
              .toList()
              .asMap()
              .entries
              .map(
                (entry) => MemberRow(
                  rank: entry.key + 1,
                  fanId: entry.value.displayLabel,
                  tier: fanTierLabel(context.afriL10n, entry.value.tier),
                  fetLabel: context.afriL10n.gamePointBalance(
                    entry.value.points,
                  ),
                  isMe: entry.value.isCurrentUser,
                ),
              ),
        ],
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
      return const SizedBox.shrink();
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
                        const SizedBox(height: SpacingTokens.spacing1 / 2),
                        Text(
                          context.afriL10n.gamePair(
                            fixture.competitionName,
                            kickoffLabel(fixture.kickoffAt),
                          ),
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
                        : context.afriL10n.gameOpenUpper,
                    style: TypographyTokens.titleMedium(
                      fixture.isLive
                          ? ColorTokens.success
                          : ColorTokens.primaryContainer,
                    ).copyWith(fontWeight: FontWeight.w600),
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
    required this.allowsUnreconciledExternalPaymentLaunch,
  });

  final bool isDialing;
  final VoidCallback onDial;
  final PartnerPaymentRoute? paymentRoute;
  final bool isActiveClubTeam;
  final String? clubSupportMessage;
  final bool allowsUnreconciledExternalPaymentLaunch;

  @override
  Widget build(BuildContext context) {
    if (!allowsUnreconciledExternalPaymentLaunch ||
        !isActiveClubTeam ||
        paymentRoute == null) {
      return const SizedBox.shrink(
        key: ValueKey<String>('team-contribute-empty'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      physics: const BouncingScrollPhysics(),
      children: [
        Text(
          context.afriL10n.gameMomoContribution,
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: TypographyTokens.trackingNone,
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
                    : context.afriL10n.gameUseProviderInCountry(
                        paymentRoute!.providerLabel,
                        paymentRoute!.country.name,
                      ),
                style: TypographyTokens.bodyMedium(),
              ),
            ],
          ),
        ),

        const SizedBox(height: SpacingTokens.spacing5),

        AfriSurfaceCard(
          child: Column(
            children: [
              ContributeStep(
                stepNumber: 1,
                title: context.afriL10n.gameEnterAmount,
                description: context.afriL10n.gameEnterAmountDescription(
                  paymentRoute!.providerLabel,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              ContributeStep(
                stepNumber: 2,
                title: context.afriL10n.gameConfirmInDialer,
                description: context.afriL10n.gameConfirmInDialerDescription(
                  paymentRoute!.recipientCode,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              ContributeStep(
                stepNumber: 3,
                title: context.afriL10n.gameReconciliation,
                description: context.afriL10n.gameReconciliationDescription,
              ),
            ],
          ),
        ),

        const SizedBox(height: SpacingTokens.spacing5),

        AfriButton(
              label: isDialing
                  ? context.afriL10n.gameOpeningDialer
                  : context.afriL10n.gameEnterAmountAndDial,
              onTap: onDial,
              isLoading: isDialing,
              enabled: !isDialing,
            )
            .afriAnimate(context)
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
          context.afriL10n.gameAboutTeam(
            team?.name ?? context.afriL10n.gameThisClubUpper,
          ),
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: TypographyTokens.trackingNone,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        AfriSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (team?.city != null)
                TeamInfoRow(context.afriL10n.gameLocation, team!.city!),
              if (team?.countryName != null)
                TeamInfoRow(context.afriL10n.gameCountry, team!.countryName!),
              if (team?.foundedYear != null)
                TeamInfoRow(
                  context.afriL10n.gameFounded,
                  team!.foundedYear.toString(),
                ),
              if (team?.teamType != null)
                TeamInfoRow(context.afriL10n.gameType, team!.teamType!),
              if (team?.sourceClubName != null)
                TeamInfoRow(
                  context.afriL10n.gameAffiliatedClub,
                  team!.sourceClubName!,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
