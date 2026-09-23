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
      pageBuilder: (context, state) => afriSheetPage(
        state,
        const ContributionsHubScreen(),
        fullHeight: true,
      ),
      routes: [
        GoRoute(
          path: 'projects',
          redirect: (_, __) => '/contribute?type=project',
        ),
        GoRoute(
          path: 'groups',
          redirect: (_, __) => '/contribute?type=community',
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
      recommendation: 'keep',
      rationale:
          'Club initiatives open directly without a competing primary tab.',
    ),
    RoutePresentationDecision(
      path: '/contribute/projects',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/contribute?type=project',
      rationale: 'Projects are a section inside contribution.',
    ),
    RoutePresentationDecision(
      path: '/contribute/groups',
      presentation: RoutePresentation.redirect,
      recommendation: 'consolidate',
      targetPath: '/contribute?type=community',
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
