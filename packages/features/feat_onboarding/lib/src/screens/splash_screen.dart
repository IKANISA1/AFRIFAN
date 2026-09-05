import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    unawaited(_navigateToNext());
  }

  Future<void> _navigateToNext() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _hasNavigated) return;

    final authNotifier = ref.read(authStateProvider.notifier);
    final currentState = ref.read(authStateProvider);

    // Try restoring existing session first — timeout after 10s to avoid
    // hanging on splash with a slow or unreachable backend.
    if (currentState is AuthInitial) {
      try {
        await authNotifier.restore().timeout(const Duration(seconds: 15));
      } catch (error, stackTrace) {
        AfriLogger.warn(
          'SplashScreen',
          'Operation failed (non-critical).',
          error,
          stackTrace,
        );
        // Timeout or restore failure — proceed to navigation logic below
      }
    }

    if (!mounted || _hasNavigated) return;

    final resolvedState = ref.read(authStateProvider);
    final deferredLocation = _deferredLocation();

    if (resolvedState is AuthAuthenticated) {
      _hasNavigated = true;
      context.go(deferredLocation ?? '/home');
      return;
    }

    _hasNavigated = true;
    if (deferredLocation == null) {
      context.go('/onboarding');
      return;
    }
    context.go(
      Uri(
        path: '/onboarding',
        queryParameters: <String, String>{'from': deferredLocation},
      ).toString(),
    );
  }

  String? _deferredLocation() {
    final raw = GoRouterState.of(context).uri.queryParameters['from']?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(raw);
    final path = uri?.path;
    if (path == null ||
        path.isEmpty ||
        !path.startsWith('/') ||
        path == '/splash' ||
        path == '/onboarding') {
      return null;
    }

    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion =
        mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true;

    Widget brandMark = AfriBrandMark(
      size: 180,
      borderRadius: ShapeTokens.chromeRadius,
      semanticLabel: context.afriL10n.splashLoadingSemantic(
        RuntimeBranding.displayAppName,
      ),
    );

    if (!reduceMotion) {
      brandMark = brandMark
          .afriAnimate(context)
          .scale(duration: 500.ms, curve: Curves.easeOutBack);
    }

    Widget progress = AfriLoadingIndicator(
      size: 20,
      color: ColorTokens.onSurface.withValues(alpha: 0.6),
    );

    if (!reduceMotion) {
      progress = progress
          .afriAnimate(context, delay: 800.ms)
          .fadeIn(duration: 400.ms);
    }

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [brandMark, const SizedBox(height: 32), progress],
        ),
      ),
    );
  }
}
