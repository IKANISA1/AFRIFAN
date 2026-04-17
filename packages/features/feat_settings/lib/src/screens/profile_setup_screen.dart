import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                'PUBLIC CONTRIBUTION ROUTES',
                style: TypographyTokens.headlineLarge(),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                'Contribution routes now belong to admin-managed fan clubs, team projects, and communities.',
                style: TypographyTokens.bodyLarge().copyWith(
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                'Every public initiative uses its own dedicated MoMo code. Users support admin-published routes only and do not manage their own supporter pools.',
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
                      'Use the contribute section to support the current public initiatives.',
                      style: TypographyTokens.labelLarge(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Text(
                      'Fan clubs, team projects, and communities are created centrally from the admin panel, with contribution collection handled through dedicated MoMo codes.',
                      style: TypographyTokens.bodyMedium(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing8),
              AfriButton(
                label: 'Open contributions',
                fullWidth: true,
                onTap: () => context.go('/contribute'),
              ),
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
          ),
        ),
      ),
    );
  }
}
