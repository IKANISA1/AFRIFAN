import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/contributions_hub_screen.dart';
import 'screens/group_detail_screen.dart';
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
      redirect: (_, state) {
        final path = state.uri.path;
        if (path == '/contribute' ||
            path == '/contribute/projects' ||
            path == '/contribute/groups') {
          return '/fanzone?section=supporters';
        }
        return null;
      },
      pageBuilder: (context, state) => afriSheetPage(
        state,
        const ContributionsHubScreen(),
        fullHeight: true,
      ),
      routes: [
        GoRoute(
          path: 'projects',
          redirect: (_, __) => '/fanzone?section=supporters',
        ),
        GoRoute(
          path: 'groups',
          redirect: (_, __) => '/fanzone?section=supporters',
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
      presentation: RoutePresentation.redirect,
      recommendation: 'merge into Home/Membership',
      targetPath: '/fanzone?section=supporters',
      rationale:
          'Support the club is valuable but belongs inside Fan Zone Supporters.',
    ),
    RoutePresentationDecision(
      path: '/contribute/projects',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/fanzone?section=supporters',
      rationale: 'Projects are a section inside contribution.',
    ),
    RoutePresentationDecision(
      path: '/contribute/groups',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/fanzone?section=supporters',
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
