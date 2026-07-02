import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/club_projects_screen.dart';
import 'screens/contributions_hub_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/statement_download_screen.dart';

/// Contributions feature module — admin-managed public initiatives.
/// Accessed via Home quick actions, NOT a bottom nav tab.
class ContributionsModule extends FeatureModule {
  @override
  String get featureKey => 'contributions';

  // Tab route omitted; accessed via Home quick actions.

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/contribute',
      name: 'contribute',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        const ContributionsHubScreen(),
        fullHeight: true,
      ),
      routes: [
        GoRoute(
          path: 'projects',
          pageBuilder: (context, state) => afriSheetPage(
            state,
            const ClubProjectsScreen(),
            fullHeight: true,
          ),
        ),
        GoRoute(
          path: 'groups',
          pageBuilder: (context, state) =>
              afriSheetPage(state, const GroupsScreen(), fullHeight: true),
        ),
        GoRoute(
          path: 'group/:groupId',
          name: 'group-detail',
          pageBuilder: (context, state) => afriSheetPage(
            state,
            GroupDetailScreen(groupId: state.pathParameters['groupId']!),
            fullHeight: true,
          ),
          routes: [
            GoRoute(
              path: 'statement',
              pageBuilder: (context, state) => afriSheetPage(
                state,
                StatementDownloadScreen(
                  groupId: state.pathParameters['groupId']!,
                ),
                fullHeight: true,
              ),
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/contribute',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'merge into Home/Membership',
      targetPath: '/home',
      rationale:
          'Support the club is valuable but should be entered from existing hubs.',
    ),
    RoutePresentationDecision(
      path: '/contribute/projects',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'consolidate',
      targetPath: '/contribute',
      rationale: 'Projects are a section inside contribution.',
    ),
    RoutePresentationDecision(
      path: '/contribute/groups',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'consolidate',
      targetPath: '/contribute',
      rationale: 'Groups are a contribution submode.',
    ),
    RoutePresentationDecision(
      path: '/contribute/group/:groupId',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/contribute/groups',
      rationale: 'Group detail is contextual to groups.',
    ),
    RoutePresentationDecision(
      path: '/contribute/group/:groupId/statement',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/contribute/group/:groupId',
      rationale: 'Statements are utility exports, not browse screens.',
    ),
  ];
}
