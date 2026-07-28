import 'dart:async';

import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';

/// Shimmer-effect skeleton for loading states.
///
/// Provides named constructors for common shapes:
/// - [AfriSkeleton.card] — full-width card skeleton
/// - [AfriSkeleton.listCard] — horizontal list item
/// - [AfriSkeleton.line] — text line skeleton
///
/// Respects `MediaQuery.disableAnimationsOf` for reduced-motion.
class AfriSkeleton extends StatefulWidget {
  const AfriSkeleton({
    this.width,
    this.height = AfriComponentSizes.skeletonDefaultHeight,
    this.borderRadius = ShapeTokens.radiusMd,
    super.key,
  });

  /// Card-shaped skeleton (full width, taller).
  const AfriSkeleton.card({super.key})
    : width = double.infinity,
      height = 120,
      borderRadius = ShapeTokens.radiusXl;

  /// Horizontal list item card.
  const AfriSkeleton.listCard({super.key})
    : width = 180,
      height = 200,
      borderRadius = ShapeTokens.radiusXl;

  /// Line of text.
  const AfriSkeleton.line({double? width, super.key})
    : width = width ?? 120,
      height = 12,
      borderRadius = ShapeTokens.radiusSm;

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<AfriSkeleton> createState() => _AfriSkeletonState();
}

class _AfriSkeletonState extends State<AfriSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AfriMotion.skeletonShimmer,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AfriMotion.reduceMotion(context);
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    if (_reduceMotion) {
      return ExcludeSemantics(
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.cardSurface,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      );
    }

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
                end: Alignment(1.0 + 2.0 * _controller.value, 0),
                colors: <Color>[
                  colors.cardSurface,
                  colors.cardSurfaceStrong,
                  colors.cardSurface,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A column of skeleton cards.
class AfriSkeletonList extends StatelessWidget {
  const AfriSkeletonList({this.itemCount = 3, this.spacing = 12, super.key});

  final int itemCount;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i < itemCount - 1 ? spacing : 0),
          child: const AfriSkeleton.card(),
        ),
      ),
    );
  }
}

/// A horizontal row of skeleton cards.
class AfriSkeletonRow extends StatelessWidget {
  const AfriSkeletonRow({this.itemCount = 3, this.spacing = 12, super.key});

  final int itemCount;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AfriComponentSizes.skeletonRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (context, index) => SizedBox(width: spacing),
        itemBuilder: (context, index) => const AfriSkeleton.listCard(),
      ),
    );
  }
}
