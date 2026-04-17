import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

class MatchIntelEvent {
  const MatchIntelEvent({
    required this.minute,
    required this.title,
    required this.body,
    this.eventType,
    this.teamSide,
  });

  final String minute;
  final String title;
  final String body;
  final String? eventType;
  final String? teamSide; // 'home' or 'away'
}

/// Displays a team crest from a hotlinked URL, falling back to
/// a text abbreviation badge when the logo is unavailable.
class TeamBadge extends StatelessWidget {
  const TeamBadge({
    super.key,
    required this.label,
    this.logoUrl,
    this.size = 64,
  });

  final String label;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
        border: BorderTokens.ghost(),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: Image.network(
                logoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _AbbreviationFallback(
                  label: label,
                  size: size,
                ),
                loadingBuilder: (_, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: size * 0.3,
                      height: size * 0.3,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white24,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              ),
            )
          : _AbbreviationFallback(label: label, size: size),
    );
  }
}

class _AbbreviationFallback extends StatelessWidget {
  const _AbbreviationFallback({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Display',
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Small inline team crest for use in event rows, standings, etc.
class TeamCrestInline extends StatelessWidget {
  const TeamCrestInline({
    super.key,
    this.logoUrl,
    this.fallbackLabel,
    this.size = 20,
  });

  final String? logoUrl;
  final String? fallbackLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.network(
          logoUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      alignment: Alignment.center,
      child: Text(
        (fallbackLabel ?? '?').substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
          color: Colors.white54,
        ),
      ),
    );
  }
}

/// Icon badge for match events (goals, cards, subs, VAR).
class MatchEventIcon extends StatelessWidget {
  const MatchEventIcon({super.key, required this.eventType, this.size = 24});

  final String eventType;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconForType(eventType);
    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.7, color: color),
    );
  }

  (IconData, Color) _iconForType(String type) {
    return switch (type.toLowerCase()) {
      'goal' => (Icons.sports_soccer, const Color(0xFF4CAF50)),
      'card' => (Icons.style, const Color(0xFFF44336)),
      'substitution' || 'subst' => (Icons.swap_horiz, const Color(0xFF2196F3)),
      'var' => (Icons.ondemand_video, const Color(0xFFFF9800)),
      _ => (Icons.info_outline, Colors.white54),
    };
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
    this.eventType,
  });

  final String minute;
  final String title;
  final String body;
  final String? eventType;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eventType != null && eventType!.isNotEmpty)
            MatchEventIcon(eventType: eventType!)
          else
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
          if (minute.isNotEmpty && eventType != null) ...[
            const SizedBox(width: SpacingTokens.spacing2),
            Text(
              "$minute'",
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

