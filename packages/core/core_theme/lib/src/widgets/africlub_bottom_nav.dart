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
        height: 64,
        decoration: BoxDecoration(
          color: ColorTokens.surface,
          borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
          border: BorderTokens.ghost(width: BorderTokens.standard),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: -10,
              offset: const Offset(0, 10),
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
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isActive ? ColorTokens.clubAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            size: 20,
            color: isActive ? Colors.black : Colors.white38,
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: isActive ? Colors.black : Colors.white38,
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
