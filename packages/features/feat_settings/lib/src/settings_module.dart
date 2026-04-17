import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:go_router/go_router.dart';

import 'screens/edit_profile_screen.dart';
import 'screens/notification_preferences_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/settings_screen.dart';

/// Settings feature module — the fixed third bottom-nav tab.
///
/// Also contributes the standalone /profile_setup compatibility route so old
/// links can redirect users into the updated contribution guidance flow.
class SettingsModule extends FeatureModule {
  @override
  String get featureKey => 'settings';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/settings',
    label: 'Settings',
    icon: AfriIcons.settings,
    activeIcon: AfriIcons.settings,
    builder: (context, state) => const SettingsScreen(),
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: 'edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: 'notifications',
      builder: (context, state) => const NotificationPreferencesScreen(),
    ),
    GoRoute(
      path: 'privacy',
      builder: (context, state) => const PrivacySettingsScreen(),
    ),
  ];

  /// Legacy compatibility route for older app links.
  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/profile_setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
  ];
}
