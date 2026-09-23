import 'package:core_l10n/core_l10n.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'screens/edit_profile_screen.dart';
import 'screens/notification_preferences_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/settings_screen.dart';

/// Settings feature module — the fixed third bottom-nav tab.
class SettingsModule extends FeatureModule {
  @override
  String get featureKey => 'settings';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/settings',
    label: lookupAfriLocalizations(const Locale('en')).settingsTitle,
    icon: AfriIcons.settings,
    activeIcon: AfriIcons.settings,
    builder: (context, state) => const SettingsScreen(),
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: 'edit-profile',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const EditProfileScreen(), fullHeight: true),
    ),
    GoRoute(
      path: 'notifications',
      pageBuilder: (context, state) => afriSheetPage(
        state,
        const NotificationPreferencesScreen(),
        fullHeight: true,
      ),
    ),
    GoRoute(
      path: 'privacy',
      pageBuilder: (context, state) =>
          afriSheetPage(state, const PrivacySettingsScreen(), fullHeight: true),
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => const <RouteBase>[];

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/settings',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Settings is the account and app control hub.',
    ),
    RoutePresentationDecision(
      path: '/settings/edit-profile',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/settings',
      rationale: 'Profile edits are short contextual tasks.',
    ),
    RoutePresentationDecision(
      path: '/settings/notifications',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'convert to sheet',
      targetPath: '/settings',
      rationale: 'Notification preferences are grouped toggles.',
    ),
    RoutePresentationDecision(
      path: '/settings/privacy',
      presentation: RoutePresentation.fullHeightSheet,
      recommendation: 'keep as single privacy authority',
      targetPath: '/settings',
      rationale: 'Privacy belongs in one trusted Settings location.',
    ),
  ];
}
