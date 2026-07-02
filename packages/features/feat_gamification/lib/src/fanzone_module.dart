import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'screens/badges_screen.dart';
import 'screens/club_fan_zone_screen.dart';
import 'screens/fan_id_screen.dart';
import 'screens/fanzone_hub_screen.dart';
import 'screens/fet_wallet_screen.dart';
import 'screens/fixtures_browser_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/league_hub_screen.dart';
import 'screens/league_standings_screen.dart';
import 'screens/match_detail_screen.dart';
import 'screens/my_predictions_screen.dart';
import 'screens/offers_screen.dart';
import 'screens/prediction_detail_screen.dart';
import 'screens/prediction_notifications_screen.dart';
import 'screens/prediction_settlement_screen.dart';
import 'screens/rewards_store_screen.dart';
import 'screens/share_card_generator_screen.dart';
import 'screens/social_hub_screen.dart';
import 'screens/streak_calendar_screen.dart';
import 'screens/team_profile_screen.dart';
import 'screens/token_history_screen.dart';

class FanzoneModule extends FeatureModule {
  @override
  String get featureKey => 'fanzone';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/fanzone',
    label: 'Fan Zone',
    icon: AfriIcons.fanzone,
    activeIcon: AfriIcons.fanzone,
    builder: (context, state) => const FanzoneHubScreen(),
  );

  @override
  bool isEnabled(Map<String, bool> featureFlags) {
    if (featureFlags.containsKey('fanzone')) {
      return featureFlags['fanzone'] ?? true;
    }

    final predictionEnabled = featureFlags['prediction'];
    final gamificationEnabled = featureFlags['gamification'];

    if (predictionEnabled == false && gamificationEnabled == false) {
      return false;
    }

    return true;
  }

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: 'fixtures',
      name: 'fanzone-fixtures',
      pageBuilder: (context, state) {
        final isLive = state.uri.queryParameters['status'] == 'live';
        return afriSheetPage(
          state,
          FixturesBrowserScreen(
            statusFilter: isLive ? 'live' : null,
            title: isLive ? 'LIVE MATCHES' : 'FIXTURES',
          ),
          fullHeight: true,
        );
      },
    ),
    GoRoute(
      path: 'live',
      name: 'fanzone-live',
      redirect: (_, __) => '/fanzone/fixtures?status=live',
    ),
    GoRoute(
      path: 'my',
      name: 'fanzone-my-predictions',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const MyPredictionsScreen(), fullHeight: true),
      routes: [
        GoRoute(
          path: ':predictionId',
          name: 'fanzone-prediction-detail',
          pageBuilder: (context, state) => afriSheetPage(
            state,
            PredictionDetailScreen(
              predictionId: state.pathParameters['predictionId'] ?? '',
            ),
            fullHeight: true,
          ),
          routes: [
            GoRoute(
              path: 'settlement',
              name: 'fanzone-prediction-settlement',
              pageBuilder: (context, state) => afriSheetPage(
                state,
                PredictionSettlementScreen(
                  predictionId: state.pathParameters['predictionId'] ?? '',
                ),
                fullHeight: true,
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: 'match/:fixtureId',
      name: 'fanzone-match-detail',
      pageBuilder: (context, state) => afriRoutePage(
        state,
        MatchDetailScreen(fixtureId: state.pathParameters['fixtureId'] ?? ''),
      ),
    ),
    GoRoute(
      path: 'wallet',
      name: 'fanzone-wallet',
      builder: (context, state) => const FetWalletScreen(),
    ),
    GoRoute(
      path: 'offers',
      name: 'fanzone-offers',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const OffersScreen(), fullHeight: true),
    ),
    GoRoute(
      path: 'rewards',
      name: 'fanzone-rewards-store',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const RewardsStoreScreen(), fullHeight: true),
    ),
    GoRoute(
      path: 'history',
      name: 'fanzone-token-history',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const TokenHistoryScreen(), fullHeight: true),
    ),
    GoRoute(
      path: 'leaderboard',
      name: 'fanzone-leaderboard',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        LeaderboardScreen(initialTab: state.uri.queryParameters['tab']),
        fullHeight: true,
      ),
    ),
    GoRoute(
      path: 'notifications',
      name: 'fanzone-notifications',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        const PredictionNotificationsScreen(),
        fullHeight: true,
      ),
    ),
    GoRoute(
      path: 'badges',
      name: 'fanzone-badges',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const BadgesScreen(), fullHeight: true),
    ),
    GoRoute(
      path: 'streak',
      name: 'fanzone-streak',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const StreakCalendarScreen(), fullHeight: true),
    ),
    GoRoute(
      path: 'share',
      name: 'fanzone-share',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const ShareCardGeneratorScreen()),
    ),
    GoRoute(
      path: 'league',
      name: 'fanzone-league-hub-root',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const LeagueHubScreen(), fullHeight: true),
    ),
    GoRoute(
      path: 'league/:competitionSlug',
      name: 'fanzone-league-hub',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        LeagueHubScreen(
          competitionSlug: state.pathParameters['competitionSlug'],
        ),
        fullHeight: true,
      ),
    ),
    GoRoute(
      path: 'standings/:competitionSlug',
      name: 'fanzone-league-standings',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        LeagueStandingsScreen(
          competitionSlug: state.pathParameters['competitionSlug'] ?? '',
        ),
        fullHeight: true,
      ),
    ),
    GoRoute(
      path: 'team/:teamSlug',
      name: 'fanzone-team-profile',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        TeamProfileScreen(teamSlug: state.pathParameters['teamSlug'] ?? ''),
        fullHeight: true,
      ),
    ),
    GoRoute(
      path: 'club-zone',
      name: 'fanzone-club-zone',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const ClubFanZoneScreen(), fullHeight: true),
    ),
    GoRoute(
      path: 'fan-id',
      name: 'fanzone-fan-id',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const FanIdScreen()),
    ),
    GoRoute(
      path: 'social',
      name: 'fanzone-social',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const SocialHubScreen(), fullHeight: true),
    ),
    GoRoute(
      path: 'privacy',
      name: 'fanzone-privacy',
      redirect: (_, __) => '/settings/privacy',
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/fanzone',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Primary engagement hub and bottom-tab destination.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/match/:fixtureId',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Match Center needs sustained focus for live state and stats.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/wallet',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Wallet combines balance, ledger, rewards, and trust.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/fixtures',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'consolidate',
      targetPath: '/fanzone',
      rationale: 'Fixture browsing belongs to the Fan Zone hub.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/live',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone/fixtures?status=live',
      rationale: 'Live is a fixture filter, not a separate screen.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/my',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'consolidate',
      targetPath: '/fanzone',
      rationale: 'Predictions are a Fan Zone section.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/my/:predictionId',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/fanzone/my',
      rationale: 'Prediction details are contextual to the list.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/my/:predictionId/settlement',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'merge',
      targetPath: '/fanzone/my/:predictionId',
      rationale: 'Settlement is a state inside prediction detail.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/offers',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'merge',
      targetPath: '/fanzone/wallet',
      rationale: 'Offers are part of the wallet/rewards economy.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/rewards',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'merge',
      targetPath: '/fanzone/wallet',
      rationale: 'Rewards should live with wallet value and redemption.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/history',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'merge',
      targetPath: '/fanzone/wallet',
      rationale: 'Token history is wallet ledger content.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/leaderboard',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'consolidate',
      targetPath: '/fanzone',
      rationale: 'Ranking is a hub section, not an app destination.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/notifications',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/fanzone',
      rationale: 'Alerts are transient and should open from a bell/action.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/badges',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'merge',
      targetPath: '/fanzone',
      rationale: 'Badges are achievement content inside the hub/profile.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/streak',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'merge',
      targetPath: '/fanzone',
      rationale: 'Streak is a status/achievement surface.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/share',
      presentation: RoutePresentation.modalSheet,
      recommendation: 'convert to sheet',
      targetPath: '/fanzone',
      rationale: 'Sharing is an action, not a destination.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/league',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'consolidate',
      targetPath: '/fanzone',
      rationale: 'League content supports match context.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/league/:competitionSlug',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'merge',
      targetPath: '/fanzone/league',
      rationale: 'Competition detail is league section depth.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/standings/:competitionSlug',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'consolidate',
      targetPath: '/fanzone/league',
      rationale: 'Standings belong beside fixtures and competitions.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/team/:teamSlug',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'hide from default navigation',
      targetPath: '/fanzone/league',
      rationale: 'Team profile is useful as deep-link context only.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/club-zone',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'merge',
      targetPath: '/fanzone',
      rationale: 'Club Zone overlaps with Fan Zone and Fan Clubs.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/fan-id',
      presentation: RoutePresentation.modalSheet,
      recommendation: 'merge',
      targetPath: '/settings',
      rationale: 'Fan ID is an identity card, not a browse screen.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/social',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'merge',
      targetPath: '/fanzone',
      rationale: 'Social belongs inside Supporters/Fan Zone.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/privacy',
      presentation: RoutePresentation.redirect,
      recommendation: 'delete duplicate',
      targetPath: '/settings/privacy',
      rationale: 'Privacy needs one authoritative settings surface.',
    ),
  ];
}
