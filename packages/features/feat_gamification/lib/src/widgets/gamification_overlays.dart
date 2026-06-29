import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// §2.4 LOCKED — no hardcoded tier names or perk descriptions.
/// All display values are passed as parameters from the caller (DB-sourced).
Future<void> showXpLevelUpModal(
  BuildContext context, {
  required String tierName,
  String perksText = '',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: ColorTokens.scrim,
    builder: (context) {
      return AfriDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LEVEL UP!',
              style: TypographyTokens.displayMedium().copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              tierName.toUpperCase(),
              style: TypographyTokens.headlineLarge(
                ColorTokens.clubAccent,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
            if (perksText.isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                perksText,
                textAlign: TextAlign.center,
                style: TypographyTokens.bodyMedium(),
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing4),
            AfriButton(
              label: 'Awesome',
              fullWidth: true,
              onTap: () => context.pop(),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showBadgeEarnedModal(
  BuildContext context, {
  required String badgeName,
  required String description,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: ColorTokens.scrim,
    builder: (context) {
      return AfriDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: SpacingTokens.spacing20 + SpacingTokens.spacing2,
              height: SpacingTokens.spacing20 + SpacingTokens.spacing2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorTokens.clubAccent.withValues(alpha: 0.16),
              ),
              child: Icon(
                AfriIcons.premium,
                color: ColorTokens.clubAccent,
                size: SpacingTokens.spacing10 + SpacingTokens.spacing1,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              badgeName,
              style: TypographyTokens.headlineLarge().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriButton(
              label: 'Keep going',
              fullWidth: true,
              onTap: () => context.pop(),
            ),
          ],
        ),
      );
    },
  );
}
