import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import 'afri_press_feedback.dart';

/// Shared universal popup menu trigger.
class AfriPopupMenuButton<T> extends StatelessWidget {
  const AfriPopupMenuButton({
    super.key,
    required this.itemBuilder,
    required this.child,
    this.onSelected,
    this.enabled = true,
    this.tooltip,
    this.offset = Offset.zero,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final Widget child;
  final bool enabled;
  final String? tooltip;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onSelected != null;
    return AfriPressFeedback(
      enabled: isEnabled,
      onTap: isEnabled ? () => unawaited(_showMenu(context)) : null,
      tooltip: tooltip,
      excludeChildSemantics: tooltip?.trim().isNotEmpty == true,
      builder: (context, state) => AnimatedContainer(
        duration: AfriMotion.resolve(context, AfriMotion.quick),
        decoration: BoxDecoration(
          color: state.isPressed
              ? ColorTokens.primaryTint(0.18)
              : state.isHovered
              ? ColorTokens.primaryTint(0.10)
              : ColorTokens.transparent,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusControl),
          border: state.isFocused
              ? BorderTokens.focusAll(color: ColorTokens.primaryContainer)
              : Border.fromBorderSide(
                  BorderTokens.side(color: ColorTokens.transparent),
                ),
        ),
        child: Opacity(
          opacity: isEnabled ? 1 : 0.48,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: SizeTokens.touchTargetMin,
              minHeight: SizeTokens.touchTargetMin,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = button.localToGlobal(offset, ancestor: overlay);
    final bottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero) + offset,
      ancestor: overlay,
    );
    final value = await showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: itemBuilder(context),
      color: ColorTokens.surfaceContainerHigh,
      surfaceTintColor: ColorTokens.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: ShapeTokens.cardRadius),
    );
    if (value != null && context.mounted) onSelected?.call(value);
  }
}
