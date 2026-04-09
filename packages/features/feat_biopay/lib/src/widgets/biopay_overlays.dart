import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showNfcPairingSheet(BuildContext context) {
  return showAfriBottomSheet<void>(
    context: context,
    builder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(
                3,
                (index) => Container(
                  width: 56 + (index * 32),
                  height: 56 + (index * 32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(
                        0xFF57D0FF,
                      ).withValues(alpha: 0.38 - (index * 0.1)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text('Waiting for Tap…', style: TypographyTokens.titleLarge()),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            'Hold phones back-to-back. Timeout in 30 seconds.',
            textAlign: TextAlign.center,
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}

class BiopayLivenessPromptOverlay extends StatelessWidget {
  const BiopayLivenessPromptOverlay({
    required this.title,
    required this.helperText,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
    super.key,
  });

  final String title;
  final String helperText;
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;

  @override
  Widget build(BuildContext context) {
    final progress = totalSteps == 0 ? 0.0 : currentStep / totalSteps;

    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GlassCard(
            animate: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ColorTokens.clubPrimary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.visibility_rounded,
                        color: ColorTokens.clubPrimary,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ColorTokens.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(helperText, style: TypographyTokens.bodyMedium()),
                const SizedBox(height: SpacingTokens.spacing4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    totalSteps,
                    (index) => Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          right: index == totalSteps - 1
                              ? 0
                              : SpacingTokens.spacing2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: SpacingTokens.spacing2,
                        ),
                        decoration: BoxDecoration(
                          color: index < currentStep
                              ? ColorTokens.clubAccent.withValues(alpha: 0.18)
                              : ColorTokens.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: index < currentStep
                                ? ColorTokens.clubAccent
                                : ColorTokens.ghostBorder,
                          ),
                        ),
                        child: Text(
                          stepLabels.length > index
                              ? stepLabels[index]
                              : '${index + 1}',
                          textAlign: TextAlign.center,
                          style: TypographyTokens.labelLarge().copyWith(
                            color: index < currentStep
                                ? ColorTokens.clubAccent
                                : ColorTokens.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                  color: ColorTokens.clubPrimary,
                  backgroundColor: ColorTokens.surfaceContainerHighest,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
