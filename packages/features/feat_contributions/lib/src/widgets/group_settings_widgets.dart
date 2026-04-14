import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Animated privacy pill selector for contribution group settings.
class PrivacyPill extends StatelessWidget {
  const PrivacyPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing4,
          vertical: SpacingTokens.spacing3,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: BorderTokens.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : ColorTokens.ghostBorder,
          ),
        ),
        child: Text(
          label,
          style: TypographyTokens.labelSmall().copyWith(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : ColorTokens.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Labeled text field wrapped in a GlassCard for contribution settings forms.
class ContributionInput extends StatelessWidget {
  const ContributionInput({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}

/// A sleek, inline input for grouped surface cards.
class MinimalistInputTile extends StatelessWidget {
  const MinimalistInputTile({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing4,
        vertical: SpacingTokens.spacing3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TypographyTokens.labelSmall().copyWith(
              color: ColorTokens.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TypographyTokens.bodyLarge().copyWith(
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TypographyTokens.bodyLarge().copyWith(
                color: ColorTokens.ghostBorder,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// A clean setting row with an optional trailing widget or chevron.
class MinimalistSettingTile extends StatelessWidget {
  const MinimalistSettingTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.leadingIcon,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  final String title;
  final String? subtitle;
  final IconData leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? ColorTokens.error : ColorTokens.onSurface;
    final iconColor = isDestructive
        ? ColorTokens.error
        : Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing4,
          vertical: SpacingTokens.spacing4,
        ),
        child: Row(
          children: [
            Icon(leadingIcon, color: iconColor, size: 24),
            const SizedBox(width: SpacingTokens.spacing4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TypographyTokens.bodyLarge().copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TypographyTokens.bodyMedium().copyWith(
                        color: ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: SpacingTokens.spacing3),
              trailing!,
            ] else if (onTap != null && !isDestructive) ...[
              const SizedBox(width: SpacingTokens.spacing3),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders a group of tiles connected without outer margins, separated by thin dividers.
class GroupedSurfaceCard extends StatelessWidget {
  const GroupedSurfaceCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> divided = [];
    for (var i = 0; i < children.length; i++) {
      divided.add(children[i]);
      if (i < children.length - 1) {
        divided.add(
          Divider(
            height: 1,
            thickness: 1,
            color: ColorTokens.ghostBorder.withValues(alpha: 0.15),
            indent: SpacingTokens.spacing4,
            endIndent: SpacingTokens.spacing4,
          ),
        );
      }
    }

    return GlassCard(
      animate: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: divided,
      ),
    );
  }
}
