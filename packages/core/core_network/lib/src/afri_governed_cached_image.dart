import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import 'afri_image_cache_manager.dart';

/// Rights-gated remote media with stable geometry and bounded disk/memory
/// decoding.
///
/// A URL alone is never treated as proof of usage rights. The caller must pass
/// both an affirmative [rightsApproved] value and a stable [provenanceId].
/// Otherwise the underlying governed image fails closed without resolving the
/// remote provider.
class AfriGovernedCachedImage extends StatelessWidget {
  const AfriGovernedCachedImage({
    required this.imageUrl,
    required this.semanticLabel,
    required this.provenanceId,
    required this.rightsApproved,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius = ShapeTokens.radiusMd,
    this.placeholder,
    this.errorFallback,
    super.key,
  }) : assert(provenanceId != ''),
       assert(width == null || width > 0),
       assert(height == null || height > 0);

  final String? imageUrl;
  final String semanticLabel;
  final String provenanceId;
  final bool rightsApproved;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double borderRadius;
  final Widget? placeholder;
  final Widget? errorFallback;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = width ?? _boundedDimension(constraints.maxWidth);
        final resolvedHeight =
            height ?? _boundedDimension(constraints.maxHeight);
        final normalizedUrl = imageUrl?.trim();
        final canResolve =
            rightsApproved && normalizedUrl != null && normalizedUrl.isNotEmpty;
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = (resolvedWidth * pixelRatio).ceil();
        final cacheHeight = (resolvedHeight * pixelRatio).ceil();

        return AfriGovernedImage(
          image: canResolve
              ? CachedNetworkImageProvider(
                  normalizedUrl,
                  cacheManager: AfriImageCacheManager.instance,
                  maxWidth: cacheWidth,
                  maxHeight: cacheHeight,
                )
              : null,
          width: resolvedWidth,
          height: resolvedHeight,
          semanticLabel: semanticLabel,
          provenanceId: provenanceId,
          rightsApproved: canResolve,
          fit: fit,
          alignment: alignment,
          borderRadius: borderRadius,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          placeholder: placeholder,
          errorFallback: errorFallback,
        );
      },
    );
  }

  static double _boundedDimension(double value) {
    if (value.isFinite && value > 0) return value;
    return 320;
  }
}
