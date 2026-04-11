import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Button variant enumeration for the AFRICLUB design system.
enum AfriButtonVariant {
  /// Claymorphic primary — dual inner shadows, high prominence.
  primary,

  /// Subtle filled background — medium prominence.
  secondary,

  /// Ghost border only — low prominence.
  outline,

  /// No background — text-only, minimal prominence.
  ghost,

  /// Accent color fill — for success/positive actions.
  accent,

  /// Full claymorphic with inverted shadows on press.
  clay,
}

/// A multi-variant button for the AFRICLUB design system.
///
/// Supports 6 variants with consistent sizing, press feedback (scale +
/// haptic), loading state, and disabled state. Replaces the single-variant
/// [ClaymorphicButton] with a complete button system.
///
/// ```dart
/// AfriButton(
///   label: 'Join Club',
///   onTap: () => join(),
///   variant: AfriButtonVariant.primary,
/// )
/// ```
class AfriButton extends StatefulWidget {
  const AfriButton({
    required this.label,
    required this.onTap,
    this.variant = AfriButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final AfriButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final bool enabled;

  @override
  State<AfriButton> createState() => _AfriButtonState();
}

class _AfriButtonState extends State<AfriButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AfriMotion.press,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: AfriMotion.pressCurve),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  bool get _isActive => widget.enabled && !widget.isLoading;

  void _onTapDown(TapDownDetails _) {
    if (_isActive) _scaleController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (_isActive) _scaleController.reverse();
  }

  void _onTapCancel() {
    if (_isActive) _scaleController.reverse();
  }

  void _onTap() {
    if (!_isActive) return;
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final theme = Theme.of(context);
    final variant = widget.variant;

    // ── Resolve colors per variant ──
    final Color bg;
    final Color fg;
    final Border? border;

    switch (variant) {
      case AfriButtonVariant.primary:
      case AfriButtonVariant.clay:
        bg = colors.buttonPrimaryBackground;
        fg = colors.buttonPrimaryForeground;
        border = null;
      case AfriButtonVariant.secondary:
        bg = colors.cardSurface;
        fg = colors.primaryText;
        border = null;
      case AfriButtonVariant.outline:
        bg = Colors.transparent;
        fg = colors.primaryText;
        border = BorderTokens.all(color: colors.border, opacity: 0.72);
      case AfriButtonVariant.ghost:
        bg = Colors.transparent;
        fg = colors.secondaryText;
        border = null;
      case AfriButtonVariant.accent:
        bg = colors.accent;
        fg = ColorTokens.background;
        border = null;
    }

    final resolvedBg = _isActive ? bg : bg.withValues(alpha: bg.a * 0.5);
    final resolvedFg = _isActive ? fg : fg.withValues(alpha: fg.a * 0.5);

    // ── Build claymorphic shadows for clay/primary variants ──
    List<BoxShadow>? shadows;
    if (variant == AfriButtonVariant.clay ||
        variant == AfriButtonVariant.primary) {
      shadows = [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.2),
          blurRadius: 2,
          offset: const Offset(-2, -2),
        ),
        BoxShadow(
          color: ColorTokens.background.withValues(alpha: 0.3),
          blurRadius: 4,
          offset: const Offset(4, 4),
        ),
      ];
    }

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(resolvedFg),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: resolvedFg),
          const SizedBox(width: SpacingTokens.spacing3),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: resolvedFg,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _isActive,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: AfriMotion.quick,
            curve: AfriMotion.enterCurve,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
              vertical: SpacingTokens.spacing4,
            ),
            decoration: BoxDecoration(
              color: resolvedBg,
              borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
              border: border,
              boxShadow: shadows,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
