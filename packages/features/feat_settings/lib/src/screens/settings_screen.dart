import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings_actions.dart';
import '../widgets/settings_overlays.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _supportWhatsApp = '+250795588248';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProvider);
    final alias = profile?.publicUserId == null
        ? '#------'
        : '#${AliasGenerator.format(profile!.publicUserId!)}';

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.spacing6,
              SpacingTokens.spacing6,
              SpacingTokens.spacing6,
              92.0 + SpacingTokens.spacing8,
            ),
            children: [
              const AfriSectionHeader(
                title: 'Settings',
                subtitle: 'Account, privacy, and support',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              GlassCard(
                animate: false,
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: ColorTokens.primaryTint(0.16),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person_outline_rounded),
                    ),
                    const SizedBox(width: SpacingTokens.spacing4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(alias, style: TypographyTokens.headlineSmall()),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Wrap(
                            spacing: SpacingTokens.spacing2,
                            runSpacing: SpacingTokens.spacing2,
                            children: [
                              AfriStatusChip(
                                label: profile?.isAdmin == true
                                    ? 'Admin'
                                    : 'Supporter',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing6),

              // ── Account ──
              _Section(
                title: 'Account',
                children: [
                  AfriListRow(
                    icon: Icons.person_outline,
                    title: 'Edit profile',
                    onTap: () => context.push('/settings/edit-profile'),
                  ),
                  AfriListRow(
                    icon: Icons.notifications_none_outlined,
                    title: 'Notifications',
                    onTap: () => context.push('/settings/notifications'),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing6),

              // ── Privacy ──
              _Section(
                title: 'Privacy',
                children: [
                  AfriListRow(
                    icon: Icons.lock_outline,
                    title: 'Privacy controls',
                    onTap: () => context.push('/settings/privacy'),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing6),

              // ── Support ──
              _Section(
                title: 'Support',
                children: [
                  AfriListRow(
                    icon: Icons.chat_outlined,
                    title: 'Help & Support',
                    subtitle: 'Chat with us on WhatsApp',
                    onTap: () => _openWhatsApp(context),
                  ),
                  if (AppLinks.hasTerms || AppLinks.hasPrivacyPolicy)
                    AfriListRow(
                      icon: Icons.description_outlined,
                      title: 'Terms & Privacy',
                      onTap: () {
                        final uri =
                            AppLinks.termsUri ?? AppLinks.privacyPolicyUri;
                        if (uri != null) {
                          launchExternalUri(
                            context,
                            uri,
                            failureMessage:
                                'Could not open the legal document.',
                          );
                        }
                      },
                    ),
                  AfriListRow(
                    icon: Icons.info_outline,
                    title: 'Open-source licenses',
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName:
                          ClubConfigScope.maybeOf(context)?.appName ??
                          RuntimeBranding.displayAppName,
                    ),
                  ),
                  AfriListRow(
                    icon: Icons.logout_rounded,
                    title: 'Sign out',
                    onTap: () async {
                      final confirmed = await showSignOutConfirmationSheet(
                        context,
                      );
                      if (!confirmed) return;
                      await ref.read(authStateProvider.notifier).signOut();
                      if (!context.mounted) return;
                      context.go('/splash');
                    },
                  ),
                  if (profile?.isAdmin == true)
                    AfriListRow(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin workspace',
                      onTap: () => context.push('/admin'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final phone = _supportWhatsApp.replaceAll('+', '');
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent('Hi, I need help with ${ClubConfigScope.maybeOf(context)?.appName ?? RuntimeBranding.displayAppName}.')}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
          child: Text(
            title,
            style: TypographyTokens.labelMedium(ColorTokens.onSurfaceVariant),
          ),
        ),
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
            child: child,
          ),
      ],
    );
  }
}
