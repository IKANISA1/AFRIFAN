import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/blur_tokens.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/shape_tokens.dart';
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
        borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AfriBlur.overlay,
            sigmaY: AfriBlur.overlay,
          ),
          child: Container(
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorTokens.surfaceBright.withValues(alpha: 0.72),
                  ColorTokens.surfaceVariant.withValues(alpha: 0.46),
                  ColorTokens.primary.withValues(alpha: 0.22),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              border: BorderTokens.ghost(),
              boxShadow: [
                ...AfriShadows.glass(),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.10),
                  blurRadius: 16,
                  spreadRadius: -12,
                  offset: const Offset(-8, -10),
                  blurStyle: BlurStyle.inner,
                ),
                BoxShadow(
                  color: ColorTokens.ambientShadow.withValues(alpha: 0.24),
                  blurRadius: 20,
                  spreadRadius: -12,
                  offset: const Offset(10, 14),
                  blurStyle: BlurStyle.inner,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
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
                  width: 48,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
                    gradient: isActive
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ColorTokens.primary.withValues(alpha: 0.82),
                              ColorTokens.primaryContainer.withValues(
                                alpha: 0.82,
                              ),
                            ],
                          )
                        : null,
                    border: widget.isFocused
                        ? BorderTokens.focusAll(
                            color: ColorTokens.navActive,
                            opacity: 0.58,
                            width: 1.1,
                          )
                        : null,
                    boxShadow: isActive || widget.isFocused
                        ? [
                            BoxShadow(
                              color:
                                  (widget.isFocused
                                          ? ColorTokens.navActive
                                          : ColorTokens.primaryContainer)
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
                        ? Colors.white
                        : ColorTokens.onSurface.withValues(alpha: 0.44),
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
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                            height: 1.1,
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
