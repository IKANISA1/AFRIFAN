import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/spacing_tokens.dart';

/// Shared universal route chrome for secondary Flutter screens.
class AfriAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AfriAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.flexibleSpace,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.elevation,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? flexibleSpace;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;

  /// Accepted for staged migration; shared chrome owns the actual color.
  final Color? backgroundColor;

  /// Accepted for staged migration; shared chrome remains flat.
  final double? elevation;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;
    final effectiveBackground =
        backgroundColor ?? theme.scaffoldBackgroundColor;

    final effectiveTitle = switch (title) {
      final Text text => _chromeTextTitle(context, text),
      _ => title,
    };

    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: effectiveBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle:
          (theme.brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
      foregroundColor: foreground,
      iconTheme: IconThemeData(color: foreground),
      titleSpacing: leading == null ? SpacingTokens.screenPadding : 0,
      centerTitle: centerTitle ?? false,
      title: effectiveTitle,
      leading: leading,
      actions: actions,
      bottom: bottom,
      flexibleSpace: flexibleSpace,
    );
  }

  Text _chromeTextTitle(BuildContext context, Text text) {
    final style = (text.style ?? DefaultTextStyle.of(context).style).copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );
    final span = text.textSpan;
    if (span != null) {
      return Text.rich(
        span,
        key: text.key,
        style: style,
        strutStyle: text.strutStyle,
        textAlign: text.textAlign,
        textDirection: text.textDirection,
        locale: text.locale,
        softWrap: text.softWrap,
        overflow: text.overflow,
        textScaler: text.textScaler,
        maxLines: text.maxLines,
        semanticsLabel: text.semanticsLabel,
        textWidthBasis: text.textWidthBasis,
        textHeightBehavior: text.textHeightBehavior,
        selectionColor: text.selectionColor,
      );
    }
    return Text(
      text.data ?? '',
      key: text.key,
      style: style,
      strutStyle: text.strutStyle,
      textAlign: text.textAlign,
      textDirection: text.textDirection,
      locale: text.locale,
      softWrap: text.softWrap,
      overflow: text.overflow,
      textScaler: text.textScaler,
      maxLines: text.maxLines,
      semanticsLabel: text.semanticsLabel,
      textWidthBasis: text.textWidthBasis,
      textHeightBehavior: text.textHeightBehavior,
      selectionColor: text.selectionColor,
    );
  }
}
