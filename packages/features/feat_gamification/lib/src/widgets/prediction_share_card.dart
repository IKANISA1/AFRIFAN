import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/prediction_models.dart';

class PredictionShareData {
  const PredictionShareData({
    required this.competitionName,
    required this.homeTeam,
    required this.homeTeamShort,
    required this.awayTeam,
    required this.awayTeamShort,
    required this.marketName,
    required this.selectedOutcome,
    required this.status,
    required this.fetPotential,
    required this.fetEarned,
    this.homeScore,
    this.awayScore,
  });

  final String competitionName;
  final String homeTeam;
  final String homeTeamShort;
  final String awayTeam;
  final String awayTeamShort;
  final String marketName;
  final String selectedOutcome;
  final PredictionStatus status;
  final int fetPotential;
  final int fetEarned;
  final int? homeScore;
  final int? awayScore;

  factory PredictionShareData.fromPrediction(UserPrediction prediction) {
    return PredictionShareData(
      competitionName: prediction.competitionName,
      homeTeam: prediction.homeTeam,
      homeTeamShort: prediction.homeTeamShort,
      awayTeam: prediction.awayTeam,
      awayTeamShort: prediction.awayTeamShort,
      marketName: prediction.marketName,
      selectedOutcome: prediction.selectedOutcome,
      status: prediction.status,
      fetPotential: prediction.fetPotential,
      fetEarned: prediction.fetEarned,
      homeScore: prediction.homeScore,
      awayScore: prediction.awayScore,
    );
  }

  factory PredictionShareData.fromDetail(PredictionDetail detail) {
    return PredictionShareData(
      competitionName: detail.competitionName,
      homeTeam: detail.homeTeam,
      homeTeamShort: detail.homeTeamShort,
      awayTeam: detail.awayTeam,
      awayTeamShort: detail.awayTeamShort,
      marketName: detail.marketName,
      selectedOutcome: detail.selectedOutcome,
      status: detail.status,
      fetPotential: detail.fetPotential,
      fetEarned: detail.fetEarned,
      homeScore: detail.homeScore,
      awayScore: detail.awayScore,
    );
  }
}

class PredictionShareService {
  const PredictionShareService._();

  static Future<void> share({
    required PredictionShareData data,
    required BuildContext context,
  }) async {
    HapticFeedback.lightImpact();
    await SharePlus.instance.share(
      ShareParams(text: _buildShareText(data), title: 'FANZONE Prediction'),
    );
  }

  static Future<void> copy({
    required PredictionShareData data,
    required BuildContext context,
  }) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: _buildShareText(data)));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share text copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _buildShareText(PredictionShareData data) {
    final buffer = StringBuffer();
    final emoji = switch (data.status) {
      PredictionStatus.won => '✅',
      PredictionStatus.lost => '❌',
      PredictionStatus.cancelled => '🚫',
      PredictionStatus.void_ => '⚪',
      _ => '⏳',
    };

    buffer.writeln('$emoji ${data.homeTeam} vs ${data.awayTeam}');
    if (data.homeScore != null && data.awayScore != null) {
      buffer.writeln('⚽ Final: ${data.homeScore}-${data.awayScore}');
    }
    buffer.writeln(
      '🎯 ${data.marketName}: ${data.selectedOutcome.toUpperCase()}',
    );
    if (data.status == PredictionStatus.won) {
      buffer.writeln('💰 Earned: +${data.fetEarned} FET');
    } else {
      buffer.writeln('🔮 Potential: +${data.fetPotential} FET');
    }
    buffer.writeln();
    buffer.writeln('🏟️ ${data.competitionName}');
    buffer.write('#FANZONE #AFRICLUB');
    return buffer.toString();
  }
}

class PredictionShareCard extends StatelessWidget {
  const PredictionShareCard({super.key, required this.data});

  final PredictionShareData data;

  Color _statusColor() {
    return switch (data.status) {
      PredictionStatus.won => ColorTokens.success,
      PredictionStatus.lost => ColorTokens.error,
      _ => ColorTokens.clubAccent,
    };
  }

  String _statusLabel() {
    return switch (data.status) {
      PredictionStatus.won => 'WON',
      PredictionStatus.lost => 'LOST',
      PredictionStatus.cancelled => 'CANCELLED',
      PredictionStatus.void_ => 'VOID',
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
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      padding: const EdgeInsets.all(SpacingTokens.spacing5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  data.competitionName.toUpperCase(),
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
          Center(
            child: Column(
              children: [
                Text(
                  data.homeTeamShort.toUpperCase(),
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
                    data.homeScore != null && data.awayScore != null
                        ? '${data.homeScore} - ${data.awayScore}'
                        : 'VS',
                    style: TypographyTokens.monolithFont(
                      fontSize: data.homeScore != null ? 20 : 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  data.awayTeamShort.toUpperCase(),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _ShareMetric(
                  label: 'MARKET',
                  value: data.marketName.toUpperCase(),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: _ShareMetric(
                  label: 'PICK',
                  value: data.selectedOutcome.toUpperCase(),
                  accent: true,
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: _ShareMetric(
                  label: data.status == PredictionStatus.won
                      ? 'EARNED'
                      : 'POTENTIAL',
                  value: data.status == PredictionStatus.won
                      ? '+${data.fetEarned}'
                      : '+${data.fetPotential}',
                  accent: data.status == PredictionStatus.won,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Center(
            child: Text(
              'FANZONE · PREDICT. EARN. REPEAT.',
              style: TypographyTokens.editorialFont(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: ColorTokens.onSurfaceVariant,
                letterSpacing: 1.2,
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TypographyTokens.monolithFont(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: accent ? ColorTokens.clubAccent : ColorTokens.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TypographyTokens.editorialFont(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: ColorTokens.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
