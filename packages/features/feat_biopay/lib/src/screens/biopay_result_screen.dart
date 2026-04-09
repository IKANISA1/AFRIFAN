import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_task_result.dart';

/// BioPay Result — tone-branded full-screen outcome.
class BiopayResultScreen extends StatelessWidget {
  const BiopayResultScreen({required this.args, super.key});

  final BiopayTaskResultArgs args;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final Color accentColor;
    final IconData icon;
    switch (args.tone) {
      case BiopayTaskResultTone.success:
        accentColor = ColorTokens.success;
        icon = Icons.check_circle_rounded;
      case BiopayTaskResultTone.error:
        accentColor = ColorTokens.error;
        icon = Icons.error_outline_rounded;
      case BiopayTaskResultTone.blocked:
        accentColor = ColorTokens.warning;
        icon = Icons.warning_rounded;
      case BiopayTaskResultTone.pending:
        accentColor = primaryColor;
        icon = Icons.hourglass_top_rounded;
    }

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
            ),
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.14),
                  ),
                  child: Icon(icon, size: 44, color: accentColor),
                ),

                const SizedBox(height: SpacingTokens.spacing6),

                Text(
                  args.title,
                  style: TypographyTokens.headlineLarge(),
                  textAlign: TextAlign.center,
                ),

                if (args.message.isNotEmpty) ...[
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(
                    args.message,
                    style: TypographyTokens.bodyMedium(),
                    textAlign: TextAlign.center,
                  ),
                ],

                // Amount / alias details
                if (args.alias != null || args.amount != null) ...[
                  const SizedBox(height: SpacingTokens.spacing6),
                  GlassCard(
                    child: Column(
                      children: [
                        if (args.alias != null)
                          Text(
                            args.alias!,
                            style: TypographyTokens.numericAlias(fontSize: 24),
                          ),
                        if (args.amount != null) ...[
                          const SizedBox(height: SpacingTokens.spacing3),
                          Text(
                            '${args.currencySymbol ?? ''} ${args.amount}',
                            style: TypographyTokens.displaySmall(),
                          ),
                        ],
                        if (args.maskedRecipientValue != null) ...[
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            args.maskedRecipientValue!,
                            style: TypographyTokens.bodySmall(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const Spacer(flex: 4),

                // Primary CTA
                ClaymorphicButton(
                  label: args.primaryLabel,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    context.go(args.primaryRoute);
                  },
                  width: double.infinity,
                  preserveCase: true,
                  letterSpacing: 0.6,
                ),

                // Secondary
                if (args.secondaryLabel != null &&
                    args.secondaryRoute != null) ...[
                  const SizedBox(height: SpacingTokens.spacing3),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go(args.secondaryRoute!),
                      child: Text(
                        args.secondaryLabel!,
                        style: TypographyTokens.labelLarge().copyWith(
                          color: ColorTokens.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: SpacingTokens.spacing8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
