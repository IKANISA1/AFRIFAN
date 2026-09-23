import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/prediction_models.dart';
import 'prediction_selection.dart';

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
    BuildContext? context,
  }) async {
    unawaited(HapticFeedback.lightImpact());
    final l10n = context == null
        ? lookupAfriLocalizations(const Locale('en'))
        : context.afriL10n;
    await SharePlus.instance.share(
      ShareParams(
        text: _buildShareText(data, l10n),
        title: l10n.gameShareTitle(RuntimeBranding.displayAppName),
      ),
    );
  }

  static Future<void> copy({
    required PredictionShareData data,
    BuildContext? context,
  }) async {
    unawaited(HapticFeedback.lightImpact());
    final l10n = context == null
        ? lookupAfriLocalizations(const Locale('en'))
        : context.afriL10n;
    await Clipboard.setData(ClipboardData(text: _buildShareText(data, l10n)));
    if (context == null || !context.mounted) {
      return;
    }
    AfriToast.success(context, context.afriL10n.gameShareCopied);
  }

  static String _buildShareText(
    PredictionShareData data,
    AfriLocalizations l10n,
  ) {
    final buffer = StringBuffer();
    final statusLabel = switch (data.status) {
      PredictionStatus.won => l10n.gameWon,
      PredictionStatus.lost => l10n.gameLost,
      PredictionStatus.cancelled => l10n.gameCancelled,
      PredictionStatus.void_ => l10n.gameVoid,
      _ => l10n.gamePendingUpper,
    };

    buffer.writeln(
      l10n.gameShareStatusLine(
        statusLabel,
        teamInitials(data.homeTeam),
        teamInitials(data.awayTeam),
      ),
    );
    if (data.homeScore != null && data.awayScore != null) {
      buffer.writeln(l10n.gameFinalScore(data.homeScore!, data.awayScore!));
    }
    buffer.writeln(
      l10n.gameMarketSelection(
        data.marketName,
        predictionSelectionLabel(
          selection: data.selectedOutcome,
          homeTeam: data.homeTeam,
          awayTeam: data.awayTeam,
        ),
      ),
    );
    if (data.status == PredictionStatus.won) {
      buffer.writeln(l10n.gameEarnedShare(data.fetEarned));
    } else {
      buffer.writeln(l10n.gamePotentialShare(data.fetPotential));
    }
    buffer.writeln();
    buffer.writeln(data.competitionName);
    buffer.write('#${RuntimeBranding.displayAppName.replaceAll(' ', '')}');
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

  Color _statusColor(BuildContext context) {
    return switch (data.status) {
      PredictionStatus.won => ColorTokens.success,
      PredictionStatus.lost => ColorTokens.error,
      _ => context.afriSemanticColors.accent,
    };
  }

  String _statusLabel(BuildContext context) {
    return switch (data.status) {
      PredictionStatus.won => context.afriL10n.gameWon,
      PredictionStatus.lost => context.afriL10n.gameLost,
      PredictionStatus.cancelled => context.afriL10n.gameCancelled,
      PredictionStatus.void_ => context.afriL10n.gameVoid,
      _ => context.afriL10n.gamePendingUpper,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    final accent = context.afriSemanticColors.accent;
    final accessibleAccent = ColorTokens.accessibleMetricColor(accent);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SpacingTokens.spacing3,
            runSpacing: SpacingTokens.spacing2,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing3,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
                ),
                child: Text(
                  data.competitionName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TypographyTokens.labelSmall(accessibleAccent).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: TypographyTokens.trackingNone,
                  ),
                ),
              ),
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
                  _statusLabel(context),
                  style: TypographyTokens.labelSmall(color).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: TypographyTokens.trackingNone,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriFixtureTeams(
            homeTeam: data.homeTeam,
            awayTeam: data.awayTeam,
            score: data.homeScore != null && data.awayScore != null
                ? '${data.homeScore}–${data.awayScore}'
                : null,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (largeText)
            Column(
              children: [
                _ShareMetric(
                  label: context.afriL10n.gameMarketUpper,
                  value: data.marketName,
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                _ShareMetric(
                  label: context.afriL10n.gamePickUpper,
                  value: data.selectedOutcome,
                  valueWidget: PredictionSelection(
                    selection: data.selectedOutcome,
                    homeTeam: data.homeTeam,
                    awayTeam: data.awayTeam,
                  ),
                  accent: true,
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                _ShareMetric(
                  label: data.status == PredictionStatus.won
                      ? context.afriL10n.gameEarnedUpper
                      : context.afriL10n.gamePotentialUpper,
                  value: data.status == PredictionStatus.won
                      ? '+${data.fetEarned}'
                      : '+${data.fetPotential}',
                  accent: data.status == PredictionStatus.won,
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _ShareMetric(
                    label: context.afriL10n.gameMarketUpper,
                    value: data.marketName,
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: _ShareMetric(
                    label: context.afriL10n.gamePickUpper,
                    value: data.selectedOutcome,
                    valueWidget: PredictionSelection(
                      selection: data.selectedOutcome,
                      homeTeam: data.homeTeam,
                      awayTeam: data.awayTeam,
                    ),
                    accent: true,
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: _ShareMetric(
                    label: data.status == PredictionStatus.won
                        ? context.afriL10n.gameEarnedUpper
                        : context.afriL10n.gamePotentialUpper,
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
              context.afriL10n.gameShareTagline(RuntimeBranding.displayAppName),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant)
                  .copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: TypographyTokens.trackingNone,
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
    this.valueWidget,
  });

  final Widget? valueWidget;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        valueWidget ??
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TypographyTokens.titleSmall(
                accent
                    ? ColorTokens.accessibleMetricColor(
                        context.afriSemanticColors.accent,
                      )
                    : ColorTokens.onSurface,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
        const SizedBox(height: SpacingTokens.spacing1),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant)
              .copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: TypographyTokens.trackingNone,
              ),
        ),
      ],
    );
  }
}
