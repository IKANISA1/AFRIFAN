import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminRouteGuard extends ConsumerWidget {
  const AdminRouteGuard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProvider);
    if (profile?.isAdmin == true) {
      return child;
    }

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing8),
              child: GlassCard(
                animate: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      AfriIcons.lock,
                      size: 64,
                      color: ColorTokens.warning,
                    ),

                    const SizedBox(height: SpacingTokens.spacing4),
                    Text(
                      'ADMIN ACCESS REQUIRED',
                      textAlign: TextAlign.center,
                      style: TypographyTokens.headlineMedium().copyWith(
                        color: ColorTokens.onSurface,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Text(
                      'This workspace is limited to verified club administrators for the active club.',
                      textAlign: TextAlign.center,
                      style: TypographyTokens.bodyMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing6),
                    AfriButton(
                      label: 'Back to settings',
                      fullWidth: true,
                      onTap: () => context.go('/settings'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
