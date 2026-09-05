import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Animated FET counter — animates from 0 to the target value on mount.
///
/// Used in wallets, cards, and profile summaries. The counter rolls up from
/// zero using a Tween animation, giving a slot-machine feel.
class AnimatedFetCounter extends StatefulWidget {
  const AnimatedFetCounter({
    super.key,
    required this.value,
    this.prefix = '+',
    this.suffix = ' FET',
    this.fontSize = 28,
    this.duration = AfriMotion.rewardReveal,
    this.color,
  });

  final int value;
  final String prefix;
  final String suffix;
  final double fontSize;
  final Duration duration;
  final Color? color;

  @override
  State<AnimatedFetCounter> createState() => _AnimatedFetCounterState();
}

class _AnimatedFetCounterState extends State<AnimatedFetCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<int> _animation;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = IntTween(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AfriMotion.reduceMotion(context);
    _controller.duration = _reduceMotion ? Duration.zero : widget.duration;
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      unawaited(_controller.forward());
    }
  }

  @override
  void didUpdateWidget(AnimatedFetCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = IntTween(begin: _animation.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.reset();
      if (_reduceMotion) {
        _controller.value = 1;
      } else {
        unawaited(_controller.forward());
      }
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
      animation: _animation,
      builder: (context, child) {
        final displayValue = _formatWithCommas(_animation.value);
        return Text(
          '${widget.prefix}$displayValue${widget.suffix}',
          style: TypographyTokens.monolithFont(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w700,
            color: widget.color ?? ColorTokens.primaryContainer,
          ),
        );
      },
    );
  }

  String _formatWithCommas(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
