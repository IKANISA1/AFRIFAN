import 'package:flutter/material.dart';

import '../runtime_branding.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

class AfriTopCommandAction {
  const AfriTopCommandAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.showDot = false,
  });

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
    this.searchSemanticsLabel,
    this.onSearchTap,
    this.onAvatarTap,
    this.showSearch = true,
    this.showNotificationDot = false,
    this.actions = const <AfriTopCommandAction>[],
  });

  final String searchHint;
  final String? searchSemanticsLabel;
  final VoidCallback? onSearchTap;
  final VoidCallback? onAvatarTap;
  final bool showSearch;
  final bool showNotificationDot;
  final List<AfriTopCommandAction> actions;

  @override
  Widget build(BuildContext context) {
    final visibleActions = actions.take(2).toList(growable: false);
    return Semantics(
      container: true,
      label: 'Primary screen actions',
      child: Row(
        children: [
          _CommandAvatar(
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
            _CommandCircle(action: visibleActions[index]),
          ],
        ],
      ),
    );
  }
}

class _CommandAvatar extends StatelessWidget {
  const _CommandAvatar({this.onTap, required this.showNotificationDot});

  final VoidCallback? onTap;
  final bool showNotificationDot;

  @override
  Widget build(BuildContext context) {
    final crestAsset = RuntimeBranding.displayCrestAsset;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AfriPressFeedback(
          onTap: onTap,
          semanticsLabel: 'Open profile',
          tooltip: 'Profile',
          builder: (context, state) => Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorTokens.referenceRewardsViolet.withValues(alpha: 0.96),
                  ColorTokens.referenceChromeBlack.withValues(alpha: 0.98),
                ],
              ),
              border: Border.all(
                color: state.isFocused
                    ? ColorTokens.primaryContainer
                    : ColorTokens.chromeBorder,
                width: state.isFocused ? 1.4 : 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: ColorTokens.ambientShadow.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: ClipOval(
                child: crestAsset.isEmpty
                    ? Center(
                        child: Text(
                          RuntimeBranding.appInitials,
                          maxLines: 1,
                          style: TypographyTokens.labelLarge(
                            ColorTokens.chromeForeground,
                          ),
                        ),
                      )
                    : Image.asset(
                        crestAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            RuntimeBranding.appInitials,
                            maxLines: 1,
                            style: TypographyTokens.labelLarge(
                              ColorTokens.chromeForeground,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        if (showNotificationDot)
          Positioned(
            right: 2,
            top: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ColorTokens.error,
                shape: BoxShape.circle,
                border: Border.all(
                  color: ColorTokens.chromeForeground,
                  width: 2,
                ),
              ),
              child: const SizedBox.square(dimension: 11),
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
          final showLabel = constraints.maxWidth >= 142;
          return Container(
            height: 58,
            padding: EdgeInsets.symmetric(
              horizontal: showLabel
                  ? SpacingTokens.spacing4
                  : SpacingTokens.spacing3,
            ),
            decoration: BoxDecoration(
              color: ColorTokens.chrome,
              borderRadius: ShapeTokens.buttonRadius,
              border: state.isFocused
                  ? BorderTokens.focusAll(color: ColorTokens.primaryContainer)
                  : Border.all(color: ColorTokens.chromeBorder, width: 1.15),
            ),
            child: Row(
              mainAxisAlignment: showLabel
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  AfriIcons.search,
                  color: ColorTokens.chromeForeground,
                  size: 27,
                ),
                if (showLabel) ...[
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: TypographyTokens.titleLarge(
                        ColorTokens.chromeForeground,
                      ).copyWith(fontWeight: FontWeight.w700),
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
  const _CommandCircle({required this.action});

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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: ColorTokens.chrome,
              shape: BoxShape.circle,
              border: state.isFocused
                  ? Border.all(color: ColorTokens.primaryContainer, width: 1.4)
                  : Border.all(color: ColorTokens.chromeBorder, width: 1.15),
            ),
            child: Icon(
              action.icon,
              color: ColorTokens.chromeForeground,
              size: 25,
            ),
          ),
        ),
        if (action.showDot)
          Positioned(
            right: 4,
            top: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ColorTokens.error,
                shape: BoxShape.circle,
                border: Border.all(
                  color: ColorTokens.chromeForeground,
                  width: 2,
                ),
              ),
              child: const SizedBox.square(dimension: 11),
            ),
          ),
      ],
    );
  }
}
