import 'package:core_theme/core_theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/biopay_providers.dart';

/// Route-level guard so direct BioPay deep links respect the kill switch.
class BiopayFeatureGate extends ConsumerWidget {
  const BiopayFeatureGate({required this.child, this.onBackPressed, super.key});

  final Widget child;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref
        .watch(biopayEnabledProvider)
        .maybeWhen(data: (value) => value, orElse: () => true);
    return KillSwitchGate(
      enabled: isEnabled,
      featureName: 'BioPay',
      onBackPressed: onBackPressed,
      child: child,
    );
  }
}
