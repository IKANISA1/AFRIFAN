import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'screens/membership_screen.dart';
import 'screens/tier_detail_screen.dart';

/// Membership feature module — the supporter identity and revenue tab.
class MembershipModule extends FeatureModule {
  static const String _moduleName = 'Membership';

  @override
  String get featureKey => 'membership';

  @override
  bool isEnabled(Map<String, bool> featureFlags) => true;

  @override
  bool isEnabledForConfig({
    Map<String, bool> featureFlags = const <String, bool>{},
    Map<String, dynamic>? configSnapshot,
  }) => true;

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/membership',
    label: _moduleName,
    icon: AfriIcons.membership,
    activeIcon: AfriIcons.membership,
    builder: (context, state) => const MembershipScreen(),
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: 'fans',
      name: 'membership-fans',
      redirect: (_, __) => '/fanzone?section=supporters',
    ),
    GoRoute(
      path: 'tier/:tierId',
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
      presentation: RoutePresentation.redirect,
      recommendation: 'merge',
      targetPath: '/fanzone?section=supporters',
      rationale: 'Fan registry is community depth inside Fan Zone Supporters.',
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
