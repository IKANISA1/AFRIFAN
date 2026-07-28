import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_surface_card.dart';

/// Shared universal modal sheet surface.
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
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.spacing3,
            SpacingTokens.spacing0,
            SpacingTokens.spacing3,
            SpacingTokens.spacing3,
          ),
          child: AfriSurfaceCard(
            backgroundColor: colors.overlaySurface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(borderRadius),
            ),
            padding:
                padding ??
                const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing5,
                  SpacingTokens.spacing3,
                  SpacingTokens.spacing5,
                  SpacingTokens.spacing5,
                ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: AfriComponentSizes.compactSheetHandleWidth,
                    height: SizeTokens.sheetHandleHeight,
                    margin: const EdgeInsets.only(
                      bottom: SpacingTokens.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.tertiaryText.withValues(alpha: 0.5),
                      borderRadius: ShapeTokens.buttonRadius,
                    ),
                  ),
                ),
                Flexible(fit: FlexFit.loose, child: child),
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
  bool useUniversalSurface = true,
}) {
  final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
  return showModalBottomSheet<T>(
    context: context,
    builder: (ctx) => AnimatedPadding(
      duration: AfriMotion.reduceMotion(ctx) ? Duration.zero : AfriMotion.quick,
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: useUniversalSurface
          ? AfriBottomSheet(child: builder(ctx))
          : builder(ctx),
    ),
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: isScrollControlled || keyboardInset > 0,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: false,
    useSafeArea: useSafeArea,
    sheetAnimationStyle: AfriMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
  );
}

void closeAfriBottomSheet(BuildContext context, [Object? result]) {
  Navigator.of(context).pop(result);
}
