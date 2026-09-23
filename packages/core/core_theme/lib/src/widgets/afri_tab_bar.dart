import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

enum AfriTabBarVariant { line, segmented }

/// Shared universal tab chrome for route-level and in-page navigation.
class AfriTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AfriTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.variant = AfriTabBarVariant.line,
    this.padding,
    this.disabledIndices = const <int>{},
    this.onTap,
  });

  const AfriTabBar.line({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.padding,
    this.disabledIndices = const <int>{},
    this.onTap,
  }) : variant = AfriTabBarVariant.line;

  const AfriTabBar.segmented({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.padding,
    this.disabledIndices = const <int>{},
    this.onTap,
  }) : variant = AfriTabBarVariant.segmented;

  final List<Widget> tabs;
  final TabController? controller;
  final bool isScrollable;
  final AfriTabBarVariant variant;
  final EdgeInsetsGeometry? padding;
  final Set<int> disabledIndices;
  final ValueChanged<int>? onTap;

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
      AfriTabBarVariant.line => _buildLineTabBar(context),
      AfriTabBarVariant.segmented => _buildSegmentedTabBar(context),
    };

    return Padding(padding: effectivePadding, child: tabBar);
  }

  EdgeInsetsGeometry get _defaultPadding => const EdgeInsets.fromLTRB(
    SpacingTokens.screenPadding,
    0,
    SpacingTokens.screenPadding,
    SpacingTokens.spacing2,
  );

  Widget _buildLineTabBar(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: isScrollable,
      indicatorColor: ColorTokens.primaryContainer,
      indicatorWeight: BorderTokens.tabIndicator,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: ColorTokens.primaryContainer,
      unselectedLabelColor: ColorTokens.onSurfaceVariant,
      labelStyle: TypographyTokens.labelSmall().copyWith(
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: TypographyTokens.labelSmall(),
      dividerColor: ColorTokens.transparent,
      overlayColor: _interactionOverlay,
      onTap: (index) => _handleTap(context, index),
      tabs: _resolvedTabs,
    );
  }

  Widget _buildSegmentedTabBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AfriComponentSizes.segmentedInset),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: ShapeTokens.buttonRadius,
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        indicator: BoxDecoration(
          color: ColorTokens.surfaceContainerHighest,
          borderRadius: ShapeTokens.segmentedInnerRadius,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: ColorTokens.onSurface,
        unselectedLabelColor: ColorTokens.onSurfaceVariant,
        labelStyle: TypographyTokens.labelMedium(),
        unselectedLabelStyle: TypographyTokens.labelMedium(
          ColorTokens.onSurfaceVariant,
        ),
        dividerColor: ColorTokens.transparent,
        overlayColor: _interactionOverlay,
        onTap: (index) => _handleTap(context, index),
        tabs: _resolvedTabs,
      ),
    );
  }

  List<Widget> get _resolvedTabs => [
    for (var index = 0; index < tabs.length; index++)
      if (disabledIndices.contains(index))
        Opacity(
          opacity: 0.48,
          child: Semantics(enabled: false, child: tabs[index]),
        )
      else
        tabs[index],
  ];

  WidgetStateProperty<Color?> get _interactionOverlay =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return ColorTokens.primaryTint(0.22);
        }
        if (states.contains(WidgetState.pressed)) {
          return ColorTokens.primaryTint(0.18);
        }
        if (states.contains(WidgetState.hovered)) {
          return ColorTokens.primaryTint(0.10);
        }
        return ColorTokens.transparent;
      });

  void _handleTap(BuildContext context, int index) {
    if (disabledIndices.contains(index)) {
      final resolvedController = controller ?? DefaultTabController.of(context);
      resolvedController.animateTo(resolvedController.previousIndex);
      return;
    }
    onTap?.call(index);
  }
}
