import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'staff_step_up_screen.dart';

class AdminRouteGuard extends ConsumerStatefulWidget {
  const AdminRouteGuard({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AdminRouteGuard> createState() => _AdminRouteGuardState();
}

class _AdminRouteGuardState extends ConsumerState<AdminRouteGuard> {
  bool _roleChecked = false;
  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() async {
        await ref.read(authStateProvider.notifier).refreshAdminAccess();
        if (mounted) setState(() => _roleChecked = true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProvider);
    if (!_roleChecked) {
      return const AfriScreenScaffold(
        child: Center(child: AfriLoadingIndicator()),
      );
    }
    if (profile?.isAdmin == true) {
      final assurance = ref.watch(staffStepUpProvider);
      if (!assurance.isFresh) return const StaffStepUpScreen();
      return widget.child;
    }

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      constrainContent: true,
      bodyWrapper: (child) => GradientBackground(child: child),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing8),
            child: GlassCard(
              animate: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AfriIcons.lock, size: 64, color: ColorTokens.warning),

                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    context.afriL10n.adminAccessRequired,
                    textAlign: TextAlign.center,
                    style: TypographyTokens.headlineMedium().copyWith(
                      color: ColorTokens.onSurface,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(
                    context.afriL10n.adminAccessRequiredMessage,
                    textAlign: TextAlign.center,
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  AfriButton(
                    label: context.afriL10n.adminBackToSettings,
                    fullWidth: true,
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
