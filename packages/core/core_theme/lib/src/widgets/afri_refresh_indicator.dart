import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Shared universal pull-to-refresh chrome.
class AfriRefreshIndicator extends StatelessWidget {
  const AfriRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
    this.displacement = AfriComponentSizes.refreshDisplacement,
    this.edgeOffset = SpacingTokens.spacing0,
    this.strokeWidth = RefreshProgressIndicator.defaultStrokeWidth,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.semanticsLabel,
    this.semanticsValue,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;
  final double displacement;
  final double edgeOffset;
  final double strokeWidth;
  final ScrollNotificationPredicate notificationPredicate;
  final String? semanticsLabel;
  final String? semanticsValue;
  final RefreshIndicatorTriggerMode triggerMode;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? ColorTokens.clubAccent,
      backgroundColor: backgroundColor ?? ColorTokens.surfaceContainerHigh,
      displacement: displacement,
      edgeOffset: edgeOffset,
      strokeWidth: strokeWidth,
      notificationPredicate: notificationPredicate,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
      triggerMode: triggerMode,
      elevation: 0,
      child: child,
    );
  }
}
