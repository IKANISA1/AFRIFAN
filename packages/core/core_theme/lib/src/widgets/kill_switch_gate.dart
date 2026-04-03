import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_button.dart';

/// Gate widget that blocks access when a feature's kill-switch is active.
class KillSwitchGate extends StatelessWidget {
  const KillSwitchGate({
    required this.enabled,
    required this.child,
    this.featureName,
    this.message,
    this.onBackPressed,
    super.key,
  });

  final bool enabled;
  final Widget child;
  final String? featureName;
  final String? message;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;

    final colors = context.afriSemanticColors;
    final msg =
        message ??
        '${featureName ?? 'This feature'} is temporarily unavailable.';

    return Scaffold(
      backgroundColor: colors.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.primaryText),
          onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colors.operationalSurface,
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
                ),
                child: Icon(
                  Icons.engineering_rounded,
                  size: 40,
                  color: colors.tertiaryText,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              Text(
                'Temporarily Unavailable',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.primaryText,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                msg,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.tertiaryText,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.spacing7),
              AfriButton(
                label: 'Go Back',
                onTap: onBackPressed ?? () => Navigator.of(context).pop(),
                variant: AfriButtonVariant.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
