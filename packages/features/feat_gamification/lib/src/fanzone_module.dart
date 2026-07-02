import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'screens/fanzone_hub_screen.dart';
import 'screens/fet_wallet_screen.dart';
import 'screens/game_session_controller_screen.dart';
import 'screens/game_session_join_screen.dart';
import 'screens/match_detail_screen.dart';
import 'screens/prediction_detail_screen.dart';
import 'screens/share_card_generator_screen.dart';

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
      redirect: (_, __) => '/fanzone?section=league',
    ),
    GoRoute(
      path: 'live',
      name: 'fanzone-live',
      redirect: (_, __) => '/fanzone?section=league',
    ),
    GoRoute(
      path: 'my',
      name: 'fanzone-my-predictions',
      redirect: (_, __) => '/fanzone?section=predictions',
    ),
    GoRoute(
      path: 'my/:predictionId',
      name: 'fanzone-prediction-detail',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        PredictionDetailScreen(
          predictionId: state.pathParameters['predictionId'] ?? '',
        ),
        fullHeight: true,
      ),
    ),
    GoRoute(
      path: 'my/:predictionId/settlement',
      name: 'fanzone-prediction-settlement',
      redirect: (_, state) {
        final predictionId = state.pathParameters['predictionId'] ?? '';
        return '/fanzone/my/$predictionId';
      },
    ),
    GoRoute(
      path: 'game',
      name: 'fanzone-game-session-entry',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const GameSessionJoinScreen(), fullHeight: true),
    ),
    GoRoute(
      path: 'game/:sessionId',
      name: 'fanzone-game-session-controller',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        GameSessionControllerScreen(
          sessionId: state.pathParameters['sessionId'] ?? '',
          sessionPlayerId:
              state.uri.queryParameters['session_player_id'] ??
              state.uri.queryParameters['sessionPlayerId'] ??
              state.uri.queryParameters['playerId'],
        ),
        fullHeight: true,
      ),
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
      redirect: (_, __) => '/fanzone?section=rewards',
    ),
    GoRoute(
      path: 'rewards',
      name: 'fanzone-rewards-store',
      redirect: (_, __) => '/fanzone?section=rewards',
    ),
    GoRoute(
      path: 'history',
      name: 'fanzone-token-history',
      redirect: (_, __) => '/fanzone?section=wallet',
    ),
    GoRoute(
      path: 'leaderboard',
      name: 'fanzone-leaderboard',
      redirect: (_, __) => '/fanzone?section=league',
    ),
    GoRoute(
      path: 'notifications',
      name: 'fanzone-notifications',
      redirect: (_, __) => '/fanzone?section=predictions',
    ),
    GoRoute(
      path: 'badges',
      name: 'fanzone-badges',
      redirect: (_, __) => '/fanzone?section=rewards',
    ),
    GoRoute(
      path: 'streak',
      name: 'fanzone-streak',
      redirect: (_, __) => '/fanzone?section=rewards',
    ),
    GoRoute(
      path: 'share',
      name: 'fanzone-share',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        const ShareCardGeneratorScreen(),
        heightFactor: 0.68,
      ),
    ),
    GoRoute(
      path: 'league',
      name: 'fanzone-league-hub-root',
      redirect: (_, __) => '/fanzone?section=league',
    ),
    GoRoute(
      path: 'league/:competitionSlug',
      name: 'fanzone-league-hub',
      redirect: (_, __) => '/fanzone?section=league',
    ),
    GoRoute(
      path: 'standings/:competitionSlug',
      name: 'fanzone-league-standings',
      redirect: (_, __) => '/fanzone?section=league',
    ),
    GoRoute(
      path: 'team/:teamSlug',
      name: 'fanzone-team-profile',
      redirect: (_, __) => '/fanzone?section=league',
    ),
    GoRoute(
      path: 'club-zone',
      name: 'fanzone-club-zone',
      redirect: (_, __) => '/fanzone?section=supporters',
    ),
    GoRoute(
      path: 'fan-id',
      name: 'fanzone-fan-id',
      redirect: (_, __) => '/fanzone?section=supporters',
    ),
    GoRoute(
      path: 'social',
      name: 'fanzone-social',
      redirect: (_, __) => '/fanzone?section=supporters',
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
      path: '/fanzone/game',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/fanzone',
      rationale:
          'TV-led game code entry is contextual to Fan Zone and should not increase the primary screen count.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/game/:sessionId',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/fanzone',
      rationale:
          'Mobile controller opens from TV pairing/deep links but remains a Fan Zone modal task.',
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
      rationale:
          'Existing route hosts wallet balance, earning history, and rewards economy.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/fixtures',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/fanzone',
      rationale: 'Fixture browsing belongs to the Fan Zone hub.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/live',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone?section=league',
      rationale: 'Live is a fixture filter, not a separate screen.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/my',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/fanzone?section=predictions',
      rationale: 'Personal prediction history belongs under Predictions.',
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
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone/my/:predictionId',
      rationale: 'Settlement is a state inside prediction detail.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/offers',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone?section=rewards',
      rationale: 'Offers are part of the points and rewards area.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/rewards',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone?section=rewards',
      rationale: 'Rewards should live with points balance and redemption.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/history',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone?section=wallet',
      rationale: 'History is wallet activity content.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/leaderboard',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/fanzone?section=league',
      rationale: 'Ranking is a hub section, not an app destination.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/notifications',
      presentation: RoutePresentation.redirect,
      recommendation: 'convert to sheet',
      targetPath: '/fanzone?section=predictions',
      rationale: 'Alerts are transient and should open from a bell/action.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/badges',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone?section=rewards',
      rationale: 'Badges are achievement content inside the hub/profile.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/streak',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone?section=rewards',
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
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/fanzone?section=league',
      rationale: 'League content supports match context.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/league/:competitionSlug',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone?section=league',
      rationale: 'Competition detail is league section depth.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/standings/:competitionSlug',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/fanzone?section=league',
      rationale: 'Standings belong beside fixtures and competitions.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/team/:teamSlug',
      presentation: RoutePresentation.redirect,
      recommendation: 'hide from default navigation',
      targetPath: '/fanzone?section=league',
      rationale: 'Team profile is useful as deep-link context only.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/club-zone',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone?section=supporters',
      rationale: 'Club Zone overlaps with Fan Zone and Fan Clubs.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/fan-id',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone?section=supporters',
      rationale: 'Fan ID is an identity card inside Supporters.',
    ),
    RoutePresentationDecision(
      path: '/fanzone/social',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone?section=supporters',
      rationale: 'Social belongs inside supporter groups.',
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
