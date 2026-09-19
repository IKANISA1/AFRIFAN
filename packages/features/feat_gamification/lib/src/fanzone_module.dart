import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'predict/predict_screen.dart';
import 'screens/match_detail_screen.dart';
import 'screens/prediction_detail_screen.dart';
import 'screens/share_card_generator_screen.dart';

class FanzoneModule extends FeatureModule {
  @override
  String get featureKey => 'fanzone';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/predict',
    label: 'Predict',
    icon: AfriIcons.fanzone,
    activeIcon: AfriIcons.fanzone,
    builder: (context, state) => const PredictScreen(embedded: true),
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
  List<RouteBase> get routes => const [];

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/fanzone',
      redirect: (_, state) =>
          state.uri.path == '/fanzone' ? _legacyHubTarget(state.uri) : null,
      routes: _legacyRoutes,
    ),
    for (final path in [
      '/challenge',
      '/challenge/create',
      '/challenge/my',
      '/challenge/:id',
    ])
      GoRoute(
        path: path,
        redirect: (_, __) =>
            path == '/challenge/my' ? '/predict?section=history' : '/predict',
      ),
  ];

  List<RouteBase> get _legacyRoutes => [
    GoRoute(
      path: 'fixtures',
      name: 'fanzone-fixtures',
      redirect: (_, __) => '/club/fixtures',
    ),
    GoRoute(
      path: 'live',
      name: 'fanzone-live',
      redirect: (_, __) => '/club/fixtures',
    ),
    GoRoute(
      path: 'my',
      name: 'fanzone-my-predictions',
      redirect: (_, __) => '/predict?section=history',
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
      redirect: (_, __) => '/predict?section=wallet',
    ),
    GoRoute(
      path: 'offers',
      name: 'fanzone-offers',
      redirect: (_, __) => '/predict?section=wallet',
    ),
    GoRoute(
      path: 'rewards',
      name: 'fanzone-rewards-store',
      redirect: (_, __) => '/predict?section=wallet',
    ),
    GoRoute(
      path: 'history',
      name: 'fanzone-token-history',
      redirect: (_, __) => '/predict?section=wallet',
    ),
    GoRoute(
      path: 'leaderboard',
      name: 'fanzone-leaderboard',
      redirect: (_, __) => '/club/fixtures',
    ),
    GoRoute(
      path: 'notifications',
      name: 'fanzone-notifications',
      redirect: (_, __) => '/predict?section=history',
    ),
    GoRoute(
      path: 'badges',
      name: 'fanzone-badges',
      redirect: (_, __) => '/predict?section=wallet',
    ),
    GoRoute(
      path: 'streak',
      name: 'fanzone-streak',
      redirect: (_, __) => '/predict?section=wallet',
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
      redirect: (_, __) => '/club/fixtures',
    ),
    GoRoute(
      path: 'league/:competitionSlug',
      name: 'fanzone-league-hub',
      redirect: (_, __) => '/club/fixtures',
    ),
    GoRoute(
      path: 'standings/:competitionSlug',
      name: 'fanzone-league-standings',
      redirect: (_, __) => '/club/fixtures',
    ),
    GoRoute(
      path: 'team/:teamSlug',
      name: 'fanzone-team-profile',
      redirect: (_, __) => '/club/fixtures',
    ),
    GoRoute(
      path: 'club-zone',
      name: 'fanzone-club-zone',
      redirect: (_, __) => '/fan-clubs',
    ),
    GoRoute(
      path: 'fan-id',
      name: 'fanzone-fan-id',
      redirect: (_, __) => '/fan-clubs',
    ),
    GoRoute(
      path: 'social',
      name: 'fanzone-social',
      redirect: (_, __) => '/fan-clubs',
    ),
    GoRoute(
      path: 'privacy',
      name: 'fanzone-privacy',
      redirect: (_, __) => '/settings/privacy',
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => [
    const RoutePresentationDecision(
      path: '/fanzone',
      presentation: RoutePresentation.redirect,
      targetPath: '/predict',
      recommendation: 'consolidate',
      rationale:
          'Fan Zone is a compatibility entry into the single Predict shell.',
    ),
    for (final path in [
      '/challenge',
      '/challenge/create',
      '/challenge/my',
      '/challenge/:id',
    ])
      RoutePresentationDecision(
        path: path,
        presentation: RoutePresentation.redirect,
        targetPath: path == '/challenge/my'
            ? '/predict?section=history'
            : '/predict',
        recommendation: 'consolidate',
        rationale: 'Retired Challenge entry opens the current Predict journey.',
      ),
    const RoutePresentationDecision(
      path: '/predict',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale:
          'One fixture-first Predict destination with picks and FET activity.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/match/:fixtureId',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Match Center needs sustained focus for live state and stats.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/wallet',
      presentation: RoutePresentation.redirect,
      targetPath: '/predict?section=wallet',
      recommendation: 'consolidate',
      rationale:
          'Existing route hosts wallet balance, earning history, and rewards economy.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/fixtures',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/club/fixtures',
      rationale: 'Fixture browsing belongs to the Fan Zone hub.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/live',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/club/fixtures',
      rationale: 'Live is a fixture filter, not a separate screen.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/my',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/predict?section=history',
      rationale: 'Personal prediction history belongs under Predictions.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/my/:predictionId',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/fanzone/my',
      rationale: 'Prediction details are contextual to the list.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/my/:predictionId/settlement',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone/my/:predictionId',
      rationale: 'Settlement is a state inside prediction detail.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/offers',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/predict?section=wallet',
      rationale: 'Offers are part of the points and rewards area.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/rewards',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/predict?section=wallet',
      rationale: 'Rewards should live with points balance and redemption.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/history',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/predict?section=wallet',
      rationale: 'History is wallet activity content.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/leaderboard',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/club/fixtures',
      rationale: 'Ranking is a hub section, not an app destination.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/notifications',
      presentation: RoutePresentation.redirect,
      recommendation: 'convert to sheet',
      targetPath: '/predict?section=history',
      rationale: 'Alerts are transient and should open from a bell/action.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/badges',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/predict?section=wallet',
      rationale: 'Badges are achievement content inside the hub/profile.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/streak',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/predict?section=wallet',
      rationale: 'Streak is a status/achievement surface.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/share',
      presentation: RoutePresentation.modalSheet,
      recommendation: 'convert to sheet',
      targetPath: '/fanzone',
      rationale: 'Sharing is an action, not a destination.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/league',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/club/fixtures',
      rationale: 'League content supports match context.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/league/:competitionSlug',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/club/fixtures',
      rationale: 'Competition detail is league section depth.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/standings/:competitionSlug',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/club/fixtures',
      rationale: 'Standings belong beside fixtures and competitions.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/team/:teamSlug',
      presentation: RoutePresentation.redirect,
      recommendation: 'hide from default navigation',
      targetPath: '/club/fixtures',
      rationale: 'Team profile is useful as deep-link context only.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/club-zone',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fan-clubs',
      rationale: 'Club Zone overlaps with Fan Zone and Fan Clubs.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/fan-id',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fan-clubs',
      rationale: 'Fan ID is an identity card inside Supporters.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/social',
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fan-clubs',
      rationale: 'Social belongs inside supporter groups.',
    ),
    const RoutePresentationDecision(
      path: '/fanzone/privacy',
      presentation: RoutePresentation.redirect,
      recommendation: 'delete duplicate',
      targetPath: '/settings/privacy',
      rationale: 'Privacy needs one authoritative settings surface.',
    ),
  ];
}

/// Old section links preserve their purpose without reviving the five-tab hub.
String _legacyHubTarget(Uri uri) => switch (uri.queryParameters['section']) {
  'wallet' || 'points' || 'pay' || 'rewards' => '/predict?section=wallet',
  'history' || 'my' => '/predict?section=history',
  'league' => '/club/fixtures',
  'supporters' || 'activity' => '/fan-clubs',
  _ => '/predict',
};
