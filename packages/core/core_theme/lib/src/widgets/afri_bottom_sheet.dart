import 'dart:ui';

import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/blur_tokens.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/shape_tokens.dart';

/// A glass bottom sheet wrapper with blur, ghost border, and accent glow.
///
/// Use with [showAfriBottomSheet] for consistent presentation.
class AfriBottomSheet extends StatelessWidget {
  const AfriBottomSheet({
    required this.child,
    this.padding,
    this.blur = AfriBlur.overlay,
    this.borderRadius = ShapeTokens.radiusXl,
    super.key,
  });

  final Widget child;
  final EdgeInsets? padding;
  final double blur;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final bgColor = colors.overlaySurface.withValues(alpha: 0.94);
    final borderCol = colors.border.withValues(alpha: 0.95);
    final glowCol = colors.accent.withValues(alpha: 0.08);

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(borderRadius),
            ),
            border: BorderTokens.sheet(color: borderCol, opacity: 0.16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.highlightColor.withValues(alpha: 0.03),
                glowCol,
                Colors.transparent,
              ],
              stops: const [0.0, 0.12, 0.6],
            ),
            boxShadow: AfriShadows.floating(null),
          ),
          child: SafeArea(
            child: Padding(
              padding: padding ?? const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a glass-themed bottom sheet.
///
/// ```dart
/// showAfriBottomSheet(
///   context: context,
///   builder: (ctx) => MySheetContent(),
/// );
/// ```
Future<T?> showAfriBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (ctx) => AfriBottomSheet(child: builder(ctx)),
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: false,
    useSafeArea: useSafeArea,
  );
}
