import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Countdown timer widget for jackpot challenges.
///
/// Shows days / hours / minutes / seconds until the jackpot deadline.
/// Updates every second. Mirrors the fanafrika JackpotChallenge countdown UX.
class JackpotCountdownTimer extends StatefulWidget {
  const JackpotCountdownTimer({
    super.key,
    required this.deadline,
    this.onExpired,
  });

  /// The jackpot deadline.
  final DateTime deadline;

  /// Called when the countdown reaches zero.
  final VoidCallback? onExpired;

  @override
  State<JackpotCountdownTimer> createState() => _JackpotCountdownTimerState();
}

class _JackpotCountdownTimerState extends State<JackpotCountdownTimer> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final diff = widget.deadline.difference(now);
    if (diff.isNegative && _remaining > Duration.zero) {
      widget.onExpired?.call();
    }
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    final isExpired = _remaining == Duration.zero;

    return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing5,
            vertical: SpacingTokens.spacing4,
          ),
          decoration: BoxDecoration(
            gradient: ColorTokens.borrowedSurfaceGradient(
              from: ColorTokens.clubAccent.withValues(alpha: 0.12),
              to: ColorTokens.surfaceContainerLow,
            ),
            borderRadius: ShapeTokens.cardRadius,
            border: BorderTokens.all(
              color: ColorTokens.clubAccent.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            children: [
              Text(
                isExpired ? 'ENTRIES CLOSED' : 'ENTRIES CLOSE IN',
                style: TypographyTokens.metricLabel(
                  ColorTokens.onSurfaceVariant,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 2),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeUnit(value: days, label: 'DAYS'),
                  _Separator(),
                  _TimeUnit(value: hours, label: 'HRS'),
                  _Separator(),
                  _TimeUnit(value: minutes, label: 'MIN'),
                  _Separator(),
                  _TimeUnit(
                    value: seconds,
                    label: 'SEC',
                    highlight: !isExpired,
                  ),
                ],
              ),
            ],
          ),
        )
        .animate(target: isExpired ? 1 : 0)
        .tint(color: ColorTokens.error.withValues(alpha: 0.2));
  }
}

class _TimeUnit extends StatelessWidget {
  const _TimeUnit({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final int value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: TypographyTokens.metricValue(
            highlight ? ColorTokens.clubAccent : ColorTokens.onSurface,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TypographyTokens.metricLabel(
            ColorTokens.onSurfaceVariant,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing2),
      child: Text(
        ':',
        style: TypographyTokens.headlineMedium(
          ColorTokens.onSurfaceVariant,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
