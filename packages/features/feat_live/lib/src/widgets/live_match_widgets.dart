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

/// Displays a team logo from a hotlinked URL, falling back to
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

    return Semantics(
      label: '$label team logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: ColorTokens.onDarkHairline,
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
                  semanticLabel: '$label team logo',
                  errorBuilder: (_, __, ___) =>
                      _AbbreviationFallback(label: label, size: size),
                  loadingBuilder: (_, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return AfriLoadingIndicator(
                      size: size * 0.3,
                      strokeWidth: 1.5,
                      color: ColorTokens.onDarkSoft,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    );
                  },
                ),
              )
            : _AbbreviationFallback(label: label, size: size),
      ),
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
        style: TypographyTokens.monolithFont(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: ColorTokens.onDark,
        ),
      ),
    );
  }
}

/// Small inline team logo for use in event rows, standings, etc.
class TeamLogoInline extends StatelessWidget {
  const TeamLogoInline({
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
    final semanticLabel = '${fallbackLabel ?? 'Team'} logo';

    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return Semantics(
        label: semanticLabel,
        image: true,
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            logoUrl!,
            fit: BoxFit.contain,
            semanticLabel: semanticLabel,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        ),
      );
    }
    return Semantics(label: semanticLabel, image: true, child: _fallback());
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ColorTokens.onDarkHairline,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      alignment: Alignment.center,
      child: Text(
        (fallbackLabel ?? '?').substring(0, 1).toUpperCase(),
        style: TypographyTokens.utilityFont(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
          color: ColorTokens.onDarkSubtle,
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
    final eventVisual = _iconForType(eventType);
    return Semantics(
      label: 'Match event: ${eventVisual.label}',
      image: true,
      child: Container(
        width: size + 8,
        height: size + 8,
        decoration: BoxDecoration(
          color: eventVisual.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(ShapeTokens.radiusSm),
        ),
        alignment: Alignment.center,
        child: Icon(
          eventVisual.icon,
          size: size * 0.7,
          color: eventVisual.color,
        ),
      ),
    );
  }

  _MatchEventVisual _iconForType(String type) {
    return switch (type.toLowerCase()) {
      'goal' => const _MatchEventVisual(
        icon: AfriIcons.fanzone,
        color: ColorTokens.success,
        label: 'goal',
      ),
      'card' => const _MatchEventVisual(
        icon: AfriIcons.warning,
        color: ColorTokens.error,
        label: 'card',
      ),
      'substitution' || 'subst' => const _MatchEventVisual(
        icon: AfriIcons.versus,
        color: ColorTokens.info,
        label: 'substitution',
      ),
      'var' => const _MatchEventVisual(
        icon: AfriIcons.visibility,
        color: ColorTokens.warning,
        label: 'VAR review',
      ),
      _ => const _MatchEventVisual(
        icon: AfriIcons.statusInfo,
        color: ColorTokens.onDarkSubtle,
        label: 'update',
      ),
    };
  }
}

class _MatchEventVisual {
  const _MatchEventVisual({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}

class LiveStatBox extends StatelessWidget {
  const LiveStatBox({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MergeSemantics(
        child: Semantics(
          label: '$label $value',
          child: AfriPanelCard(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing4,
              vertical: SpacingTokens.spacing4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onDarkFaint,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  value,
                  style: TypographyTokens.metricValue(
                    ColorTokens.onDark,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
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
    return AfriSurfaceCard(
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
                Text(title, style: TypographyTokens.titleSmall()),
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
