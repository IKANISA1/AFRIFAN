import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/color_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';

enum EliteButtonVariant { primary, secondary, outline }

class EliteButton extends StatefulWidget {
  const EliteButton({
    required this.label,
    required this.onTap,
    this.variant = EliteButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final EliteButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final bool enabled;

  @override
  State<EliteButton> createState() => _EliteButtonState();
}

class _EliteButtonState extends State<EliteButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
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
    late Color background;
    late Color foreground;
    Border? border;

    switch (widget.variant) {
      case EliteButtonVariant.primary:
        background = ColorTokens.clubAccent;
        foreground = Colors.black;
      case EliteButtonVariant.secondary:
        background = ColorTokens.surfaceContainerHigh;
        foreground = Colors.white;
      case EliteButtonVariant.outline:
        background = Colors.transparent;
        foreground = Colors.white;
        border = Border.all(color: Colors.white24);
    }

    if (!_isActive) {
      background = background.withValues(alpha: background.a * 0.4);
      foreground = foreground.withValues(alpha: foreground.a * 0.4);
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: AfriMotion.quick,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
            border: border,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: widget.fullWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              if (widget.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else if (widget.icon != null)
                Icon(widget.icon, size: 18, color: foreground),
              if (widget.isLoading || widget.icon != null)
                const SizedBox(width: 8),
              Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
