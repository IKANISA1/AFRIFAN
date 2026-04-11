import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Button variant enumeration for the AFRICLUB design system.
enum AfriButtonVariant { primary, secondary, outline, ghost, accent, clay }

/// Shared button component with a small, consistent set of emphasis levels.
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.985).animate(
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

    late Color background;
    late Color foreground;
    Border? border;
    List<BoxShadow>? shadows;

    switch (widget.variant) {
      case AfriButtonVariant.primary:
      case AfriButtonVariant.clay:
        background = colors.buttonPrimaryBackground;
        foreground = colors.buttonPrimaryForeground;
        shadows = [
          BoxShadow(
            color: background.withValues(alpha: 0.16),
            blurRadius: 16,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ];
      case AfriButtonVariant.secondary:
        background = colors.cardSurfaceStrong;
        foreground = colors.primaryText;
        border = BorderTokens.ghost(width: BorderTokens.standard);
      case AfriButtonVariant.outline:
        background = Colors.transparent;
        foreground = colors.primaryText;
        border = BorderTokens.all(
          color: colors.borderStrong,
          width: BorderTokens.standard,
        );
      case AfriButtonVariant.ghost:
        background = Colors.transparent;
        foreground = colors.secondaryText;
      case AfriButtonVariant.accent:
        background = colors.accent;
        foreground = ColorTokens.background;
        shadows = [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.14),
            blurRadius: 14,
            spreadRadius: -10,
            offset: const Offset(0, 6),
          ),
        ];
    }

    if (!_isActive) {
      background = background.withValues(alpha: background.a * 0.45);
      foreground = foreground.withValues(alpha: foreground.a * 0.55);
      shadows = null;
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
              valueColor: AlwaysStoppedAnimation(foreground),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: foreground),
          const SizedBox(width: SpacingTokens.spacing2),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
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
              horizontal: SpacingTokens.spacing5,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: background,
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
