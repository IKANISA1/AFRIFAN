import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';

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
    return PopupMenuButton<T>(
      enabled: enabled && onSelected != null,
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      tooltip: tooltip,
      offset: offset,
      color: ColorTokens.surfaceContainerHigh,
      surfaceTintColor: ColorTokens.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: ShapeTokens.cardRadius),
      child: child,
    );
  }
}
