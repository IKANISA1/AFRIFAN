import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/create_fan_club_screen.dart';
import 'screens/fan_club_detail_screen.dart';
import 'screens/fan_clubs_list_screen.dart';

class FanClubsModule extends FeatureModule {
  @override
  String get featureKey => 'fan_clubs';

  @override
  TabRoute? get tabRoute => null;

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/fan-clubs',
      builder: (context, state) => const FanClubsListScreen(),
      routes: [
        GoRoute(
          path: 'create',
          builder: (context, state) => const CreateFanClubScreen(),
        ),
        GoRoute(
          path: ':clubId',
          builder: (context, state) => FanClubDetailScreen(
            clubId: state.pathParameters['clubId'] ?? 'kigali-blue-army',
          ),
        ),
      ],
    ),
  ];
}
