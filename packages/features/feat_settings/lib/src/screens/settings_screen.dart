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
              Text(
                'THE BELOVED',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: ColorTokens.clubAccent, letterSpacing: 2),
              ),
              const Text(
                'SETTINGS',
                style: TextStyle(fontFamily: 'Display', fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white, height: 1),
              ),
              const SizedBox(height: 24),

              // ── Profile card ──
              EliteCard(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(AfriIcons.profile, color: Colors.black),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alias, 
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5)
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (profile?.isAdmin == true ? 'Admin' : 'Supporter').toUpperCase(),
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(height: 1, color: Colors.black.withValues(alpha: 0.05)),
                    const SizedBox(height: 20),
                    EliteButton(
                      label: 'Membership Details',
                      onTap: () => context.push('/membership'),
                      variant: EliteButtonVariant.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Heritage ──
              _buildEliteSection('HERITAGE', [
                AfriListRow(
                  icon: AfriIcons.history,
                  title: 'History & Honors',
                  onTap: () => context.push('/history'),
                ),
                AfriListRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Hall of Fame',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 24),

              // ── Account ──
              _buildEliteSection('ACCOUNT', [
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

              const SizedBox(height: 24),

              // ── Support ──
              _buildEliteSection('SUPPORT', [
                AfriListRow(
                  icon: AfriIcons.help,
                  title: 'Help & Support',
                  onTap: () => _openWhatsApp(context, supportWhatsApp.valueOrNull),
                ),
                AfriListRow(
                  icon: AfriIcons.privacy,
                  title: 'Privacy Policy',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 32),

              // ── Account actions ──
              if (profile?.isAdmin == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EliteButton(
                    label: 'Admin Workspace',
                    onTap: () => _openAdminWorkspace(context, ref),
                    variant: EliteButtonVariant.secondary,
                    icon: AfriIcons.admin,
                  ),
                ),
              
              EliteButton(
                label: 'Sign Out',
                onTap: () async {
                  final confirmed = await showSignOutConfirmationSheet(context);
                  if (!confirmed) return;
                  await ref.read(authStateProvider.notifier).signOut();
                  if (!context.mounted) return;
                  context.go('/onboarding');
                },
                variant: EliteButtonVariant.outline,
                icon: AfriIcons.logout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEliteSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 2),
          ),
        ),
        ...children.map((child) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: child,
        )),
      ],
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

  Future<void> _openAdminWorkspace(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final session = ref.read(supabaseClientProvider).auth.currentUser;
    if (session == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please sign in again.')),
      );
      return;
    }

    final confirmed = await _showAdminConfirmation(context);
    if (!confirmed || !context.mounted) return;
    unawaited(context.push('/admin'));
  }

  Future<bool> _showAdminConfirmation(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => EliteCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AfriIcons.admin, color: ColorTokens.warning, size: 48),
            const SizedBox(height: 16),
            const Text(
              'ADMIN ACCESS',
              style: TextStyle(fontFamily: 'Display', fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'You are entering the admin workspace with elevated permissions. Actions taken here affect all supporters.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: EliteButton(
                    label: 'Cancel',
                    variant: EliteButtonVariant.outline,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EliteButton(
                    label: 'Continue',
                    onTap: () => Navigator.of(context).pop(true),
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
