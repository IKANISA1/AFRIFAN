import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';

/// Onboarding feature module. Provides non-tab routes for initial user flow.
///
/// §2.2 LOCKED — /profile_setup is NOT part of onboarding. MOMO linking
/// lives in Settings → Account → MOMO Number. The /profile_setup route
/// is registered via SettingsModule.standaloneRoutes.
class OnboardingModule extends FeatureModule {
  @override
  String get featureKey => 'onboarding';

  @override
  TabRoute? get tabRoute => null; // Not a tab

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
  ];
}
