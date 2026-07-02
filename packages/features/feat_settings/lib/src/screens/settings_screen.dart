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
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('Settings', style: TypographyTokens.headlineSmall()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.screenPadding,
            SpacingTokens.spacing4,
            SpacingTokens.screenPadding,
            SpacingTokens.spacing20,
          ),
          children: [
            // ── Profile summary ──
            GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: SizeTokens.avatarMd,
                        height: SizeTokens.avatarMd,
                        decoration: BoxDecoration(
                          color: ColorTokens.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            ShapeTokens.radiusMd,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          AfriIcons.profile,
                          color: ColorTokens.onDark,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(alias, style: TypographyTokens.titleLarge()),
                            const SizedBox(height: SpacingTokens.spacing1),
                            AfriStatusChip(
                              label: profile?.isAdmin == true
                                  ? 'Admin'
                                  : 'Supporter',
                              tone: AfriStatusTone.live,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  AfriButton(
                    label: 'Membership details',
                    onTap: () => context.push('/membership'),
                    variant: AfriButtonVariant.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing8),

            // ── Account ──
            _buildMinimalistSection('Account', [
              AfriListRow(
                icon: AfriIcons.profile,
                title: 'Edit profile',
                onTap: () => context.push('/settings/edit-profile'),
              ),
            ]),

            const SizedBox(height: SpacingTokens.spacing6),

            // ── Preferences ──
            _buildMinimalistSection('Preferences', [
              AfriListRow(
                icon: AfriIcons.notifications,
                title: 'Notifications',
                onTap: () => context.push('/settings/notifications'),
              ),
              AfriListRow(
                icon: AfriIcons.privacy,
                title: 'Privacy',
                onTap: () => context.push('/settings/privacy'),
              ),
            ]),

            const SizedBox(height: SpacingTokens.spacing6),

            // ── Support ──
            _buildMinimalistSection('Support', [
              AfriListRow(
                icon: AfriIcons.help,
                title: 'Help & support',
                onTap: () =>
                    _openWhatsApp(context, supportWhatsApp.valueOrNull),
              ),
            ]),

            const SizedBox(height: SpacingTokens.spacing8),

            // ── Account actions ──
            AfriButton(
              label: 'Sign out',
              onTap: () async {
                final confirmed = await showSignOutConfirmationSheet(context);
                if (!confirmed) return;
                await ref.read(authStateProvider.notifier).signOut();
                if (!context.mounted) return;
                context.go('/onboarding');
              },
              variant: AfriButtonVariant.outline,
              icon: AfriIcons.logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalistSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AfriSectionHeader(title: title, padding: EdgeInsets.zero),
        const SizedBox(height: SpacingTokens.spacing3),
        ...children.map(
          (child) =>
              Padding(padding: const EdgeInsets.only(bottom: 4), child: child),
        ),
      ],
    );
  }

  Future<void> _openWhatsApp(
    BuildContext context,
    String? supportWhatsApp,
  ) async {
    final phone = supportWhatsApp?.trim() ?? '';
    if (phone.isEmpty) {
      AfriToast.error(context, 'Support contact is not configured.');
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
