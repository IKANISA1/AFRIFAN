import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../settings_actions.dart';
import '../widgets/settings_navigation_scope.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appName =
        ClubConfigScope.maybeOf(context)?.appName ??
        RuntimeBranding.displayAppName;
    final hasChannels =
        AppLinks.hasWebsite ||
        AppLinks.hasSupportWhatsApp ||
        AppLinks.hasSupportEmail;
    final canRequestExport =
        AppLinks.hasSupportWhatsApp || AppLinks.hasSupportEmail;
    return SettingsBackGuard(
      child: Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AppBar(
          title: Text(
            'HELP & SUPPORT',
            style: TypographyTokens.monolithFont(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          leading: IconButton(
            onPressed: () => closeSettingsChild(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          children: [
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MATCHDAY SUPPORT',
                    style: TypographyTokens.labelSmall(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(
                    hasChannels
                        ? 'Need help? Use the configured support channels below.'
                        : 'Support channels are not configured for this build yet.',
                    style: TypographyTokens.bodyLarge(),
                  ),
                ],
              ),
            ),
            if (AppLinks.hasWebsite) ...[
              const SizedBox(height: SpacingTokens.spacing4),
              _SupportCard(
                title: 'Official Website',
                subtitle: 'Club updates, schedules, and matchday info.',
                trailing: 'OPEN SITE',
                onTap: () async {
                  await launchExternalUri(
                    context,
                    AppLinks.websiteUri!,
                    failureMessage: 'Club website is not available yet.',
                  );
                },
              ),
            ],
            if (AppLinks.hasSupportWhatsApp) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              _SupportCard(
                title: 'WhatsApp Support',
                subtitle: 'For account, payment, and app issues.',
                trailing: AppLinks.supportWhatsApp,
                onTap: () async {
                  await launchWhatsApp(
                    context,
                    message: 'Hi, I need help with $appName.',
                    failureMessage: 'Could not open WhatsApp.',
                  );
                },
              ),
            ],
            if (AppLinks.hasSupportEmail) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              _SupportCard(
                title: 'Email Support',
                subtitle: 'Reach the support team by email.',
                trailing: AppLinks.supportEmail,
                onTap: () async {
                  await launchMailTo(
                    context,
                    email: AppLinks.supportEmail,
                    subject: '$appName support request',
                    failureMessage: 'Could not open your mail app.',
                  );
                },
              ),
            ],
            if (canRequestExport) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              _SupportCard(
                title: 'Request Data Export',
                subtitle: 'Ask support for a copy of your account data.',
                trailing: 'REQUEST',
                onTap: () async {
                  if (AppLinks.hasSupportWhatsApp) {
                    await launchWhatsApp(
                      context,
                      message:
                          'Data export request for $appName. Please send me a copy of the data stored for my account.',
                      failureMessage: 'Could not open WhatsApp.',
                    );
                    return;
                  }
                  await launchMailTo(
                    context,
                    email: AppLinks.supportEmail,
                    subject: '$appName data export request',
                    body:
                        'Please send me a copy of the data stored for my account.',
                    failureMessage: 'Could not open your mail app.',
                  );
                },
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing6),
            ClaymorphicButton(
              label: 'RETURN TO SETTINGS',
              width: double.infinity,
              onPressed: () => context.go('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TypographyTokens.monolithFont(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ColorTokens.onSurface,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(subtitle, style: TypographyTokens.bodyMedium()),
          const SizedBox(height: SpacingTokens.spacing3),
          Row(
            children: [
              Expanded(
                child: Text(
                  trailing,
                  style: TypographyTokens.bodyLarge().copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
