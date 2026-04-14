import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hasBiopay = ClubConfigScope.maybeOf(context)?.hasBiopay ?? false;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SpacingTokens.spacing8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'FACE ID PAYMENT ROUTE',
                style: TypographyTokens.headlineLarge(),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                'Mobile money numbers and merchant codes are not linked at the account level anymore. Save a payment route only while enrolling Face ID.',
                style: TypographyTokens.bodyLarge().copyWith(
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                'QR codes and NFC taps now ask for the MoMo number or code manually each time you generate them.',
                style: TypographyTokens.bodyMedium(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing8),
              Container(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                decoration: BoxDecoration(
                  color: ColorTokens.surface,
                  borderRadius: ShapeTokens.cardRadius,
                  border: BorderTokens.ghost(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use Face ID enrollment when you want one saved route tied to your face.',
                      style: TypographyTokens.labelLarge(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Text(
                      'That saved route is used only for Face ID payments. It is not required for tickets, membership, QR, NFC, or other app features.',
                      style: TypographyTokens.bodyMedium(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing8),
              ClaymorphicButton(
                label: hasBiopay ? 'Open Face ID setup' : 'Back to Settings',
                preserveCase: true,
                width: double.infinity,
                onPressed: () =>
                    context.go(hasBiopay ? '/biopay/register' : '/settings'),
              ),
              if (hasBiopay) ...[
                const SizedBox(height: SpacingTokens.spacing4),
                TextButton(
                  onPressed: () => context.go('/settings'),
                  child: Text(
                    'Back to Settings',
                    style: TypographyTokens.labelLarge().copyWith(
                      color: ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
