import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/membership_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/tier_detail_screen.dart';

/// Membership feature module — non-tab module with standalone routes.
class MembershipModule extends FeatureModule {
  @override
  String get featureKey => 'membership';

  @override
  TabRoute? get tabRoute => null; // Not a tab — Settings tab is in SettingsModule

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/membership',
      name: 'membership',
      builder: (context, state) => const MembershipScreen(),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/membership/tier/:tierId',
      builder: (context, state) =>
          TierDetailScreen(tierId: state.pathParameters['tierId'] ?? 'bronze'),
    ),
  ];
}
