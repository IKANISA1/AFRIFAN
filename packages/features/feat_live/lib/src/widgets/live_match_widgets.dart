import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Data class for a match event entry (goal, card, etc.).
class MatchIntelEvent {
  const MatchIntelEvent({
    required this.minute,
    required this.title,
    required this.body,
  });

  final String minute;
  final String title;
  final String body;
}

/// Abbreviated team badge (e.g. "RAY" or "APR").
class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: BorderTokens.ghost(),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TypographyTokens.titleLarge().copyWith(
          color: ColorTokens.onSurface,
        ),
      ),
    );
  }
}

/// Stat summary box (possession, shots, corners).
class LiveStatBox extends StatelessWidget {
  const LiveStatBox({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClayCard(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing3,
          vertical: SpacingTokens.spacing4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TypographyTokens.labelSmall()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              value,
              style: TypographyTokens.headlineMedium().copyWith(
                color: ColorTokens.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Commentary card showing match intel events with minute, title, and body.
class CommentaryCard extends StatelessWidget {
  const CommentaryCard({
    super.key,
    required this.minute,
    required this.title,
    required this.body,
  });

  final String minute;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            minute,
            style: TypographyTokens.headlineSmall().copyWith(
              color: ColorTokens.clubAccent,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TypographyTokens.bodyLarge()),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(body, style: TypographyTokens.bodyMedium()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
