import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Renders the footer for the BioPay Scan Screen, primarily handling
/// error states and manual camera initialization triggers.
class BioPayScanFooter extends StatelessWidget {
  const BioPayScanFooter({
    required this.isCameraReady,
    this.errorMessage,
    this.onEnableCamera,
    super.key,
  });

  final bool isCameraReady;
  final String? errorMessage;
  final VoidCallback? onEnableCamera;

  @override
  Widget build(BuildContext context) {
    if (!isCameraReady) {
      return Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onEnableCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorTokens.surfaceContainerHighest,
                  foregroundColor: ColorTokens.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusXl),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Enable Camera',
                  style: TypographyTokens.labelLarge().copyWith(
                    color: ColorTokens.onSurface,
                  ),
                ),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                errorMessage!,
                style: TypographyTokens.bodySmall().copyWith(
                  color: ColorTokens.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        child: Text(
          errorMessage!,
          style: TypographyTokens.bodySmall().copyWith(
            color: ColorTokens.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
