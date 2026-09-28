import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/chrome_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_brand_mark.dart';
import 'afri_press_feedback.dart';

class AfriTopCommandAction {
  const AfriTopCommandAction({
    this.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.showDot = false,
  });

  final Key? key;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showDot;
}

/// Black-glass command chrome for primary mobile routes.
class AfriTopCommandBar extends StatelessWidget {
  const AfriTopCommandBar({
    super.key,
    this.searchHint = 'Search',
    this.avatarIcon,
    this.searchSemanticsLabel,
    this.onSearchTap,
    this.onAvatarTap,
    this.showSearch = true,
    this.showNotificationDot = false,
    this.actions = const <AfriTopCommandAction>[],
  });

  final String searchHint;
  final IconData? avatarIcon;
  final String? searchSemanticsLabel;
  final VoidCallback? onSearchTap;
  final VoidCallback? onAvatarTap;
  final bool showSearch;
  final bool showNotificationDot;
  final List<AfriTopCommandAction> actions;

  @override
  Widget build(BuildContext context) {
    final visibleActions = actions
        .take(AfriChromeTokens.maxTopCommandActions)
        .toList(growable: false);
    return Semantics(
      container: true,
      label: 'Primary screen actions',
      child: Row(
        children: [
          _CommandAvatar(
            icon: avatarIcon,
            onTap: onAvatarTap,
            showNotificationDot: showNotificationDot,
          ),
          if (showSearch) ...[
            const SizedBox(width: SpacingTokens.spacing3),
            Expanded(
              child: _CommandSearchButton(
                label: searchHint,
                semanticsLabel: searchSemanticsLabel ?? searchHint,
                onTap: onSearchTap,
              ),
            ),
          ] else
            const Spacer(),
          if (visibleActions.isNotEmpty)
            const SizedBox(width: SpacingTokens.spacing3),
          for (var index = 0; index < visibleActions.length; index += 1) ...[
            if (index > 0) const SizedBox(width: SpacingTokens.spacing2),
            _CommandCircle(
              key: visibleActions[index].key,
              action: visibleActions[index],
            ),
          ],
        ],
      ),
    );
  }
}

class _CommandAvatar extends StatelessWidget {
  const _CommandAvatar({
    this.onTap,
    this.icon,
    required this.showNotificationDot,
  });

  final IconData? icon;

  final VoidCallback? onTap;
  final bool showNotificationDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AfriPressFeedback(
          onTap: onTap,
          semanticsLabel: 'Open profile',
          tooltip: 'Profile',
          builder: (context, state) => Container(
            width: AfriChromeTokens.commandControlSize,
            height: AfriChromeTokens.commandControlSize,
            decoration: BoxDecoration(
              color: icon == null
                  ? null
                  : ColorTokens.inkBase.withValues(
                      alpha: AfriChromeTokens.commandFillOpacity,
                    ),
              shape: BoxShape.circle,
              border: state.isFocused
                  ? BorderTokens.focusAll(color: ColorTokens.onSurface)
                  : null,
            ),
            child: Center(
              child: icon == null
                  ? const AfriBrandMark(size: AfriChromeTokens.commandBrandSize)
                  : Icon(
                      icon,
                      color: ColorTokens.chromeForeground,
                      size: AfriChromeTokens.commandActionIconSize,
                    ),
            ),
          ),
        ),
        if (showNotificationDot)
          Positioned(
            right: AfriChromeTokens.notificationDotInset,
            top: AfriChromeTokens.notificationDotInset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ColorTokens.error,
                shape: BoxShape.circle,
                border: BorderTokens.all(
                  color: ColorTokens.chromeForeground,
                  width: BorderTokens.emphasis,
                ),
              ),
              child: const SizedBox.square(
                dimension: AfriChromeTokens.notificationDotSize,
              ),
            ),
          ),
      ],
    );
  }
}

class _CommandSearchButton extends StatelessWidget {
  const _CommandSearchButton({
    required this.label,
    required this.semanticsLabel,
    this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: onTap,
      semanticsLabel: semanticsLabel,
      tooltip: semanticsLabel,
      builder: (context, state) => LayoutBuilder(
        builder: (context, constraints) {
          final labelPainter = TextPainter(
            text: TextSpan(text: label, style: TypographyTokens.bodyLarge()),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final labelWidth = labelPainter.width;
          labelPainter.dispose();
          final showLabel =
              label.isNotEmpty &&
              constraints.maxWidth >=
                  AfriChromeTokens.commandSearchLabelMinWidth &&
              constraints.maxWidth >=
                  labelWidth +
                      SpacingTokens.spacing4 * 2 +
                      SpacingTokens.spacing3 +
                      AfriChromeTokens.commandSearchIconSize;
          return Container(
            height: AfriChromeTokens.commandControlSize,
            padding: EdgeInsets.symmetric(
              horizontal: showLabel
                  ? SpacingTokens.spacing4
                  : SpacingTokens.spacing3,
            ),
            decoration: BoxDecoration(
              color: ColorTokens.inkBase.withValues(
                alpha: AfriChromeTokens.commandFillOpacity,
              ),
              borderRadius: ShapeTokens.buttonRadius,
              border: state.isFocused
                  ? BorderTokens.focusAll(
                      color: ColorTokens.primaryContainer,
                      width: context.afriDesignTokens.focusRingWidth,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: showLabel
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  AfriIcons.search,
                  color: ColorTokens.chromeForeground,
                  size: AfriChromeTokens.commandSearchIconSize,
                ),
                if (showLabel) ...[
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: TypographyTokens.bodyLarge(
                        ColorTokens.chromeForeground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommandCircle extends StatelessWidget {
  const _CommandCircle({super.key, required this.action});

  final AfriTopCommandAction action;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AfriPressFeedback(
          onTap: action.onTap,
          semanticsLabel: action.label,
          tooltip: action.label,
          builder: (context, state) => Container(
            width: AfriChromeTokens.commandControlSize,
            height: AfriChromeTokens.commandControlSize,
            decoration: BoxDecoration(
              color: ColorTokens.inkBase.withValues(
                alpha: AfriChromeTokens.commandFillOpacity,
              ),
              shape: BoxShape.circle,
              border: BorderTokens.all(
                color: state.isFocused
                    ? ColorTokens.primaryContainer
                    : ColorTokens.chromeBorder,
                width: state.isFocused
                    ? BorderTokens.chromeFocus
                    : BorderTokens.chrome,
              ),
            ),
            child: Icon(
              action.icon,
              color: ColorTokens.chromeForeground,
              size: AfriChromeTokens.commandActionIconSize,
            ),
          ),
        ),
        if (action.showDot)
          Positioned(
            right: AfriChromeTokens.actionNotificationDotInset,
            top: AfriChromeTokens.notificationDotInset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ColorTokens.error,
                shape: BoxShape.circle,
                border: BorderTokens.all(
                  color: ColorTokens.chromeForeground,
                  width: BorderTokens.emphasis,
                ),
              ),
              child: const SizedBox.square(
                dimension: AfriChromeTokens.notificationDotSize,
              ),
            ),
          ),
      ],
    );
  }
}
