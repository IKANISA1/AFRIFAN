import 'package:flutter/material.dart';

import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

/// Shared bottom navigation bar with compact icon-first emphasis.
class AfriClubBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AfriClubNavItem> items;

  const AfriClubBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.spacing4,
        0,
        SpacingTokens.spacing4,
        bottomPadding + SpacingTokens.spacing4,
      ),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: ColorTokens.surfaceContainerLowest.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(ShapeTokens.radiusXl),
          border: BorderTokens.ghost(width: BorderTokens.standard),
          boxShadow: [
            BoxShadow(
              color: ColorTokens.ambientShadow.withValues(alpha: 0.20),
              blurRadius: 24,
              spreadRadius: -10,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing2,
            vertical: SpacingTokens.spacing2,
          ),
          child: Row(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = index == currentIndex;

              return Expanded(
                child: AfriPressFeedback(
                  onTap: () => onTap(index),
                  tooltip: item.label,
                  semanticsLabel: item.label,
                  semanticsHint: 'Open ${item.label}',
                  selected: isActive,
                  excludeChildSemantics: true,
                  builder: (context, state) => _NavItem(
                    icon: item.icon,
                    activeIcon: item.activeIcon ?? item.icon,
                    label: item.label,
                    isActive: isActive,
                    isFocused: state.isFocused,
                  ),
                ),
              );
            }).toList(),
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
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? ColorTokens.primaryTint(0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
        border: isFocused
            ? BorderTokens.focusAll(
                color: ColorTokens.primaryContainer,
                opacity: 0.9,
              )
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            size: 20,
            color: isActive
                ? ColorTokens.primaryContainer
                : ColorTokens.onSurfaceVariant,
          ),
          if (isActive)
            Flexible(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: SpacingTokens.spacing2,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypographyTokens.labelSmall(
                      ColorTokens.primaryContainer,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AfriClubNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const AfriClubNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}
