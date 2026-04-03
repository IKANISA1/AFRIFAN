import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/about_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/language_region_screen.dart';
import 'screens/notification_preferences_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/settings_screen.dart';

/// Settings feature module — provides the 3rd or 4th tab based on config.
///
/// Also contributes the standalone /profile_setup route for just-in-time
/// MOMO linking per §2.2 (not part of onboarding, accessible from any feature).
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
      path: 'language',
      builder: (context, state) => const LanguageRegionScreen(),
    ),
    GoRoute(
      path: 'privacy',
      builder: (context, state) => const PrivacySettingsScreen(),
    ),
    GoRoute(path: 'about', builder: (context, state) => const AboutScreen()),
    GoRoute(
      path: 'help',
      builder: (context, state) => const HelpSupportScreen(),
    ),
  ];

  /// §2.2 LOCKED — /profile_setup is the just-in-time MOMO linking screen.
  /// It is NOT part of onboarding. It is reachable from BioPay, Ticketing,
  /// Shop, Contributions, and Settings via context.push('/profile_setup').
  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/profile_setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
  ];
}
