import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/prediction_models.dart';

/// Generates shareable text for a prediction result and triggers
/// the platform share sheet.
class PredictionShareService {
  const PredictionShareService._();

  /// Share a settled prediction result.
  static Future<void> sharePrediction({
    required UserPrediction prediction,
    required BuildContext context,
  }) async {
    HapticFeedback.lightImpact();

    final text = _buildShareText(prediction);

    await SharePlus.instance.share(
      ShareParams(text: text, title: 'My Prediction'),
    );
  }

  /// Copy prediction summary to clipboard.
  static Future<void> copyToClipboard({
    required UserPrediction prediction,
    required BuildContext context,
  }) async {
    HapticFeedback.lightImpact();

    final text = _buildShareText(prediction);
    await Clipboard.setData(ClipboardData(text: text));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prediction copied to clipboard.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static String _buildShareText(UserPrediction prediction) {
    final buffer = StringBuffer();

    // Status emoji
    final statusEmoji = switch (prediction.status) {
      PredictionStatus.won => '✅',
      PredictionStatus.lost => '❌',
      PredictionStatus.cancelled => '🚫',
      _ => '⏳',
    };

    buffer.writeln(
      '$statusEmoji ${prediction.homeTeam} vs ${prediction.awayTeam}',
    );

    // Score if available
    if (prediction.homeScore != null && prediction.awayScore != null) {
      buffer.writeln(
        '⚽ Final: ${prediction.homeScore}-${prediction.awayScore}',
      );
    }

    buffer.writeln(
      '🎯 ${prediction.marketName}: ${prediction.selectedOutcome.toUpperCase()}',
    );

    if (prediction.isWon) {
      buffer.writeln('💰 Earned: +${prediction.fetEarned} FET');
    } else if (prediction.isPending) {
      buffer.writeln('🔮 Potential: +${prediction.fetPotential} FET');
    }

    buffer.writeln();
    buffer.writeln('🏟️ ${prediction.competitionName}');
    buffer.write('#AFRICLUB #Predictions');

    return buffer.toString();
  }
}

/// Visual share card rendered inline in the prediction detail.
/// Shows the result in a premium, social-media-friendly layout.
class PredictionShareCard extends StatelessWidget {
  const PredictionShareCard({
    super.key,
    required this.prediction,
  });

  final UserPrediction prediction;

  Color _statusColor() {
    return switch (prediction.status) {
      PredictionStatus.won => ColorTokens.success,
      PredictionStatus.lost => ColorTokens.error,
      _ => ColorTokens.clubAccent,
    };
  }

  String _statusLabel() {
    return switch (prediction.status) {
      PredictionStatus.won => 'WON',
      PredictionStatus.lost => 'LOST',
      PredictionStatus.cancelled => 'CANCELLED',
      _ => 'PENDING',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorTokens.surfaceContainerLow,
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(SpacingTokens.spacing5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Competition + Status ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  prediction.competitionName.toUpperCase(),
                  style: TypographyTokens.editorialFont(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.clubAccent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(),
                  style: TypographyTokens.editorialFont(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: SpacingTokens.spacing4),

          // ── Teams ──
          Center(
            child: Column(
              children: [
                Text(
                  prediction.homeTeamShort.toUpperCase(),
                  style: TypographyTokens.monolithFont(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: ColorTokens.onSurface,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: SpacingTokens.spacing1,
                  ),
                  child: Text(
                    prediction.homeScore != null && prediction.awayScore != null
                        ? '${prediction.homeScore} - ${prediction.awayScore}'
                        : 'VS',
                    style: TypographyTokens.monolithFont(
                      fontSize: prediction.homeScore != null ? 20 : 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  prediction.awayTeamShort.toUpperCase(),
                  style: TypographyTokens.monolithFont(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: ColorTokens.onSurface,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: SpacingTokens.spacing4),

          // ── Prediction info ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ShareMetric(
                label: 'MARKET',
                value: prediction.marketName.toUpperCase(),
              ),
              const SizedBox(width: SpacingTokens.spacing4),
              _ShareMetric(
                label: 'PICK',
                value: prediction.selectedOutcome.toUpperCase(),
                accent: true,
              ),
              const SizedBox(width: SpacingTokens.spacing4),
              _ShareMetric(
                label: prediction.isWon ? 'EARNED' : 'POTENTIAL',
                value: prediction.isWon
                    ? '+${prediction.fetEarned}'
                    : '+${prediction.fetPotential}',
                accent: prediction.isWon,
              ),
            ],
          ),

          const SizedBox(height: SpacingTokens.spacing4),

          // ── Branding footer ──
          Center(
            child: Text(
              'AFRICLUB PREDICTIONS',
              style: TypographyTokens.editorialFont(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: ColorTokens.onSurfaceVariant,
                letterSpacing: 2.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareMetric extends StatelessWidget {
  const _ShareMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TypographyTokens.monolithFont(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: accent ? ColorTokens.clubAccent : ColorTokens.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TypographyTokens.editorialFont(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: ColorTokens.onSurfaceVariant,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
