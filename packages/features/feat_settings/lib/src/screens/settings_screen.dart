import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/settings_overlays.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProvider);
    final alias = profile?.publicUserId == null
        ? '#------'
        : '#${AliasGenerator.format(profile!.publicUserId!)}';
    final statusLine = [
      profile?.hasMomo == true ? 'MOMO LINKED' : 'MOMO PENDING',
      profile?.isAdmin == true ? 'ADMIN READY' : 'SUPPORTER',
    ].join('  •  ');

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.spacing6,
              SpacingTokens.spacing8,
              SpacingTokens.spacing6,
              92.0 + SpacingTokens.spacing8, // Clear floating bottom nav
            ),
            children: [
              Text(
                'SETTINGS',
                style: TypographyTokens.displaySmall(
                  Theme.of(context).colorScheme.primary,
                ).copyWith(letterSpacing: 1.0),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              GlassCard(
                animate: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alias,
                            style: TypographyTokens.numericAlias(fontSize: 22),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            statusLine,
                            style: TypographyTokens.labelSmall().copyWith(
                              color: ColorTokens.onSurfaceVariant,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              _buildSettingsSection(
                title: 'ACCOUNT',
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    onTap: () => context.push('/settings/edit-profile'),
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.phone_android_outlined,
                    title: 'Linked Mobile Money',
                    onTap: () => context.push('/profile_setup'),
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.notifications_none_outlined,
                    title: 'Notifications',
                    onTap: () => context.push('/settings/notifications'),
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.language_outlined,
                    title: 'Language & Region',
                    onTap: () => context.push('/settings/language'),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              _buildSettingsSection(
                title: 'BIOPAY & PRIVACY',
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.payments_outlined,
                    title: 'BioPay Home',
                    onTap: () => context.push('/biopay'),
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.face_retouching_natural_rounded,
                    title: 'Face ID & Enrollment',
                    onTap: () => context.push('/biopay/manage'),
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.qr_code_rounded,
                    title: 'QR Receive & Pay',
                    onTap: () => context.push('/biopay/qr'),
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.nfc_rounded,
                    title: 'NFC Receive & Pay',
                    onTap: () => context.push('/biopay/nfc'),
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.lock_outline,
                    title: 'Privacy Controls',
                    onTap: () => context.push('/settings/privacy'),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              _buildSettingsSection(
                title: 'SUPPORT & ABOUT',
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    onTap: () => context.push('/settings/help'),
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.bug_report_outlined,
                    title: 'Report Bug',
                    onTap: () => context.push('/settings/help'),
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.star_outline_rounded,
                    title: 'Rate App',
                    onTap: () => context.push('/settings/about'),
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.info_outline,
                    title: 'About ${RuntimeBranding.displayAppName}',
                    onTap: () => context.push('/settings/about'),
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
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
                    _buildSettingsTile(
                      context: context,
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin Workspace',
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

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 8,
            bottom: SpacingTokens.spacing2,
          ),
          child: Text(
            title,
            style: TypographyTokens.labelMedium().copyWith(
              color: ColorTokens.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: ColorTokens.surfaceContainerLow,
            borderRadius: ShapeTokens.cardRadius,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: ColorTokens.onSurface),
      title: Text(
        title,
        style: TypographyTokens.titleMedium().copyWith(
          color: ColorTokens.onSurface,
          letterSpacing: 1.5,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: ColorTokens.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
