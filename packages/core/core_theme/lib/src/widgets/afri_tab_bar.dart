import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

enum AfriTabBarVariant { line, segmented }

/// Shared borrowed-system tab chrome for route-level and in-page navigation.
class AfriTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AfriTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.variant = AfriTabBarVariant.line,
    this.padding,
  });

  const AfriTabBar.line({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.padding,
  }) : variant = AfriTabBarVariant.line;

  const AfriTabBar.segmented({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.padding,
  }) : variant = AfriTabBarVariant.segmented;

  final List<Widget> tabs;
  final TabController? controller;
  final bool isScrollable;
  final AfriTabBarVariant variant;
  final EdgeInsetsGeometry? padding;

  static const double _lineHeight = 48;
  static const double _segmentedHeight = 46;

  @override
  Size get preferredSize {
    final effectivePadding = padding ?? _defaultPadding;
    final verticalPadding = effectivePadding.vertical;
    final height = switch (variant) {
      AfriTabBarVariant.line => _lineHeight,
      AfriTabBarVariant.segmented => _segmentedHeight,
    };
    return Size.fromHeight(height + verticalPadding);
  }

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? _defaultPadding;
    final tabBar = switch (variant) {
      AfriTabBarVariant.line => _buildLineTabBar(),
      AfriTabBarVariant.segmented => _buildSegmentedTabBar(),
    };

    return Padding(padding: effectivePadding, child: tabBar);
  }

  EdgeInsetsGeometry get _defaultPadding => const EdgeInsets.fromLTRB(
    SpacingTokens.screenPadding,
    0,
    SpacingTokens.screenPadding,
    SpacingTokens.spacing2,
  );

  Widget _buildLineTabBar() {
    return TabBar(
      controller: controller,
      isScrollable: isScrollable,
      indicatorColor: ColorTokens.clubAccent,
      indicatorWeight: 2.5,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: ColorTokens.clubAccent,
      unselectedLabelColor: ColorTokens.onSurfaceVariant,
      labelStyle: TypographyTokens.labelSmall().copyWith(
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: TypographyTokens.labelSmall(),
      dividerColor: ColorTokens.transparent,
      overlayColor: WidgetStateProperty.all(ColorTokens.transparent),
      splashFactory: NoSplash.splashFactory,
      tabs: tabs,
    );
  }

  Widget _buildSegmentedTabBar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        indicator: BoxDecoration(
          color: ColorTokens.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: ColorTokens.ambientShadow.withValues(alpha: 0.12),
              blurRadius: 8,
              spreadRadius: -4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: ColorTokens.onSurface,
        unselectedLabelColor: ColorTokens.onSurfaceVariant,
        labelStyle: TypographyTokens.labelMedium(),
        unselectedLabelStyle: TypographyTokens.labelMedium(
          ColorTokens.onSurfaceVariant,
        ),
        dividerColor: ColorTokens.transparent,
        overlayColor: WidgetStateProperty.all(ColorTokens.transparent),
        splashFactory: NoSplash.splashFactory,
        tabs: tabs,
      ),
    );
  }
}
