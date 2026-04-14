import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/club_projects_screen.dart';
import 'screens/contributions_hub_screen.dart';
import 'screens/create_group_screen.dart';
import 'screens/group_chat_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/group_settings_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/join_group_screen.dart';
import 'screens/statement_download_screen.dart';

/// Contributions feature module — group contributions.
/// Accessed via Home quick actions, NOT a bottom nav tab.
class ContributionsModule extends FeatureModule {
  @override
  String get featureKey => 'contributions';

  // No tabRoute — accessed via Home quick actions

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/contribute',
      name: 'contribute',
      builder: (context, state) => const ContributionsHubScreen(),
      routes: [
        GoRoute(
          path: 'projects',
          builder: (context, state) => const ClubProjectsScreen(),
        ),
        GoRoute(
          path: 'groups',
          builder: (context, state) => const GroupsScreen(),
        ),
        GoRoute(
          path: 'create',
          builder: (context, state) => const CreateGroupScreen(),
        ),
        GoRoute(
          path: 'join',
          builder: (context, state) =>
              JoinGroupScreen(initialCode: state.uri.queryParameters['code']),
        ),
        GoRoute(
          path: 'group/:groupId',
          name: 'group-detail',
          builder: (context, state) =>
              GroupDetailScreen(groupId: state.pathParameters['groupId']!),
          routes: [
            GoRoute(
              path: 'chat',
              builder: (context, state) =>
                  GroupChatScreen(groupId: state.pathParameters['groupId']!),
            ),
            GoRoute(
              path: 'settings',
              builder: (context, state) => GroupSettingsScreen(
                groupId: state.pathParameters['groupId']!,
              ),
            ),
            GoRoute(
              path: 'statement',
              builder: (context, state) => StatementDownloadScreen(
                groupId: state.pathParameters['groupId']!,
              ),
            ),
          ],
        ),
      ],
    ),
  ];
}
