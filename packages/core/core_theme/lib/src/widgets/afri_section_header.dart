import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Shared section header with optional supporting text or trailing action.
class AfriSectionHeader extends StatelessWidget {
  const AfriSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
    this.isPageTitle = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final bool isPageTitle;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: isPageTitle
                ? (MediaQuery.textScalerOf(context).scale(1) >= 1.5
                      ? TypographyTokens.headlineMedium()
                      : TypographyTokens.headlineLarge())
                : TypographyTokens.sectionTitle(),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            subtitle!,
            style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
          ),
        ],
      ],
    );
    return Padding(
      padding:
          padding ??
          const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (trailing != null &&
              MediaQuery.textScalerOf(context).scale(1) >= 1.5 &&
              constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: SpacingTokens.spacing1),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: subtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              if (trailing != null) ...[
                const SizedBox(width: SpacingTokens.spacing3),
                trailing!,
              ],
            ],
          );
        },
      ),
    );
  }
}
