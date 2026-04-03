import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_route_guard.dart';
import 'screens/cms_content_manager_screen.dart';
import 'screens/contributions_monitor_screen.dart';
import 'screens/match_manager_screen.dart';
import 'screens/push_notifications_screen.dart';
import 'screens/sms_sync_monitor_screen.dart';

class AdminModule extends FeatureModule {
  @override
  String get featureKey => 'admin';

  @override
  TabRoute? get tabRoute => null;

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/admin',
      builder: (context, state) =>
          const AdminRouteGuard(child: AdminDashboardScreen()),
      routes: [
        GoRoute(
          path: 'cms',
          builder: (context, state) =>
              const AdminRouteGuard(child: CmsContentManagerScreen()),
        ),
        GoRoute(
          path: 'matches',
          builder: (context, state) =>
              const AdminRouteGuard(child: MatchManagerScreen()),
        ),
        GoRoute(
          path: 'contributions',
          builder: (context, state) =>
              const AdminRouteGuard(child: ContributionsMonitorScreen()),
        ),
        GoRoute(
          path: 'notifications',
          builder: (context, state) =>
              const AdminRouteGuard(child: PushNotificationsScreen()),
        ),
        GoRoute(
          path: 'sms-monitor',
          builder: (context, state) =>
              const AdminRouteGuard(child: SmsSyncMonitorScreen()),
        ),
      ],
    ),
  ];
}
