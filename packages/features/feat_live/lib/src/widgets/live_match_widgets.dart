import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

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

class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
        border: BorderTokens.ghost(),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Display',
          fontSize: 24,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: Colors.white,
        ),
      ),
    );
  }
}

class LiveStatBox extends StatelessWidget {
  const LiveStatBox({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: EliteCard(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing4,
          vertical: SpacingTokens.spacing4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white38,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontFamily: 'Display',
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ColorTokens.clubAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
            ),
            alignment: Alignment.center,
            child: Text(
              minute,
              style: TypographyTokens.labelMedium(ColorTokens.clubAccent),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TypographyTokens.titleSmall(),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    body,
                    style: TypographyTokens.bodySmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
