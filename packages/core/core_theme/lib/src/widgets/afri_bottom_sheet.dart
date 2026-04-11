import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'clay_card.dart';

/// Shared minimalist modal sheet surface.
class AfriBottomSheet extends StatelessWidget {
  const AfriBottomSheet({
    required this.child,
    this.padding,
    this.borderRadius = ShapeTokens.radiusXl,
    super.key,
  });

  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.appBackground.withValues(alpha: 0.72),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClayCard(
            backgroundColor: colors.overlaySurface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(borderRadius),
            ),
            padding: padding ?? const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(
                      bottom: SpacingTokens.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.tertiaryText.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
