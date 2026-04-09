import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/blur_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

/// AFRICLUB floating bottom navigation bar.
///
/// Design language: Glassmorphism + Claymorphism hybrid.
/// - Floats above content with rounded corners
/// - Frosted glass backdrop blur
/// - Soft gradient overlay (deep navy → midnight with subtle warmth)
/// - Claymorphic inner shadows for tactile depth
/// - Active item: glowing pill with icon + label
/// - Inactive item: translucent icon only
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
      // Float 16px from left/right edges + safe area bottom
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.spacing6,
        0,
        SpacingTokens.spacing6,
        bottomPadding + SpacingTokens.spacing4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AfriBlur.overlay,
            sigmaY: AfriBlur.overlay,
          ),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              // ── Soft gradient fill ──
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                  ColorTokens.clubPrimary.withValues(alpha: 0.03),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              // ── Ghost border ──
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.8,
              ),
              // ── Claymorphic double inner shadows + ambient outer ──
              boxShadow: [
                // Top-left inner highlight (clay light)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.07),
                  blurRadius: 2,
                  offset: const Offset(-1.5, -1.5),
                  blurStyle: BlurStyle.inner,
                ),
                // Bottom-right inner shadow (clay depth)
                BoxShadow(
                  color: ColorTokens.background.withValues(alpha: 0.30),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                  blurStyle: BlurStyle.inner,
                ),
                // Ambient outer shadow (floating feel)
                BoxShadow(
                  color: ColorTokens.background.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
                // Subtle warm underglow
                BoxShadow(
                  color: ColorTokens.clubPrimary.withValues(alpha: 0.06),
                  blurRadius: 32,
                  spreadRadius: -2,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                    builder: (context, state) => _FloatingNavItem(
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
    );
  }
}

class _FloatingNavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isFocused;

  const _FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.isFocused,
  });

  @override
  State<_FloatingNavItem> createState() => _FloatingNavItemState();
}

class _FloatingNavItemState extends State<_FloatingNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    if (widget.isActive) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _FloatingNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isActive = widget.isActive;
        final progress = _scaleAnim.value;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon with active pill background ──
              Transform.scale(
                scale: 1.0 + (progress * 0.15),
                child: Container(
                  width: 44,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    // Active pill: soft red glow
                    gradient: isActive
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ColorTokens.clubPrimary.withValues(alpha: 0.22),
                              ColorTokens.clubPrimary.withValues(alpha: 0.10),
                            ],
                          )
                        : null,
                    border: widget.isFocused
                        ? Border.all(
                            color: ColorTokens.navActive.withValues(
                              alpha: 0.58,
                            ),
                            width: 1.1,
                          )
                        : null,
                    boxShadow: isActive || widget.isFocused
                        ? [
                            // Active glow
                            BoxShadow(
                              color:
                                  (widget.isFocused
                                          ? ColorTokens.navActive
                                          : ColorTokens.clubPrimary)
                                      .withValues(
                                        alpha: widget.isFocused ? 0.18 : 0.25,
                                      ),
                              blurRadius: 16,
                              spreadRadius: -2,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isActive ? widget.activeIcon : widget.icon,
                    color: isActive
                        ? ColorTokens.navActive
                        : ColorTokens.onSurface.withValues(alpha: 0.38),
                    size: 22,
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: isActive
                    ? Padding(
                        padding: const EdgeInsets.only(
                          top: SpacingTokens.spacing1,
                        ),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypographyTokens.labelSmall().copyWith(
                            color: ColorTokens.navActive,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                            height: 1.0,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Data class for a bottom navigation item.
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
