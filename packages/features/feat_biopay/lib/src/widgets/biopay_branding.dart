import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

String biopayAppName(BuildContext context) {
  return ClubConfigScope.maybeOf(context)?.appName ??
      RuntimeBranding.displayAppName;
}

String biopayClubName(BuildContext context) {
  return ClubConfigScope.maybeOf(context)?.clubName ??
      RuntimeBranding.displayClubName;
}

Color biopayPrimary(BuildContext context) {
  return ClubConfigScope.maybeOf(context)?.colors.primary ??
      Theme.of(context).colorScheme.primary;
}

Color biopaySecondary(BuildContext context) {
  return ClubConfigScope.maybeOf(context)?.colors.secondary ??
      ColorTokens.clubSecondary;
}

Color biopayAccent(BuildContext context) {
  return ClubConfigScope.maybeOf(context)?.colors.accent ??
      Theme.of(context).colorScheme.secondary;
}

List<Color> biopayGradient(BuildContext context) {
  final configGradient = ClubConfigScope.maybeOf(context)?.colors.gradient;
  if (configGradient != null && configGradient.isNotEmpty) {
    return configGradient;
  }
  return ColorTokens.clubGradient;
}

class BiopayMoodBackground extends StatelessWidget {
  const BiopayMoodBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gradient = biopayGradient(context);
    final primary = biopayPrimary(context);
    final accent = biopayAccent(context);

    return Stack(
      children: [
        GradientBackground(
          colors: [
            gradient.first,
            Color.lerp(gradient.last, ColorTokens.background, 0.55) ??
                ColorTokens.background,
            ColorTokens.background,
          ],
          child: const SizedBox.expand(),
        ),
        Positioned(
          top: -72,
          right: -48,
          child: _GlowOrb(color: primary.withValues(alpha: 0.26), size: 220),
        ),
        Positioned(
          top: 180,
          left: -84,
          child: _GlowOrb(color: accent.withValues(alpha: 0.14), size: 260),
        ),
        Positioned(
          bottom: -120,
          right: -40,
          child: _GlowOrb(color: primary.withValues(alpha: 0.16), size: 260),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class BiopayHeroCard extends StatelessWidget {
  const BiopayHeroCard({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottom,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final accent = biopayAccent(context);

    return GlassCard(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BiopayBadge(
                      icon: Icons.shield_rounded,
                      label: eyebrow,
                      tint: accent.withValues(alpha: 0.16),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    Text(
                      title,
                      style: TypographyTokens.displaySmall().copyWith(
                        height: 1.05,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: SpacingTokens.spacing3),
                      Text(
                        subtitle!,
                        style: TypographyTokens.bodyMedium().copyWith(
                          color: ColorTokens.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: SpacingTokens.spacing4),
                trailing!,
              ],
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: SpacingTokens.spacing5),
            bottom!,
          ],
        ],
      ),
    );
  }
}

class BiopayBadge extends StatelessWidget {
  const BiopayBadge({
    required this.label,
    this.icon,
    this.tint,
    this.foregroundColor,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? tint;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final foreground = foregroundColor ?? ColorTokens.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2,
      ),
      decoration: BoxDecoration(
        color: tint ?? Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: SpacingTokens.spacing2),
          ],
          Text(
            label,
            style: TypographyTokens.labelSmall().copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: size * 0.45, spreadRadius: 12),
          ],
        ),
      ),
    );
  }
}
