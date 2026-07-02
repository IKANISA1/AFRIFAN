import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
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
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottomPadding + 12),
      child: ClipRRect(
        borderRadius: ShapeTokens.chromeRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: MediaQuery.textScalerOf(context).scale(1) > 1.45 ? 66 : 78,
            decoration: BoxDecoration(
              color: ColorTokens.chrome,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  ColorTokens.referencePaymentsPurple.withValues(alpha: 0.52),
                  ColorTokens.referenceChromeBlack.withValues(alpha: 0.98),
                ],
              ),
              borderRadius: ShapeTokens.chromeRadius,
              border: Border.all(color: ColorTokens.chromeBorder, width: 1.15),
              boxShadow: [
                BoxShadow(
                  color: ColorTokens.ambientShadow.withValues(alpha: 0.36),
                  blurRadius: 34,
                  spreadRadius: -12,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                      scaleEnd: 0.96,
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
    final isLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: double.infinity,
      constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
        border: isFocused
            ? Border.all(color: ColorTokens.primaryContainer, width: 1.2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            size: isLargeText ? 24 : 22,
            color: isActive
                ? ColorTokens.chromeForeground
                : ColorTokens.chromeForeground.withValues(alpha: 0.68),
          ),
          if (!isLargeText) ...[
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0,
                color: isActive
                    ? ColorTokens.chromeForeground
                    : ColorTokens.chromeForeground.withValues(alpha: 0.68),
              ),
            ),
          ],
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
