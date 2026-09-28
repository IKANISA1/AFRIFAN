import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/club_content_providers.dart';
import '../widgets/club_crest.dart';
import 'club_content_state_widgets.dart';

class ClubHubScreen extends ConsumerWidget {
  const ClubHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final config = ClubConfigScope.maybeOf(context) ?? ClubConfig.fallback();
    final overview = ref.watch(clubOverviewProvider);
    final overviewValue = overview.valueOrNull;
    final matches = ref.watch(clubMatchesProvider).valueOrNull;
    final currentMatch =
        matches
            ?.where(
              (m) =>
                  !m.isCompleted &&
                  (m.matchDate
                          ?.add(const Duration(days: 1))
                          .isAfter(DateTime.now()) ??
                      false),
            )
            .firstOrNull ??
        matches?.firstOrNull;
    final clubName = overviewValue?.name.trim().isNotEmpty == true
        ? overviewValue!.name
        : config.clubName;
    final identityLine = <String>[
      if (overviewValue?.league.trim().isNotEmpty == true)
        overviewValue!.league,
      if (overviewValue?.country.trim().isNotEmpty == true)
        overviewValue!.country
      else
        config.country,
    ].join(' • ');

    return AfriScreenScaffold(
      showAppBar: false,
      bottomNavigationAware: true,
      bodyWrapper: (child) => GradientBackground(
        routePath: '/club',
        child: SafeArea(bottom: false, child: child),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: ConnectivityService.onlineNotifier,
        builder: (context, isOnline, _) {
          final failure = overview.hasError
              ? ClubContentFailure.fromError(
                  overview.error!,
                  isOnline: isOnline,
                )
              : !isOnline
              ? const ClubContentFailure(ClubContentFailureKind.offline)
              : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: AfriTopCommandBar(
                  searchHint: l10n.homeSearchHint,
                  avatarIcon: AfriIcons.profile,
                  onSearchTap: () => context.push('/search'),
                  onAvatarTap: () => context.go('/settings'),
                  actions: [
                    AfriTopCommandAction(
                      key: const ValueKey<String>('club-refresh-action'),
                      icon: AfriIcons.refresh,
                      label: l10n.clubRefresh,
                      onTap: () {
                        ref.invalidate(clubOverviewProvider);
                        ref.invalidate(clubMatchesProvider);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Center(
                child: Semantics(
                  label: l10n.clubOfficialOverviewSemantic(clubName),
                  child: Column(
                    children: [
                      ClubCrest(
                        clubSlug: overviewValue?.slug ?? config.clubId,
                        clubName: clubName,
                        imageUrl: overviewValue?.logoUrl,
                        size: 56,
                      ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      Text(
                        clubName == 'AFRICLUB'
                            ? clubName
                            : teamInitials(clubName),
                        textAlign: TextAlign.center,
                        style: TypographyTokens.headlineLarge().copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (overviewValue?.nickname.trim().isNotEmpty ==
                          true) ...[
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          overviewValue!.nickname,
                          textAlign: TextAlign.center,
                          style: TypographyTokens.bodyLarge(),
                        ),
                      ],
                      if (identityLine.isNotEmpty) ...[
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          identityLine,
                          textAlign: TextAlign.center,
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              if (overview.isLoading || failure != null) ...[
                const SizedBox(height: SpacingTokens.spacing4),
                if (failure == null)
                  const ClubContentStatusBanner(refreshing: true, failure: null)
                else if (failure.kind == ClubContentFailureKind.unknown)
                  AfriStateView.offline(
                    compact: true,
                    title: l10n.clubLiveIdentityUnavailable,
                    message: l10n.clubIdentityFallbackMessage,
                    actionLabel: l10n.retry,
                    onAction: () => ref.invalidate(clubOverviewProvider),
                  )
                else
                  ClubContentFailureView(
                    compact: true,
                    failure: failure,
                    onRetry:
                        failure.kind == ClubContentFailureKind.permissionDenied
                        ? null
                        : () => ref.invalidate(clubOverviewProvider),
                  ),
              ],
              const SizedBox(height: SpacingTokens.sectionGap),
              if (currentMatch != null) ...[
                AfriListGroup(
                  children: [
                    AfriFixtureCard(
                      lightSurface: true,
                      homeTeam: currentMatch.homeTeam,
                      imageUrl: currentMatch.imageUrl,
                      imageRightsApproved: currentMatch.imageUrl != null,
                      imageProvenanceId: 'published-fixture:${currentMatch.id}',
                      awayTeam: currentMatch.awayTeam,
                      score: currentMatch.isCompleted
                          ? '${currentMatch.homeScore}–${currentMatch.awayScore}'
                          : null,
                      subtitle: currentMatch.isCompleted
                          ? '${l10n.clubFootballRecent} · ${currentMatch.homeScore}–${currentMatch.awayScore}'
                          : '${l10n.clubFootballUpcoming} · ${currentMatch.matchDate?.toIso8601String().split('T').first ?? ''} ${currentMatch.kickoffTime}',
                      onTap: () =>
                          context.push('/club/fixtures/${currentMatch.id}'),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.sectionGap),
              ],
              Text(
                l10n.clubExploreTitle,
                style: TypographyTokens.titleLarge().copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriListGroup(
                children: [
                  _ClubDestination(
                    icon: AfriIcons.people,
                    title: l10n.clubTeamTitle,
                    subtitle: l10n.clubTeamSubtitle,
                    route: '/club/team',
                  ),
                  _ClubDestination(
                    icon: AfriIcons.article,
                    title: l10n.clubNewsTitle,
                    subtitle: l10n.clubNewsSubtitle,
                    route: '/club/news',
                  ),
                  _ClubDestination(
                    icon: AfriIcons.fixture,
                    title: l10n.clubFixturesTitle,
                    subtitle: l10n.clubFixturesSubtitle,
                    route: '/club/fixtures',
                  ),
                  _ClubDestination(
                    icon: AfriIcons.score,
                    title: l10n.clubResultsTitle,
                    subtitle: l10n.clubResultsSubtitle,
                    route: '/club/results',
                  ),
                  _ClubDestination(
                    icon: AfriIcons.league,
                    title: l10n.clubStandingsTitle,
                    subtitle: l10n.clubStandingsSubtitle,
                    route: '/club/standings',
                  ),
                  if (overviewValue?.hasProfile != true)
                    _ClubDestination(
                      icon: AfriIcons.history,
                      title: l10n.clubHistoryTitle,
                      subtitle: l10n.clubHistorySubtitle,
                      route: '/club/history',
                    ),
                  _ClubDestination(
                    icon: AfriIcons.business,
                    title: l10n.clubPartnersTitle,
                    subtitle: l10n.clubPartnersIntro,
                    route: '/club/partners',
                  ),
                  _ClubDestination(
                    icon: AfriIcons.business,
                    title: l10n.clubProjectsTitle,
                    subtitle: l10n.clubProjectsSubtitle,
                    route: '/club/projects',
                  ),
                  _ClubDestination(
                    icon: AfriIcons.tickets,
                    title: l10n.clubTicketsTitle,
                    subtitle: l10n.clubTicketsSubtitle,
                    route: '/tickets',
                  ),
                  _ClubDestination(
                    icon: AfriIcons.shop,
                    title: l10n.clubShopTitle,
                    subtitle: l10n.clubShopSubtitle,
                    route: '/shop',
                  ),
                ],
              ),
              if (overviewValue != null && overviewValue.hasProfile) ...[
                const SizedBox(height: SpacingTokens.sectionGap),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.clubAboutTitle,
                    style: TypographyTokens.titleLarge(),
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriSectionCard(
                  title: overviewValue.fullName.isEmpty
                      ? clubName
                      : overviewValue.fullName,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final fact in [
                        (l10n.clubOriginLabel, overviewValue.origin),
                        (l10n.clubBaseLabel, overviewValue.currentBase),
                        (l10n.clubColoursLabel, overviewValue.colours),
                      ])
                        if (fact.$2.isNotEmpty) ...[
                          const SizedBox(height: SpacingTokens.spacing4),
                          Text(
                            fact.$1,
                            style: TypographyTokens.bodySmall(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing1),
                          Text(fact.$2, style: TypographyTokens.bodyLarge()),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriListGroup(
                  children: [
                    _ClubDestination(
                      icon: AfriIcons.history,
                      title: l10n.clubHistoryTitle,
                      subtitle: l10n.clubRootsSubtitle,
                      route: '/club/history',
                    ),
                  ],
                ),
                if (overviewValue.identityNote.isNotEmpty) ...[
                  const SizedBox(height: SpacingTokens.spacing5),
                  Text(
                    overviewValue.identityNote,
                    style: TypographyTokens.bodyMedium(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: SpacingTokens.spacing5),
                AfriButton(
                  label: l10n.clubMembershipAction,
                  onTap: () => context.push('/membership'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ClubDestination extends StatelessWidget {
  const _ClubDestination({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return AfriListRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => context.push(route),
    );
  }
}
