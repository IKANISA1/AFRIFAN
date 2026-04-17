import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/supporter_phone_auth_screen.dart';

/// Onboarding feature module. Provides non-tab routes for initial user flow.
///
/// /profile_setup is NOT part of onboarding. Saved payment routes belong only
/// to Face ID enrollment, and the compatibility route is registered via
/// SettingsModule.standaloneRoutes.
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
    GoRoute(
      path: '/auth/phone',
      builder: (context, state) => const SupporterPhoneAuthScreen(),
    ),
  ];

  @override
  Set<String> get publicPaths => const <String>{
    '/splash',
    '/onboarding',
    '/auth/phone',
  };
}
