import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Resolve only a team selection; totals, scorers and draw outcomes stay intact.
String? predictionSelectionTeam({
  required String selection,
  required String homeTeam,
  required String awayTeam,
}) {
  final value = selection.trim().toLowerCase();
  if (value.isEmpty) return null;
  for (final team in [homeTeam, awayTeam]) {
    if (value == team.trim().toLowerCase() ||
        value == teamInitials(team).toLowerCase() ||
        (teamAssetFor(selection) != null &&
            teamAssetFor(selection) == teamAssetFor(team))) {
      return team;
    }
  }
  return switch (value) {
    'home' => homeTeam,
    'away' => awayTeam,
    _ => null,
  };
}

String predictionSelectionLabel({
  required String selection,
  required String homeTeam,
  required String awayTeam,
}) {
  final team = predictionSelectionTeam(
    selection: selection,
    homeTeam: homeTeam,
    awayTeam: awayTeam,
  );
  return team == null ? selection : teamInitials(team);
}

class PredictionSelection extends StatelessWidget {
  const PredictionSelection({
    super.key,
    required this.selection,
    required this.homeTeam,
    required this.awayTeam,
    this.style,
  });

  final String selection, homeTeam, awayTeam;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final team = predictionSelectionTeam(
      selection: selection,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
    );
    return team == null
        ? Text(selection, style: style ?? TypographyTokens.titleSmall())
        : AfriTeamCard(name: team);
  }
}
