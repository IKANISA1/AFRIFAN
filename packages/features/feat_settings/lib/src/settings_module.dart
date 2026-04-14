import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/edit_profile_screen.dart';
import 'screens/notification_preferences_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/settings_screen.dart';

/// Settings feature module — provides the 3rd or 4th tab based on config.
///
/// Also contributes the standalone /profile_setup compatibility route so old
/// deep links can redirect users into Face ID route setup.
class SettingsModule extends FeatureModule {
  @override
  String get featureKey => 'settings';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/settings',
    label: 'SETTINGS',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
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

  /// Legacy compatibility route.
  ///
  /// This route is NOT a general-purpose MoMo linking step and must never be
  /// used as a hard gate for shop, ticketing, membership, or contribution
  /// flows. It only explains that saved payment routes now belong to Face ID
  /// enrollment.
  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/profile_setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
  ];
}
