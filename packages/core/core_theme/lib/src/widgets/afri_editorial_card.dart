import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_press_feedback.dart';

/// LIVE-030's photograph and quiet content panel, using published club media.
/// Content grows with text size; failed/missing media never becomes fake art.
class AfriEditorialCard extends StatelessWidget {
  const AfriEditorialCard({
    super.key,
    required this.child,
    this.imageUrl,
    this.imageProvenanceId,
    this.imageRightsApproved = false,
    this.imageLabel,
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.center,
    this.imageAspectRatio = 16 / 10,
    this.onTap,
    this.lightSurface = false,
    this.semanticsLabel,
  });

  final bool lightSurface;
  final bool imageRightsApproved;
  final String? imageProvenanceId;
  final Widget child;
  final String? imageUrl, imageLabel, semanticsLabel;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  final double imageAspectRatio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(imageUrl ?? '');
    final hasImage =
        imageRightsApproved &&
        (imageProvenanceId?.trim().isNotEmpty ?? false) &&
        uri?.scheme == 'https' &&
        uri!.host.isNotEmpty &&
        uri.userInfo.isEmpty;
    return Material(
      color: lightSurface
          ? ColorTokens.discoveryControl
          : ColorTokens.discoverySurface,
      borderRadius: ShapeTokens.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: AfriPressFeedback(
        onTap: onTap,
        semanticsLabel: semanticsLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage)
              Image.network(
                imageUrl!,
                width: double.infinity,
                height: null,
                fit: imageFit,
                alignment: imageAlignment,
                cacheWidth: 1080,
                semanticLabel: imageLabel,
                frameBuilder: (_, image, frame, synchronous) =>
                    AspectRatio(aspectRatio: imageAspectRatio, child: image),
                // A compact text card remains usable when photography fails.
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing4),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
