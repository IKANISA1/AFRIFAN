import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../settings_actions.dart';
import '../widgets/settings_overlays.dart';

final _supportWhatsAppProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final repository = AppConfigRepository(
    client: ref.watch(supabaseClientProvider),
  );
  final configured = (await repository.getValue(
    AppConfigKeys.supportWhatsApp,
  ))?.trim();
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }

  final fallback = AppLinks.supportWhatsApp.trim();
  return fallback.isEmpty ? null : fallback;
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProvider);
    final supportWhatsApp = ref.watch(_supportWhatsAppProvider);
    final alias = profile?.publicUserId == null
        ? '#------'
        : '#${AliasGenerator.format(profile!.publicUserId!)}';

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.screenPadding,
              SpacingTokens.screenPadding,
              SpacingTokens.screenPadding,
              92.0 + SpacingTokens.sectionGap,
            ),
            children: [
              const AfriSectionHeader(
                title: 'Settings',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: SpacingTokens.spacing4),

              // ── Profile card ──
              GlassCard(
                animate: false,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ColorTokens.primaryTint(0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(AfriIcons.profile),
                    ),
                    const SizedBox(width: SpacingTokens.spacing4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(alias, style: TypographyTokens.headlineSmall()),
                          const SizedBox(height: SpacingTokens.spacing1),
                          AfriInfoChip(
                            label: profile?.isAdmin == true
                                ? 'Admin'
                                : 'Supporter',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.sectionGap),

              // ── Account ──
              AfriSection(
                title: 'Account',
                child: Column(
                  children: [
                    AfriListRow(
                      icon: AfriIcons.profile,
                      title: 'Edit profile',
                      onTap: () => context.push('/settings/edit-profile'),
                    ),
                    const SizedBox(height: SpacingTokens.listItemGap),
                    AfriListRow(
                      icon: AfriIcons.notifications,
                      title: 'Notifications',
                      onTap: () => context.push('/settings/notifications'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.sectionGap),

              // ── Privacy ──
              AfriSection(
                title: 'Privacy',
                child: AfriListRow(
                  icon: AfriIcons.privacy,
                  title: 'Privacy controls',
                  onTap: () => context.push('/settings/privacy'),
                ),
              ),
              const SizedBox(height: SpacingTokens.sectionGap),

              // ── Support ──
              AfriSection(
                title: 'Support',
                child: Column(
                  children: [
                    AfriListRow(
                      icon: AfriIcons.help,
                      title: 'Help & Support',
                      onTap: () =>
                          _openWhatsApp(context, supportWhatsApp.valueOrNull),
                    ),
                    if (AppLinks.hasTerms || AppLinks.hasPrivacyPolicy) ...[
                      const SizedBox(height: SpacingTokens.listItemGap),
                      AfriListRow(
                        icon: AfriIcons.terms,
                        title: 'Terms & Privacy',
                        onTap: () {
                          final uri =
                              AppLinks.termsUri ?? AppLinks.privacyPolicyUri;
                          if (uri != null) {
                            unawaited(
                              launchExternalUri(
                                context,
                                uri,
                                failureMessage:
                                    'Could not open the legal document.',
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.sectionGap),

              // ── Account actions ──
              if (profile?.isAdmin == true)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: SpacingTokens.listItemGap,
                  ),
                  child: AfriListRow(
                    icon: AfriIcons.admin,
                    title: 'Admin workspace',
                    onTap: () => context.push('/admin'),
                  ),
                ),
              AfriListRow(
                icon: AfriIcons.logout,
                title: 'Sign out',
                onTap: () async {
                  final confirmed = await showSignOutConfirmationSheet(context);
                  if (!confirmed) return;
                  await ref.read(authStateProvider.notifier).signOut();
                  if (!context.mounted) return;
                  context.go('/splash');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(
    BuildContext context,
    String? supportWhatsApp,
  ) async {
    final phone = supportWhatsApp?.trim() ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support contact is not configured.')),
      );
      return;
    }

    final uri = Uri.parse(
      'https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent('Hi, I need help with ${ClubConfigScope.maybeOf(context)?.appName ?? RuntimeBranding.displayAppName}.')}',
    );
    await launchExternalUri(
      context,
      uri,
      failureMessage: 'Could not open WhatsApp.',
    );
  }
}
