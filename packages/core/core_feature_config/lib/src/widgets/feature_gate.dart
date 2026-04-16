import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feature_config_providers.dart';

/// Conditionally renders [child] only if the feature [featureKey] is enabled.
///
/// Uses [isFeatureEnabledProvider] for reactive updates.
class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.featureKey,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final String featureKey;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(isFeatureEnabledProvider(featureKey));
    return isEnabled ? child : fallback;
  }
}
