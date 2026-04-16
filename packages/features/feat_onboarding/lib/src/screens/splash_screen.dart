import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
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
    _navigateToNext();
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
        await authNotifier.restore().timeout(
          const Duration(seconds: 15),
        );
      } catch (_) {
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
    final crestAsset = RuntimeBranding.displayCrestAsset;

    return Scaffold(
      backgroundColor: ColorTokens.clubPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            (crestAsset.isNotEmpty
                    ? Image.asset(
                        crestAsset,
                        width: 180,
                        height: 180,
                        errorBuilder: (context, error, stackTrace) =>
                            _SplashFallbackBadge(
                              label: RuntimeBranding.appInitials,
                            ),
                      )
                    : _SplashFallbackBadge(label: RuntimeBranding.appInitials))
                .animate()
                .scale(duration: 500.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 32),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ColorTokens.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
                .animate(delay: 800.ms)
                .fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

class _SplashFallbackBadge extends StatelessWidget {
  const _SplashFallbackBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: ColorTokens.onSurface.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(40),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style:
            Theme.of(context).textTheme.displaySmall?.copyWith(
              color: ColorTokens.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ) ??
            TextStyle(
              color: ColorTokens.onSurface,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
      ),
    );
  }
}
