import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/challenge_detail_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/create_challenge_screen.dart';
import 'screens/my_challenges_screen.dart';

/// Challenge feature module — stake-based prediction pools.
class ChallengeModule extends FeatureModule {
  @override
  String get featureKey => 'challenge';

  @override
  bool isEnabled(Map<String, bool> featureFlags) {
    return featureFlags[featureKey] == true;
  }

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/challenge',
      builder: (context, state) => const ChallengesScreen(),
    ),
    GoRoute(
      path: '/challenge/create',
      builder: (context, state) => const CreateChallengeScreen(),
    ),
    GoRoute(
      path: '/challenge/my',
      builder: (context, state) => const MyChallengesScreen(),
    ),
    GoRoute(
      path: '/challenge/:id',
      pageBuilder: (context, state) => afriRoutePage(
        state,
        ChallengeDetailScreen(id: state.pathParameters['id'] ?? ''),
      ),
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/challenge',
      presentation: RoutePresentation.deepLinkOnly,
      recommendation: 'hide from launch',
      rationale: 'Challenge is opt-in and outside the default supporter app.',
    ),
    RoutePresentationDecision(
      path: '/challenge/create',
      presentation: RoutePresentation.deepLinkOnly,
      recommendation: 'hide from launch',
      rationale: 'Challenge creation requires the challenge feature flag.',
    ),
    RoutePresentationDecision(
      path: '/challenge/my',
      presentation: RoutePresentation.deepLinkOnly,
      recommendation: 'hide from launch',
      rationale: 'Challenge history is not part of the minimal launch surface.',
    ),
    RoutePresentationDecision(
      path: '/challenge/:id',
      presentation: RoutePresentation.deepLinkOnly,
      recommendation: 'hide from launch',
      rationale: 'Challenge details stay behind explicit feature enablement.',
    ),
  ];
}
