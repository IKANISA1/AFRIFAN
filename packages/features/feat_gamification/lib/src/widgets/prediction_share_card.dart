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
    } else if (data.status == PredictionStatus.pending) {
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

/// A single, read-only preview of the text summary sent to the share sheet.
class PredictionShareCard extends StatelessWidget {
  const PredictionShareCard({super.key, required this.data});

  final PredictionShareData data;

  String _statusLabel(BuildContext context) => switch (data.status) {
    PredictionStatus.won => context.afriL10n.gameWon,
    PredictionStatus.lost => context.afriL10n.gameLost,
    PredictionStatus.cancelled => context.afriL10n.gameCancelled,
    PredictionStatus.void_ => context.afriL10n.gameVoid,
    _ => context.afriL10n.gamePendingUpper,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final statusColor = switch (data.status) {
      PredictionStatus.won => ColorTokens.success,
      PredictionStatus.lost => ColorTokens.error,
      _ => ColorTokens.onSurfaceVariant,
    };
    final selection = predictionSelectionLabel(
      selection: data.selectedOutcome,
      homeTeam: data.homeTeam,
      awayTeam: data.awayTeam,
    );
    final pointsLabel = data.status == PredictionStatus.won
        ? l10n.gameEarnedUpper
        : l10n.gamePotentialUpper;
    final points = data.status == PredictionStatus.won
        ? data.fetEarned
        : data.fetPotential;
    final showPoints =
        data.status == PredictionStatus.won ||
        data.status == PredictionStatus.pending;

    return Container(
      key: const ValueKey<String>('prediction-share-preview'),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: ShapeTokens.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.competitionName.trim().isNotEmpty) ...[
            Text(
              data.competitionName,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _ShareTeam(name: data.homeTeam)),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing3,
                ),
                child: Text(
                  data.homeScore != null && data.awayScore != null
                      ? '${data.homeScore}–${data.awayScore}'
                      : l10n.gameVsUpper,
                  style: largeText
                      ? TypographyTokens.titleLarge()
                      : TypographyTokens.headlineMedium(),
                ),
              ),
              Expanded(child: _ShareTeam(name: data.awayTeam)),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text(
            _statusLabel(context),
            textAlign: TextAlign.center,
            style: TypographyTokens.labelMedium(statusColor),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          AfriDivider(color: ColorTokens.outlineVariant),
          const SizedBox(height: SpacingTokens.spacing5),
          Text(
            l10n.gameShareYourPick,
            style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(selection, style: TypographyTokens.headlineMedium()),
          if (data.marketName.trim().isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              data.marketName,
              style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
            ),
          ],
          if (showPoints) ...[
            const SizedBox(height: SpacingTokens.spacing5),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: SpacingTokens.spacing3,
              runSpacing: SpacingTokens.spacing2,
              children: [
                Text(pointsLabel, style: TypographyTokens.bodyMedium()),
                Text(
                  '+$points ${l10n.gameFet}',
                  style: TypographyTokens.titleLarge(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ShareTeam extends StatelessWidget {
  const _ShareTeam({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Semantics(
    label: name,
    excludeSemantics: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AfriTeamCrest(name: name, size: SizeTokens.iconXl),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          teamInitials(name),
          textAlign: TextAlign.center,
          style: TypographyTokens.titleLarge(),
        ),
      ],
    ),
  );
}
