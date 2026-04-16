import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'screens/challenge_detail_screen.dart';
import 'screens/challenge_feed_screen.dart';
import 'screens/create_challenge_screen.dart';

/// Challenge feature module — stake-based prediction pools.
class ChallengeModule extends FeatureModule {
  @override
  String get featureKey => 'challenge';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/challenge',
    label: 'CHALLENGE',
    icon: AfriIcons.versus,
    activeIcon: AfriIcons.versus,
    builder: (context, state) => const ChallengeFeedScreen(),
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/challenge/create',
      builder: (context, state) => const CreateChallengeScreen(),
    ),
    GoRoute(
      path: '/challenge/:id',
      builder: (context, state) => ChallengeDetailScreen(
        id: state.pathParameters['id'] ?? '',
      ),
    ),
  ];
}
