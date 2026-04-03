import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Quick actions — horizontally scrollable row of tactile claymorphic circle icons.
///
/// Always one line, scrollable, with ellipsis for long names.
/// Items driven by the [actions] list — dynamic and extensible.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.confirmation_number_rounded,
        label: 'TICKETS',
        onTap: () => context.push('/tickets'),
      ),
      _QuickAction(
        icon: Icons.shopping_bag_rounded,
        label: 'SHOP',
        onTap: () => context.push('/shop'),
      ),
      _QuickAction(
        icon: Icons.groups_rounded,
        label: 'FAN CLUBS',
        onTap: () => context.push('/fan-clubs'),
      ),
      _QuickAction(
        icon: Icons.bolt_rounded,
        label: 'GAMES',
        onTap: () => context.push('/xp'),
      ),
      _QuickAction(
        icon: Icons.military_tech_rounded,
        label: 'MEMBERSHIP',
        onTap: () => context.push('/membership'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Full-width SUPPORT pill ──
        ClaymorphicButton(
          label: 'SUPPORT',
          icon: Icons.volunteer_activism_rounded,
          width: double.infinity,
          onPressed: () => context.push('/contribute'),
        ),
        const SizedBox(height: SpacingTokens.spacing8),

        // ── Section header ──
        Text(
          'QUICK ACTIONS',
          style: GoogleFonts.barlowCondensed(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ColorTokens.onSurface,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing5),

        // ── Horizontally scrollable row of circular icons ──
        SizedBox(
          height: _CircleActionButton.totalHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: actions.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: SpacingTokens.spacing3),
            itemBuilder: (context, index) =>
                _CircleActionButton(action: actions[index]),
          ),
        ),
      ],
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// A tactile claymorphic circular button — red circle, white icon, label below.
///
/// Matches the "Stadium Pulse" design system:
/// - Club-red fill
/// - Dual inner shadows (top-left light, bottom-right dark) for clay depth
/// - On press: shadows invert + scale down for "press-in" feel
/// - Haptic feedback on tap
/// - Single-line label with ellipsis for overflow
class _CircleActionButton extends StatelessWidget {
  final _QuickAction action;

  const _CircleActionButton({required this.action});

  /// Fixed tile width — gives enough room for icon + short label + ellipsis.
  static const double tileWidth = 70.0;

  /// Circle diameter.
  static const double circleSize = 52.0;

  /// Total height: circle + spacing + label line.
  static const double totalHeight = circleSize + 6 + 20;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: action.onTap,
      semanticsLabel: action.label,
      semanticsHint: 'Open ${action.label}',
      tooltip: action.label,
      excludeChildSemantics: true,
      builder: (context, state) => SizedBox(
        width: _CircleActionButton.tileWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Red claymorphic circle ──
            AnimatedScale(
              scale: state.isPressed ? 0.88 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: _CircleActionButton.circleSize,
                height: _CircleActionButton.circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColorTokens.clubPrimary,
                  border: state.isFocused
                      ? Border.all(
                          color: ColorTokens.onSurface.withValues(alpha: 0.85),
                          width: 1.3,
                        )
                      : null,
                  boxShadow: state.isPressed
                      ? [
                          // Pressed: inverted inner shadows
                          BoxShadow(
                            color: ColorTokens.background.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 2,
                            offset: const Offset(-1, -1),
                            blurStyle: BlurStyle.inner,
                          ),
                          BoxShadow(
                            color: ColorTokens.ghostBorder,
                            blurRadius: 3,
                            offset: const Offset(2, 2),
                            blurStyle: BlurStyle.inner,
                          ),
                        ]
                      : [
                          // Default: top-left light, bottom-right dark
                          BoxShadow(
                            color: ColorTokens.onSurface.withValues(
                              alpha: 0.22,
                            ),
                            blurRadius: 3,
                            offset: const Offset(-2, -2),
                            blurStyle: BlurStyle.inner,
                          ),
                          BoxShadow(
                            color: ColorTokens.background.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 5,
                            offset: const Offset(3, 3),
                            blurStyle: BlurStyle.inner,
                          ),
                          // Ambient outer glow
                          BoxShadow(
                            color: ColorTokens.clubPrimary.withValues(
                              alpha: 0.30,
                            ),
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: Icon(
                    action.icon,
                    color: ColorTokens.onSurface,
                    size: _CircleActionButton.circleSize * 0.42,
                  ),
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),

            // ── Single-line label with ellipsis ──
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.barlowCondensed(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ColorTokens.onSurface.withValues(alpha: 0.80),
                letterSpacing: 0.8,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
