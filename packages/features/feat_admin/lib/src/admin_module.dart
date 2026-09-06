import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_route_guard.dart';
import 'screens/cms_content_manager_screen.dart';
import 'screens/competition_manager_screen.dart';
import 'screens/contributions_monitor_screen.dart';
import 'screens/feature_detail_screen.dart';
import 'screens/feature_manager_screen.dart';
import 'screens/fixture_settlement_screen.dart';
import 'screens/match_manager_screen.dart';
import 'screens/predict_ops_screen.dart';
import 'screens/push_notifications_screen.dart';
import 'screens/sms_sync_monitor_screen.dart';

class AdminModule extends FeatureModule {
  @override
  String get featureKey => 'admin';

  /// Mobile admin is PWA-owned by default for Rayon/Gikundiro.
  ///
  /// Keep the module available for explicit internal builds, but do not let the
  /// base FeatureModule fallback register it just because the key is absent.
  @override
  bool isEnabled(Map<String, bool> featureFlags) {
    return featureFlags['mobile_admin'] == true ||
        featureFlags['admin'] == true;
  }

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
        GoRoute(
          path: 'settle',
          builder: (context, state) =>
              const AdminRouteGuard(child: FixtureSettlementScreen()),
        ),
        GoRoute(
          path: 'predict',
          builder: (context, state) =>
              const AdminRouteGuard(child: PredictOpsScreen()),
        ),
        GoRoute(
          path: 'competitions',
          builder: (context, state) =>
              const AdminRouteGuard(child: CompetitionManagerScreen()),
        ),
        GoRoute(
          path: 'features',
          builder: (context, state) =>
              const AdminRouteGuard(child: FeatureManagerScreen()),
          routes: [
            GoRoute(
              path: ':featureKey',
              builder: (context, state) => AdminRouteGuard(
                child: FeatureDetailScreen(
                  featureKey: state.pathParameters['featureKey'] ?? '',
                ),
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
      path: '/admin',
      presentation: RoutePresentation.internalOnly,
      recommendation: 'hide from supporter app',
      rationale: 'Mobile admin is PWA-owned by default and opt-in only.',
    ),
    RoutePresentationDecision(
      path: '/admin/cms',
      presentation: RoutePresentation.internalOnly,
      recommendation: 'hide from supporter app',
      rationale: 'CMS management is internal tooling.',
    ),
    RoutePresentationDecision(
      path: '/admin/matches',
      presentation: RoutePresentation.internalOnly,
      recommendation: 'hide from supporter app',
      rationale: 'Match management is internal tooling.',
    ),
    RoutePresentationDecision(
      path: '/admin/contributions',
      presentation: RoutePresentation.internalOnly,
      recommendation: 'hide from supporter app',
      rationale: 'Contribution monitoring is internal tooling.',
    ),
    RoutePresentationDecision(
      path: '/admin/notifications',
      presentation: RoutePresentation.internalOnly,
      recommendation: 'hide from supporter app',
      rationale: 'Push notification composition is internal tooling.',
    ),
    RoutePresentationDecision(
      path: '/admin/sms-monitor',
      presentation: RoutePresentation.internalOnly,
      recommendation: 'hide from supporter app',
      rationale: 'SMS sync monitoring is internal tooling.',
    ),
    RoutePresentationDecision(
      path: '/admin/settle',
      presentation: RoutePresentation.internalOnly,
      recommendation: 'hide from supporter app',
      rationale: 'Fixture settlement is internal tooling.',
    ),
    RoutePresentationDecision(
      path: '/admin/predict',
      presentation: RoutePresentation.internalOnly,
      recommendation: 'hide from supporter app',
      rationale: 'Predict operations are internal tooling.',
    ),
    RoutePresentationDecision(
      path: '/admin/competitions',
      presentation: RoutePresentation.internalOnly,
      recommendation: 'hide from supporter app',
      rationale: 'Competition management is internal tooling.',
    ),
    RoutePresentationDecision(
      path: '/admin/features',
      presentation: RoutePresentation.internalOnly,
      recommendation: 'hide from supporter app',
      rationale: 'Feature management is internal tooling.',
    ),
    RoutePresentationDecision(
      path: '/admin/features/:featureKey',
      presentation: RoutePresentation.internalOnly,
      recommendation: 'hide from supporter app',
      rationale: 'Feature details are internal tooling.',
    ),
  ];
}
