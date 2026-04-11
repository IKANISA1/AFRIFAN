import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../settings_actions.dart';
import '../widgets/settings_navigation_scope.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<String> _loadVersionLabel() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version.trim();
      final build = packageInfo.buildNumber.trim();
      if (version.isEmpty && build.isEmpty) {
        return 'Version unavailable';
      }
      if (build.isEmpty) {
        return 'v$version';
      }
      if (version.isEmpty) {
        return 'Build $build';
      }
      return 'v$version ($build)';
    } catch (_) {
      return 'Version unavailable';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appName =
        ClubConfigScope.maybeOf(context)?.appName ??
        RuntimeBranding.displayAppName;
    return SettingsBackGuard(
      child: Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AppBar(
          title: Text(
            'ABOUT',
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: Column(
            children: [
              GlassCard(
                animate: false,
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        appName.length >= 2
                            ? appName.substring(0, 2).toUpperCase()
                            : appName.toUpperCase(),
                        style: TypographyTokens.monolithFont(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    Text(
                      appName.toUpperCase(),
                      style: TypographyTokens.monolithFont(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: ColorTokens.onSurface,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      'Official mobile experience for $appName supporters',
                      style: TypographyTokens.bodyMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    FutureBuilder<String>(
                      future: _loadVersionLabel(),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Loading version…',
                          style: TypographyTokens.bodySmall(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (AppLinks.hasTerms) ...[
                const SizedBox(height: SpacingTokens.spacing4),
                _LinkCard(
                  title: 'Terms of Use',
                  onTap: () => launchExternalUri(
                    context,
                    AppLinks.termsUri!,
                    failureMessage: 'Terms of use are not available yet.',
                  ),
                ),
              ],
              if (AppLinks.hasPrivacyPolicy) ...[
                const SizedBox(height: SpacingTokens.spacing3),
                _LinkCard(
                  title: 'Privacy Policy',
                  onTap: () => launchExternalUri(
                    context,
                    AppLinks.privacyPolicyUri!,
                    failureMessage: 'Privacy policy is not available yet.',
                  ),
                ),
              ],
              if (AppLinks.hasWebsite) ...[
                const SizedBox(height: SpacingTokens.spacing3),
                _LinkCard(
                  title: 'Club Website',
                  onTap: () => launchExternalUri(
                    context,
                    AppLinks.websiteUri!,
                    failureMessage: 'Club website is not available yet.',
                  ),
                ),
              ],
              const SizedBox(height: SpacingTokens.spacing3),
              _LinkCard(
                title: 'Open Source Licenses',
                onTap: () =>
                    showLicensePage(context: context, applicationName: appName),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              ClaymorphicButton(
                label: 'CONTACT SUPPORT',
                width: double.infinity,
                onPressed: () => context.push('/settings/help'),
              ),
              if (AppLinks.hasSupportWhatsApp) ...[
                const SizedBox(height: SpacingTokens.spacing3),
                OutlinedButton(
                  onPressed: () async {
                    await launchWhatsApp(
                      context,
                      message: 'Hi, I need help with $appName.',
                      failureMessage: 'Could not open WhatsApp.',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorTokens.onSurface,
                    minimumSize: const Size(double.infinity, 58),
                    side: BorderTokens.side(
                      color: ColorTokens.onSurface,
                      opacity: 0.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('WHATSAPP SUPPORT'),
                ),
              ],
              const SizedBox(height: SpacingTokens.spacing3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (_) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      Icons.star_rounded,
                      color: ColorTokens.clubAccent,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              OutlinedButton(
                onPressed: () async {
                  await openStoreListing(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorTokens.onSurface,
                  minimumSize: const Size(double.infinity, 58),
                  side: BorderTokens.side(
                    color: ColorTokens.onSurface,
                    opacity: 0.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('RATE THIS APP'),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(title, style: TypographyTokens.bodyLarge())),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        ],
      ),
    );
  }
}
