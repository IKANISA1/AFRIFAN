import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/motion_tokens.dart';
import '../tokens/size_tokens.dart';

class AfriPressState {
  const AfriPressState({
    required this.isPressed,
    required this.isFocused,
    required this.isHovered,
  });

  final bool isPressed;
  final bool isFocused;
  final bool isHovered;
}

/// Accessible, focusable press wrapper for custom interactive surfaces.
///
/// Provides:
/// - tap + keyboard activation
/// - hover/focus tracking
/// - optional semantics and tooltip labeling
/// - lightweight tactile scale/opacity feedback
class AfriPressFeedback extends StatefulWidget {
  const AfriPressFeedback({
    required this.onTap,
    this.child,
    this.builder,
    this.scaleEnd = 0.97,
    this.opacityEnd = 0.92,
    this.haptic = true,
    this.enabled = true,
    this.button = true,
    this.selected = false,
    this.toggled,
    this.autofocus = false,
    this.focusNode,
    this.tooltip,
    this.semanticsLabel,
    this.semanticsHint,
    this.excludeChildSemantics = false,
    this.minimumTargetSize = SizeTokens.touchTargetMin,
    super.key,
  }) : assert(
         (child != null) != (builder != null),
         'Provide either child or builder.',
       );

  final Widget? child;
  final Widget Function(BuildContext context, AfriPressState state)? builder;
  final VoidCallback? onTap;
  final double scaleEnd;
  final double opacityEnd;
  final bool haptic;
  final bool enabled;
  final bool button;
  final bool selected;
  final bool? toggled;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? tooltip;
  final String? semanticsLabel;
  final String? semanticsHint;
  final bool excludeChildSemantics;
  final double minimumTargetSize;

  @override
  State<AfriPressFeedback> createState() => _AfriPressFeedbackState();
}

class _AfriPressFeedbackState extends State<AfriPressFeedback>
    with SingleTickerProviderStateMixin {
  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      };

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  bool _isPressed = false;
  bool _isFocused = false;
  bool _isHovered = false;

  bool get _isInteractive => widget.enabled && widget.onTap != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AfriMotion.press);
    _scale = Tween<double>(begin: 1.0, end: widget.scaleEnd).animate(
      CurvedAnimation(parent: _controller, curve: AfriMotion.pressCurve),
    );
    _opacity = Tween<double>(begin: 1.0, end: widget.opacityEnd).animate(
      CurvedAnimation(parent: _controller, curve: AfriMotion.pressCurve),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AfriMotion.resolve(context, AfriMotion.press);
    if (AfriMotion.reduceMotion(context) && _controller.isAnimating) {
      _controller.value = _isPressed ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!_isInteractive) return;
    setState(() => _isPressed = true);
    unawaited(_controller.forward());
    if (widget.haptic) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_isInteractive) return;
    setState(() => _isPressed = false);
    unawaited(_controller.reverse());
    if (widget.haptic) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _handleTapCancel() {
    if (!_isInteractive) return;
    setState(() => _isPressed = false);
    unawaited(_controller.reverse());
    if (widget.haptic) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _handleTap() {
    if (!_isInteractive) return;
    widget.onTap!.call();
  }

  void _setHovered(bool value) {
    if (!_isInteractive || _isHovered == value) return;
    setState(() => _isHovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final state = AfriPressState(
      isPressed: _isPressed,
      isFocused: _isFocused,
      isHovered: _isHovered,
    );

    Widget content = widget.builder?.call(context, state) ?? widget.child!;
    if (widget.excludeChildSemantics) {
      content = ExcludeSemantics(child: content);
    }

    content = FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(scale: _scale, child: content),
    );
    content = AnimatedScale(
      scale: (_isHovered || _isFocused) && !_isPressed ? 1.01 : 1,
      duration: AfriMotion.resolve(context, AfriMotion.quick),
      curve: AfriMotion.enterCurve,
      child: content,
    );
    content = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minimumTargetSize,
        minHeight: widget.minimumTargetSize,
      ),
      child: content,
    );

    content = FocusableActionDetector(
      enabled: _isInteractive,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      mouseCursor: _isInteractive
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      shortcuts: _shortcuts,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handleTap();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (value) {
        if (_isFocused == value) return;
        setState(() => _isFocused = value);
      },
      onShowHoverHighlight: (value) {
        _setHovered(value);
      },
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
    content = MouseRegion(
      cursor: _isInteractive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: content,
    );

    if (widget.tooltip != null && widget.tooltip!.trim().isNotEmpty) {
      content = Tooltip(message: widget.tooltip!, child: content);
    }

    final semantics = Semantics(
      button: widget.button,
      enabled: _isInteractive,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticsLabel,
      hint: widget.semanticsHint,
      onTap: _isInteractive ? _handleTap : null,
      child: content,
    );
    // An explicitly labeled single action excludes its visual child semantics.
    // Merge the gesture/focus nodes too, so assistive technology sees one named
    // control. Composite content keeps its independent descendant controls.
    return widget.excludeChildSemantics
        ? MergeSemantics(child: semantics)
        : semantics;
  }
}
