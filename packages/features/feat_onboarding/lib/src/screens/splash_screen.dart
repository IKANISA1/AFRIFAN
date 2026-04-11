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

    // Try restoring existing session first
    if (currentState is AuthInitial) {
      await authNotifier.restore();
    }

    if (!mounted || _hasNavigated) return;

    final resolvedState = ref.read(authStateProvider);

    if (resolvedState is AuthAuthenticated) {
      _hasNavigated = true;
      // §2.2 LOCKED — no MOMO gate on launch. Always go to /home.
      context.go('/home');
      return;
    }

    _hasNavigated = true;
    context.go('/onboarding');
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
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(40),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style:
            Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ) ??
            const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
      ),
    );
  }
}
