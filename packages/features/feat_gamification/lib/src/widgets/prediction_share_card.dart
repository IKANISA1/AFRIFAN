import 'dart:async';

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
    unawaited(HapticFeedback.lightImpact());
    await SharePlus.instance.share(
      ShareParams(text: _buildShareText(data), title: 'AFRICLUB Pick'),
    );
  }

  static Future<void> copy({
    required PredictionShareData data,
    required BuildContext context,
  }) async {
    unawaited(HapticFeedback.lightImpact());
    await Clipboard.setData(ClipboardData(text: _buildShareText(data)));
    if (!context.mounted) {
      return;
    }
    AfriToast.success(context, 'Share text copied to clipboard.');
  }

  static String _buildShareText(PredictionShareData data) {
    final buffer = StringBuffer();
    final statusLabel = switch (data.status) {
      PredictionStatus.won => 'Won',
      PredictionStatus.lost => 'Lost',
      PredictionStatus.cancelled => 'Cancelled',
      PredictionStatus.void_ => 'Void',
      _ => 'Pending',
    };

    buffer.writeln(
      '$statusLabel: ${data.homeTeamShort.toUpperCase()} vs ${data.awayTeamShort.toUpperCase()}',
    );
    if (data.homeScore != null && data.awayScore != null) {
      buffer.writeln('Final score: ${data.homeScore}-${data.awayScore}');
    }
    buffer.writeln('${data.marketName}: ${data.selectedOutcome.toUpperCase()}');
    if (data.status == PredictionStatus.won) {
      buffer.writeln('Earned: +${data.fetEarned} pts');
    } else {
      buffer.writeln('Potential: +${data.fetPotential} pts');
    }
    buffer.writeln();
    buffer.writeln(data.competitionName);
    buffer.write('#AFRICLUB');
    final brandHashtag = _buildBrandHashtag();
    if (brandHashtag != null) {
      buffer.write(' #$brandHashtag');
    }
    return buffer.toString();
  }

  static String? _buildBrandHashtag() {
    final sanitized = RuntimeBranding.displayAppName.replaceAll(
      RegExp(r'[^A-Za-z0-9]+'),
      '',
    );
    if (sanitized.isEmpty) {
      return null;
    }
    return sanitized;
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
        gradient: ColorTokens.universalSurfaceGradient(
          from: ColorTokens.surfaceContainerLow,
          to: color.withValues(alpha: 0.06),
        ),
        borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
        border: BorderTokens.all(
          color: color.withValues(alpha: 0.2),
          width: BorderTokens.strong,
        ),
      ),
      padding: const EdgeInsets.all(SpacingTokens.spacing5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing3,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
                ),
                child: Text(
                  data.competitionName.toUpperCase(),
                  style: TypographyTokens.labelSmall(
                    ColorTokens.clubAccent,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing3,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
                ),
                child: Text(
                  _statusLabel(),
                  style: TypographyTokens.labelSmall(
                    color,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0),
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
                  style: TypographyTokens.headlineMedium().copyWith(
                    fontWeight: FontWeight.w900,
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
                    style:
                        (data.homeScore != null
                                ? TypographyTokens.headlineSmall(color)
                                : TypographyTokens.titleSmall(color))
                            .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  data.awayTeamShort.toUpperCase(),
                  style: TypographyTokens.headlineMedium().copyWith(
                    fontWeight: FontWeight.w900,
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
              'AFRICLUB · PLAY. PICK. EARN.',
              style: TypographyTokens.labelSmall(
                ColorTokens.onSurfaceVariant,
              ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2),
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
          style: TypographyTokens.titleSmall(
            accent ? ColorTokens.clubAccent : ColorTokens.onSurface,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: SpacingTokens.spacing1),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TypographyTokens.labelSmall(
            ColorTokens.onSurfaceVariant,
          ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
      ],
    );
  }
}
