import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'screens/membership_screen.dart';
import 'screens/native_membership_journey_screen.dart';
import 'screens/tier_detail_screen.dart';

/// Membership feature module — the supporter identity and revenue tab.
class MembershipModule extends FeatureModule {
  MembershipModule({this.nativeMembershipSelected = false});
  final bool nativeMembershipSelected;
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
    builder: (context, state) => nativeMembershipSelected
        ? NativeMembershipJourneyScreen(
            configuredClubId: state.uri.hasQuery || state.uri.hasFragment
                ? ''
                : ClubConfigScope.of(context).clubId,
          )
        : const MembershipScreen(),
  );

  @override
  Set<String> get independentlyAuthenticatedPaths => {
    '/membership/native',
    if (nativeMembershipSelected) '/membership',
  };

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: 'native',
      name: 'membership-native',
      builder: (context, state) => NativeMembershipJourneyScreen(
        // Noncanonical query-bearing links fail the screen's exact scope check.
        configuredClubId: state.uri.hasQuery || state.uri.hasFragment
            ? ''
            : ClubConfigScope.of(context).clubId,
      ),
    ),
    GoRoute(
      path: 'fans',
      name: 'membership-fans',
      redirect: (_, __) => '/fan-clubs',
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
      path: '/membership/native',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale:
          'Explicit native sign-in, payment review and uncertain recovery for one club.',
    ),
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
      targetPath: '/fan-clubs',
      rationale: 'Fan communities open directly from Membership.',
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
