import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Skeleton loading state for the Shop product grid.
class ShopLoadingSkeleton extends StatelessWidget {
  const ShopLoadingSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6),
      child: Column(
        children: List.generate(itemCount, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: ShapeTokens.cardRadius,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 1200.ms,
                      color: ColorTokens.surfaceContainerHigh,
                    ),
                const SizedBox(height: SpacingTokens.spacing3),
                Container(
                      height: 22,
                      width: 200,
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          ShapeTokens.radiusSm,
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 1200.ms,
                      delay: 100.ms,
                      color: ColorTokens.surfaceContainerHigh,
                    ),
                const SizedBox(height: SpacingTokens.spacing2),
                Container(
                      height: 18,
                      width: 100,
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          ShapeTokens.radiusSm,
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 1200.ms,
                      delay: 200.ms,
                      color: ColorTokens.surfaceContainerHigh,
                    ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
