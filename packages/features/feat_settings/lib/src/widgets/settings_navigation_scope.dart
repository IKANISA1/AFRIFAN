import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void closeSettingsChild(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }

  context.go('/settings');
}

class SettingsBackGuard extends StatelessWidget {
  const SettingsBackGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && context.mounted) {
          context.go('/settings');
        }
      },
      child: child,
    );
  }
}
