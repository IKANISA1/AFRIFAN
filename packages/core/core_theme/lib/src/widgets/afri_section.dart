import 'dart:ui';
import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Unified section wrapper — title + optional trailing action + child.
///
/// Intentionally has **no subtitle** to enforce conciseness.
/// Use instead of ad-hoc `_Section` / `_SectionCard` private classes.
///
/// ```dart
/// AfriSection(
///   title: 'Shortcuts',
///   trailing: AfriIconButton(icon: AfriIcons.forward, onTap: onSeeAll),
///   child: QuickActionsGrid(),
/// )
/// ```
class AfriSection extends StatelessWidget {
  const AfriSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.trailingLabel,
    this.onTrailingTap,
    this.padding,
  });

  final String title;
  final Widget child;

  /// Trailing widget (e.g. icon button). Takes priority over [trailingLabel].
  final Widget? trailing;

  /// A short text link shown as trailing action (e.g. "See all").
  /// Requires [onTrailingTap].
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    Widget? trailingWidget = trailing;
    if (trailingWidget == null &&
        trailingLabel != null &&
        onTrailingTap != null) {
      trailingWidget = GestureDetector(
        onTap: onTrailingTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: SpacingTokens.spacing1,
            horizontal: SpacingTokens.spacing2,
          ),
          child: Text(trailingLabel!, style: TypographyTokens.inlineAction()),
        ),
      );
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: TypographyTokens.sectionTitle()),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: SpacingTokens.spacing3),
                trailingWidget,
              ],
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          child,
        ],
      ),
    );
  }
}

/// Card-wrapped section — same as [AfriSection] but wraps child in a
/// card surface. Use for grouped content that needs visual containment.
class AfriSectionCard extends StatelessWidget {
  const AfriSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    Widget? trailingWidget = trailing;
    if (trailingWidget == null &&
        trailingLabel != null &&
        onTrailingTap != null) {
      trailingWidget = GestureDetector(
        onTap: onTrailingTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: SpacingTokens.spacing1,
            horizontal: SpacingTokens.spacing2,
          ),
          child: Text(trailingLabel!, style: TypographyTokens.inlineAction()),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: ColorTokens.glassBlurSigma / 2,
          sigmaY: ColorTokens.glassBlurSigma / 2,
        ),
        child: Container(
          padding: const EdgeInsets.all(SpacingTokens.cardPadding),
          decoration: BoxDecoration(
            color: ColorTokens.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ColorTokens.ghostBorder, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: TypographyTokens.sectionTitle()),
                  ),
                  if (trailingWidget != null) ...[
                    const SizedBox(width: SpacingTokens.spacing3),
                    trailingWidget,
                  ],
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
