import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_skeleton.dart';

enum AfriGovernedImageState {
  ready,
  loading,
  error,
  empty,
  offline,
  permissionDenied,
  skeleton,
}

/// Stable, privacy-aware image surface with explicit rights provenance.
///
/// Unapproved media fails closed and is never resolved. The provenance ID is
/// intentionally metadata rather than visible copy; evidence tooling can
/// associate it with a source/rights register without exposing private URLs.
class AfriGovernedImage extends StatelessWidget {
  const AfriGovernedImage({
    this.image,
    required this.width,
    required this.height,
    required this.semanticLabel,
    required this.provenanceId,
    required this.rightsApproved,
    this.state = AfriGovernedImageState.ready,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius = ShapeTokens.radiusMd,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorFallback,
    super.key,
  }) : assert(
         state != AfriGovernedImageState.ready ||
             !rightsApproved ||
             image != null,
       ),
       assert(width > 0),
       assert(height > 0),
       assert(semanticLabel != ''),
       assert(provenanceId != '');

  /// The image provider is optional only when [rightsApproved] is false.
  ///
  /// This lets callers fail closed without creating a placeholder provider
  /// that could accidentally resolve an unapproved URL or asset.
  final ImageProvider? image;
  final double width;
  final double height;
  final String semanticLabel;
  final String provenanceId;
  final bool rightsApproved;
  final AfriGovernedImageState state;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double borderRadius;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? placeholder;
  final Widget? errorFallback;

  @override
  Widget build(BuildContext context) {
    final effectiveState = rightsApproved
        ? state
        : AfriGovernedImageState.error;
    final fallback =
        errorFallback ??
        _MediaFallback(label: semanticLabel, state: effectiveState);
    final skeleton =
        placeholder ??
        AfriSkeleton(width: width, height: height, borderRadius: borderRadius);
    final child = switch (effectiveState) {
      AfriGovernedImageState.ready => Image(
        image: ResizeImage.resizeIfNeeded(cacheWidth, cacheHeight, image!),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        semanticLabel: semanticLabel,
        excludeFromSemantics: false,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return skeleton;
        },
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
      AfriGovernedImageState.loading ||
      AfriGovernedImageState.skeleton => skeleton,
      AfriGovernedImageState.error ||
      AfriGovernedImageState.empty ||
      AfriGovernedImageState.offline ||
      AfriGovernedImageState.permissionDenied => fallback,
    };

    return SizedBox(
      key: const ValueKey('afri-governed-image-surface'),
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.label, required this.state});

  final String label;
  final AfriGovernedImageState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final message = switch (state) {
      AfriGovernedImageState.empty => 'No media available',
      AfriGovernedImageState.offline => 'Media unavailable offline',
      AfriGovernedImageState.permissionDenied => 'Permission required',
      _ => 'Media unavailable',
    };
    return Semantics(
      container: true,
      image: true,
      label: state == AfriGovernedImageState.error
          ? '$label unavailable'
          : '$label. $message',
      child: ColoredBox(
        color: colors.cardSurface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  AfriIcons.mediaUnavailable,
                  color: colors.secondaryText,
                ),
              ),
              Text(
                message,
                style: TypographyTokens.labelMedium(colors.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
