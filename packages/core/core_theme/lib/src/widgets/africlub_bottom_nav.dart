import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/chrome_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

/// Announces whether the active application shell uses bottom navigation or
/// a large-screen side rail.
///
/// Route bodies use this to reserve floating-navigation clearance only when
/// the bottom bar is actually present. The default remains bottom navigation
/// so isolated feature and widget tests retain their mobile behavior.
class AfriShellNavigationScope extends InheritedWidget {
  const AfriShellNavigationScope({
    required this.usesBottomNavigation,
    required super.child,
    super.key,
  });

  final bool usesBottomNavigation;

  static bool usesBottomNavigationOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AfriShellNavigationScope>()
            ?.usesBottomNavigation ??
        true;
  }

  @override
  bool updateShouldNotify(AfriShellNavigationScope oldWidget) {
    return usesBottomNavigation != oldWidget.usesBottomNavigation;
  }
}

/// Shared bottom navigation bar with compact icon-first emphasis.
class AfriClubBottomNav extends StatelessWidget {
  static const double compactHeight = AfriChromeTokens.navigationCompactHeight;
  static const double regularHeight = AfriChromeTokens.navigationRegularHeight;
  static const double bottomMargin = AfriChromeTokens.navigationBottomMargin;
  static const double contentClearance =
      AfriChromeTokens.navigationContentClearance;

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AfriClubNavItem> items;

  const AfriClubBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  /// Bottom space scrollable shell content needs in order to remain fully
  /// visible above this floating navigation bar.
  static double contentBottomInset(BuildContext context) {
    if (!AfriShellNavigationScope.usesBottomNavigationOf(context)) {
      return 0;
    }
    final mediaQuery = MediaQuery.of(context);
    final isLargeText =
        mediaQuery.textScaler.scale(1) >
        AfriChromeTokens.navigationLargeTextThreshold;
    return mediaQuery.padding.bottom +
        bottomMargin +
        (isLargeText ? compactHeight : regularHeight) +
        contentClearance;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isLargeText =
        MediaQuery.textScalerOf(context).scale(1) >
        AfriChromeTokens.navigationLargeTextThreshold;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AfriChromeTokens.navigationHorizontalMargin,
        SpacingTokens.spacing0,
        AfriChromeTokens.navigationHorizontalMargin,
        bottomPadding + bottomMargin,
      ),
      child: ClipRRect(
        borderRadius: ShapeTokens.chromeRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AfriChromeTokens.navigationBlurSigma,
            sigmaY: AfriChromeTokens.navigationBlurSigma,
          ),
          child: Container(
            height: isLargeText ? compactHeight : regularHeight,
            decoration: BoxDecoration(
              color: ColorTokens.chrome,
              borderRadius: ShapeTokens.chromeRadius,
              border: BorderTokens.all(
                color: ColorTokens.chromeBorder,
                width: BorderTokens.chrome,
              ),
              boxShadow: AfriShadows.navigationChrome(),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AfriChromeTokens.navigationItemHorizontalPadding,
                vertical: AfriChromeTokens.navigationItemHorizontalPadding,
              ),
              child: Row(
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isActive = index == currentIndex;

                  return Expanded(
                    child: AfriPressFeedback(
                      enabled: item.enabled,
                      onTap: () => onTap(index),
                      tooltip: item.label,
                      semanticsLabel: item.label,
                      semanticsHint: 'Open ${item.label}',
                      selected: isActive,
                      excludeChildSemantics: true,
                      scaleEnd: AfriChromeTokens.navigationPressScale,
                      builder: (context, state) => _NavItem(
                        icon: item.icon,
                        activeIcon: item.activeIcon ?? item.icon,
                        label: item.label,
                        isActive: isActive,
                        isFocused: state.isFocused,
                        isEnabled: item.enabled,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.isFocused,
    required this.isEnabled,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isFocused;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final isLargeText =
        MediaQuery.textScalerOf(context).scale(1) >
        AfriChromeTokens.navigationLargeTextThreshold;

    return Opacity(
      opacity: isEnabled ? 1 : 0.48,
      child: AnimatedContainer(
        duration: AfriMotion.navigation,
        curve: Curves.easeOutCubic,
        height: double.infinity,
        constraints: const BoxConstraints(
          minHeight: SizeTokens.touchTargetMin,
          minWidth: AfriChromeTokens.navigationItemMinWidth,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AfriChromeTokens.navigationItemHorizontalMargin,
          vertical: AfriChromeTokens.navigationItemVerticalMargin,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AfriChromeTokens.navigationItemHorizontalPadding,
          vertical: AfriChromeTokens.navigationItemVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? ColorTokens.onDark.withValues(
                  alpha: AfriChromeTokens.navigationActiveFillOpacity,
                )
              : ColorTokens.transparent,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
          border: isFocused
              ? BorderTokens.focusAll(color: ColorTokens.primaryContainer)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: isLargeText
                  ? AfriChromeTokens.navigationLargeTextIconSize
                  : AfriChromeTokens.navigationIconSize,
              color: isActive
                  ? ColorTokens.chromeForeground
                  : ColorTokens.chromeForeground.withValues(
                      alpha: AfriChromeTokens.navigationInactiveContentOpacity,
                    ),
            ),
            if (!isLargeText) ...[
              const SizedBox(height: AfriChromeTokens.navigationLabelGap),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TypographyTokens.navigationLabel(
                    selected: isActive,
                    color: isActive
                        ? ColorTokens.chromeForeground
                        : ColorTokens.chromeForeground.withValues(
                            alpha: AfriChromeTokens
                                .navigationInactiveContentOpacity,
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AfriClubNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool enabled;

  const AfriClubNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.enabled = true,
  });
}
