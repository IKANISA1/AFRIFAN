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
    final config = ClubConfigScope.maybeOf(context);
    final appName = config?.appName ?? RuntimeBranding.displayAppName;
    final showBiopayEntries =
        (config?.hasBiopay ?? false) &&
        _hasRoute(context, 'biopay') &&
        _hasRoute(context, 'biopay_profile');
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
                                label: profile?.hasMomo == true
                                    ? 'MOMO linked'
                                    : 'MOMO pending',
                                tone: profile?.hasMomo == true
                                    ? AfriStatusTone.success
                                    : AfriStatusTone.warning,
                              ),
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
              _Section(
                title: 'Account',
                children: [
                  AfriListRow(
                    icon: Icons.person_outline,
                    title: 'Edit profile',
                    onTap: () => context.push('/settings/edit-profile'),
                  ),
                  AfriListRow(
                    icon: Icons.phone_android_outlined,
                    title: 'Linked mobile money',
                    onTap: () => context.push('/profile_setup'),
                  ),
                  AfriListRow(
                    icon: Icons.notifications_none_outlined,
                    title: 'Notifications',
                    onTap: () => context.push('/settings/notifications'),
                  ),
                  AfriListRow(
                    icon: Icons.language_outlined,
                    title: 'Language & region',
                    onTap: () => context.push('/settings/language'),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              _Section(
                title: showBiopayEntries ? 'BioPay & Privacy' : 'Privacy',
                children: [
                  if (showBiopayEntries)
                    AfriListRow(
                      icon: Icons.payments_outlined,
                      title: 'BioPay home',
                      onTap: () => context.push('/biopay'),
                    ),
                  if (showBiopayEntries)
                    AfriListRow(
                      icon: Icons.face_retouching_natural_rounded,
                      title: 'Face ID & enrollment',
                      onTap: () => context.push('/biopay/profile'),
                    ),
                  if (showBiopayEntries)
                    AfriListRow(
                      icon: Icons.qr_code_rounded,
                      title: 'QR receive & pay',
                      onTap: () => context.push('/biopay/qr'),
                    ),
                  if (showBiopayEntries)
                    AfriListRow(
                      icon: Icons.nfc_rounded,
                      title: 'NFC receive & pay',
                      onTap: () => context.push('/biopay/nfc'),
                    ),
                  AfriListRow(
                    icon: Icons.lock_outline,
                    title: 'Privacy controls',
                    onTap: () => context.push('/settings/privacy'),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              _Section(
                title: 'Support & About',
                children: [
                  AfriListRow(
                    icon: Icons.help_outline,
                    title: 'Help center',
                    onTap: () => context.push('/settings/help'),
                  ),
                  AfriListRow(
                    icon: Icons.bug_report_outlined,
                    title: 'Report bug',
                    onTap: () => context.push('/settings/help'),
                  ),
                  AfriListRow(
                    icon: Icons.star_outline_rounded,
                    title: 'Rate app',
                    onTap: () => context.push('/settings/about'),
                  ),
                  AfriListRow(
                    icon: Icons.info_outline,
                    title: 'About $appName',
                    onTap: () => context.push('/settings/about'),
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

  bool _hasRoute(BuildContext context, String routeName) {
    try {
      GoRouter.of(context).namedLocation(routeName);
      return true;
    } catch (_) {
      return false;
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
        ...children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
                child: child,
              ),
            )
            .toList(),
      ],
    );
  }
}
