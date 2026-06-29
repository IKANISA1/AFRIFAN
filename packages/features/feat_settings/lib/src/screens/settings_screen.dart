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

            // ── Heritage ──
            _buildMinimalistSection('Heritage', [
              AfriListRow(
                icon: AfriIcons.history,
                title: 'History & honors',
                onTap: () => context.push('/fanzone/history'),
              ),
              AfriListRow(
                icon: AfriIcons.star,
                title: 'Hall of fame',
                onTap: () => context.push('/fanzone/leaderboard'),
              ),
            ]),

            const SizedBox(height: SpacingTokens.spacing6),

            // ── Account ──
            _buildMinimalistSection('Account', [
              AfriListRow(
                icon: AfriIcons.profile,
                title: 'Edit profile',
                onTap: () => context.push('/settings/edit-profile'),
              ),
              AfriListRow(
                icon: AfriIcons.notifications,
                title: 'Notifications',
                onTap: () => context.push('/settings/notifications'),
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
              AfriListRow(
                icon: AfriIcons.privacy,
                title: 'Privacy policy',
                onTap: () => context.push('/settings/privacy'),
              ),
            ]),

            const SizedBox(height: SpacingTokens.spacing8),

            // ── Account actions ──
            if (profile?.isAdmin == true)
              Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
                child: AfriButton(
                  label: 'Admin workspace',
                  onTap: () => _openAdminWorkspace(context, ref),
                  variant: AfriButtonVariant.secondary,
                  icon: AfriIcons.admin,
                ),
              ),

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

  Future<void> _openAdminWorkspace(BuildContext context, WidgetRef ref) async {
    final session = ref.read(supabaseClientProvider).auth.currentUser;
    if (session == null) {
      if (!context.mounted) return;
      AfriToast.error(context, 'Session expired. Please sign in again.');
      return;
    }

    final confirmed = await _showAdminConfirmation(context);
    if (!confirmed || !context.mounted) return;
    unawaited(context.push('/admin'));
  }

  Future<bool> _showAdminConfirmation(BuildContext context) async {
    final result = await showAfriBottomSheet<bool>(
      context: context,
      builder: (context) => AfriPanelCard(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              AfriIcons.admin,
              color: ColorTokens.warning,
              size: SizeTokens.iconXl,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'ADMIN ACCESS',
              style: TypographyTokens.headlineMedium(ColorTokens.onDark)
                  .copyWith(
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              'You are entering the admin workspace with elevated permissions. Actions taken here affect all supporters.',
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(
                ColorTokens.onDarkDim,
              ).copyWith(height: TypographyTokens.lineHeightRelaxed),
            ),
            const SizedBox(height: SpacingTokens.spacing8),
            Row(
              children: [
                Expanded(
                  child: AfriButton(
                    label: 'Cancel',
                    variant: AfriButtonVariant.outline,
                    onTap: () => context.pop(false),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: AfriButton(
                    label: 'Continue',
                    onTap: () => context.pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result == true;
  }
}
