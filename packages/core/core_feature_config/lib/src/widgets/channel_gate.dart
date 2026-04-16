import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feature_config_providers.dart';

/// Conditionally renders [child] only if the feature [featureKey] is
/// enabled on the current channel.
///
/// This is functionally equivalent to [FeatureGate] since the feature
/// config already accounts for channel-specific enablement via the
/// `platform_feature_channels` table. Use this widget when you want
/// to express channel-awareness in the widget tree explicitly.
class ChannelGate extends ConsumerWidget {
  const ChannelGate({
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
