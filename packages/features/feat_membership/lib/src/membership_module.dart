import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/fan_registry_screen.dart';
import 'screens/membership_screen.dart';
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
      path: '/membership/fans',
      name: 'membership-fans',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const FanRegistryScreen(), fullHeight: true),
    ),
    GoRoute(
      path: '/membership/tier/:tierId',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        TierDetailScreen(tierId: state.pathParameters['tierId'] ?? 'imena'),
        fullHeight: true,
      ),
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/membership',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Membership is a core identity and revenue surface.',
    ),
    RoutePresentationDecision(
      path: '/membership/fans',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'merge',
      targetPath: '/membership',
      rationale:
          'Fan registry is community depth inside membership/supporters.',
    ),
    RoutePresentationDecision(
      path: '/membership/tier/:tierId',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/membership',
      rationale: 'Tier benefits are comparison content from plan cards.',
    ),
  ];
}
