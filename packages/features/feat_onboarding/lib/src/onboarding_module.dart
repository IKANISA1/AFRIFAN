import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/supporter_phone_auth_screen.dart';

/// Onboarding feature module. Provides non-tab routes for initial user flow.
///
/// Profile setup and saved payment compatibility routes are not part of
/// onboarding. The first-run auth surface is WhatsApp number input followed by
/// OTP verification.
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
    GoRoute(
      path: '/auth/otp',
      builder: (context, state) => const SupporterOtpVerificationScreen(),
    ),
  ];

  @override
  Set<String> get publicPaths => const <String>{
    '/splash',
    '/onboarding',
    '/auth/phone',
    '/auth/otp',
  };
}
