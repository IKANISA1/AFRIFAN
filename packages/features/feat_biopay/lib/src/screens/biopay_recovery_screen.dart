import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_recovery_args.dart';

/// BioPay Recovery — action screen for auth / device issues.
class BioPayRecoveryScreen extends StatelessWidget {
  const BioPayRecoveryScreen({required this.args, super.key});

  final BioPayRecoveryArgs args;

  @override
  Widget build(BuildContext context) {
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
                    color: ColorTokens.warning.withValues(alpha: 0.14),
                  ),
                  child: const Icon(
                    AfriIcons.lock,
                    size: 44,
                    color: ColorTokens.warning,
                  ),
                ),

                const SizedBox(height: SpacingTokens.spacing6),

                Text(
                  args.title,
                  style: TypographyTokens.headlineLarge(),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: SpacingTokens.spacing3),

                Text(
                  args.message,
                  style: TypographyTokens.bodyMedium(),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 4),

                // Primary CTA
                AfriButton(
                  label: args.primaryLabel,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.go(args.primaryRoute);
                  },
                  fullWidth: true,
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
