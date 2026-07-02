import 'package:core_router/core_router.dart';
import 'package:go_router/go_router.dart';

import 'screens/onboarding_screen.dart';
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
    GoRoute(path: '/splash', redirect: (_, state) => _splashRedirect(state)),
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

  @override
  List<RoutePresentationDecision> get routePresentationDecisions => const [
    RoutePresentationDecision(
      path: '/splash',
      presentation: RoutePresentation.deepLinkOnly,
      recommendation: 'delete as visible screen',
      targetPath: '/home',
      rationale: 'Startup should use native launch plus auth/loading state.',
    ),
    RoutePresentationDecision(
      path: '/onboarding',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep but compress',
      rationale: 'First-run identity context is useful when concise.',
    ),
    RoutePresentationDecision(
      path: '/auth/phone',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'Phone entry is a focused credential step.',
    ),
    RoutePresentationDecision(
      path: '/auth/otp',
      presentation: RoutePresentation.fullScreen,
      recommendation: 'keep',
      rationale: 'OTP verification needs focused validation and resend state.',
    ),
  ];
}

String _splashRedirect(GoRouterState state) {
  final raw = state.uri.queryParameters['from']?.trim();
  final uri = raw == null || raw.isEmpty ? null : Uri.tryParse(raw);
  final path = uri?.path;
  if (path == null ||
      path.isEmpty ||
      !path.startsWith('/') ||
      path == '/splash' ||
      path == '/onboarding') {
    return '/onboarding';
  }

  return Uri(
    path: '/onboarding',
    queryParameters: <String, String>{'from': uri.toString()},
  ).toString();
}
