import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';

/// Shared borrowed-system sliver chrome for hero and scrolling routes.
class AfriSliverAppBar extends StatelessWidget {
  const AfriSliverAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.flexibleSpace,
    this.expandedHeight,
    this.pinned = false,
    this.floating = false,
    this.backgroundColor,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? flexibleSpace;
  final double? expandedHeight;
  final bool pinned;
  final bool floating;

  /// Accepted for staged migration; borrowed chrome controls the final tint.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveBackground =
        backgroundColor == Colors.transparent || backgroundColor == null
        ? ColorTokens.chrome.withValues(alpha: 0.82)
        : backgroundColor!.withValues(alpha: 0.88);

    return SliverAppBar(
      backgroundColor: effectiveBackground,
      foregroundColor: ColorTokens.chromeForeground,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      iconTheme: IconThemeData(color: ColorTokens.chromeForeground),
      expandedHeight: expandedHeight,
      pinned: pinned,
      floating: floating,
      title: title,
      leading: leading,
      actions: actions,
      flexibleSpace: flexibleSpace,
    );
  }
}
