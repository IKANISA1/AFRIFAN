import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../settings_actions.dart';
import '../settings_route_content_provider.dart';
import '../widgets/settings_overlays.dart';

export '../support_whatsapp_provider.dart' show supportWhatsAppProvider;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProvider);
    final asyncContent = ref.watch(settingsRouteContentProvider);
    final content = asyncContent.valueOrNull;
    final supportWhatsApp = content?.supportWhatsApp;
    final themeMode = ref.watch(themeModeProvider);
    final alias = profile?.publicUserId == null
        ? '#------'
        : '#${AliasGenerator.format(profile!.publicUserId!)}';

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('Settings', style: TypographyTokens.headlineSmall()),
      ),
      scrollable: false,
      constrainContent: true,
      bottomNavigationAware: true,
      child: ListView(
        key: const ValueKey('settings-scroll'),
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.screenPadding,
          SpacingTokens.spacing4,
          SpacingTokens.screenPadding,
          SpacingTokens.spacing20,
        ),
        children: [
          if (_buildRouteStateBanner(
                asyncContent,
                onRefresh: () =>
                    ref.read(settingsRouteContentProvider.notifier).refresh(),
              )
              case final Widget banner) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing5),
          ],

          // ── Profile summary ──
          GlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    AfriAvatar(
                      semanticLabel: alias,
                      initials: 'Supporter',
                      size: SizeTokens.avatarMd,
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
                  key: const ValueKey<String>('settings-membership-action'),
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
              key: const ValueKey<String>('settings-edit-profile-action'),
              icon: AfriIcons.profile,
              title: 'Edit profile',
              onTap: () => context.push('/settings/edit-profile'),
            ),
          ]),

          const SizedBox(height: SpacingTokens.spacing6),

          // ── Preferences ──
          _buildMinimalistSection('Preferences', [
            AfriListRow(
              key: const ValueKey<String>('settings-appearance-action'),
              icon: AfriIcons.appearance,
              title: 'Appearance',
              subtitle: _themeModeLabel(themeMode),
              onTap: () => _showAppearanceSheet(context, ref, themeMode),
            ),
            AfriListRow(
              key: const ValueKey<String>('settings-notifications-action'),
              icon: AfriIcons.notifications,
              title: 'Notifications',
              onTap: () => context.push('/settings/notifications'),
            ),
            AfriListRow(
              key: const ValueKey<String>('settings-privacy-action'),
              icon: AfriIcons.privacy,
              title: 'Privacy',
              onTap: () => context.push('/settings/privacy'),
            ),
          ]),

          const SizedBox(height: SpacingTokens.spacing6),

          // ── Support ──
          _buildMinimalistSection('Support', [
            AfriListRow(
              key: const ValueKey<String>('settings-support-action'),
              icon: AfriIcons.help,
              title: 'Help & support',
              subtitle: _supportSubtitle(asyncContent, content),
              enabled: _supportAvailable(content),
              onTap: _supportAvailable(content)
                  ? () => _openWhatsApp(context, supportWhatsApp)
                  : null,
            ),
          ]),

          const SizedBox(height: SpacingTokens.spacing8),

          // ── Account actions ──
          AfriButton(
            key: const ValueKey<String>('settings-sign-out-action'),
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
    );
  }

  Widget? _buildRouteStateBanner(
    AsyncValue<SettingsRouteContentSnapshot> asyncContent, {
    required VoidCallback onRefresh,
  }) {
    final content = asyncContent.valueOrNull;
    if (asyncContent.isRefreshing && content != null) {
      return const AfriStateBanner(
        key: ValueKey<String>('settings-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Refreshing settings',
        subtitle: 'Current account and appearance settings stay available.',
        tone: AfriStateBannerTone.info,
        trailing: SizedBox.square(
          dimension: SizeTokens.iconMd,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (content != null) {
      if (content.status == SettingsRouteContentStatus.localFallback) {
        return AfriStateBanner(
          key: const ValueKey<String>('settings-state-offline'),
          icon: AfriIcons.offline,
          title: 'Offline settings',
          subtitle: content.message,
          tone: AfriStateBannerTone.warning,
        );
      }
      if (!content.supportEnabled) {
        return AfriStateBanner(
          key: const ValueKey<String>('settings-state-disabled'),
          icon: AfriIcons.help,
          title: 'Help and support unavailable',
          subtitle: content.message,
          tone: AfriStateBannerTone.neutral,
        );
      }
      if (content.isEmpty) {
        return AfriStateBanner(
          key: const ValueKey<String>('settings-state-empty'),
          icon: AfriIcons.help,
          title: 'Support contact unavailable',
          subtitle: 'Other settings still work. Refresh to check again.',
          onTap: onRefresh,
          tone: AfriStateBannerTone.neutral,
        );
      }
      return null;
    }

    if (asyncContent.isLoading) {
      return const AfriStateBanner(
        key: ValueKey<String>('settings-state-loading'),
        icon: AfriIcons.settings,
        title: 'Loading settings',
        subtitle: 'Checking support availability.',
        tone: AfriStateBannerTone.info,
        trailing: SizedBox.square(
          dimension: SizeTokens.iconMd,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final failure = SettingsRouteContentFailure.fromError(
      asyncContent.error ??
          const SettingsRouteContentFailure(
            SettingsRouteContentFailureKind.unknown,
          ),
    );
    return switch (failure.kind) {
      SettingsRouteContentFailureKind.permissionDenied => const AfriStateBanner(
        key: ValueKey<String>('settings-state-permission-denied'),
        icon: AfriIcons.lock,
        title: 'Settings access limited',
        subtitle:
            'Support availability could not be verified. '
            'Account and appearance settings remain available.',
        tone: AfriStateBannerTone.warning,
      ),
      SettingsRouteContentFailureKind.conflict => AfriStateBanner(
        key: const ValueKey<String>('settings-state-conflict'),
        icon: AfriIcons.refresh,
        title: 'Settings changed',
        subtitle: 'Refresh to load the current support settings.',
        onTap: onRefresh,
        tone: AfriStateBannerTone.warning,
      ),
      SettingsRouteContentFailureKind.securityTimeout => AfriStateBanner(
        key: const ValueKey<String>('settings-state-security-timeout'),
        icon: AfriIcons.lock,
        title: 'Settings security check timed out',
        subtitle: 'Check your connection and refresh.',
        onTap: onRefresh,
        tone: AfriStateBannerTone.warning,
      ),
      SettingsRouteContentFailureKind.unknown => AfriStateBanner(
        key: const ValueKey<String>('settings-state-error'),
        icon: AfriIcons.statusError,
        title: 'Could not load support settings',
        subtitle: 'Account and appearance settings remain available.',
        onTap: onRefresh,
        tone: AfriStateBannerTone.danger,
      ),
    };
  }

  String? _supportSubtitle(
    AsyncValue<SettingsRouteContentSnapshot> asyncContent,
    SettingsRouteContentSnapshot? content,
  ) {
    if (asyncContent.isLoading && content == null) return 'Checking…';
    if (content?.status == SettingsRouteContentStatus.localFallback) {
      return 'Connection required';
    }
    if (content != null && !content.supportEnabled) return 'Unavailable';
    if (content?.isEmpty == true) return 'Not configured';
    if (asyncContent.hasError && content == null) return 'Status unavailable';
    return null;
  }

  bool _supportAvailable(SettingsRouteContentSnapshot? content) {
    return content != null &&
        content.status == SettingsRouteContentStatus.current &&
        content.supportEnabled &&
        !content.isEmpty;
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

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Use device setting',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  Future<void> _showAppearanceSheet(
    BuildContext context,
    WidgetRef ref,
    ThemeMode selectedMode,
  ) async {
    final selectedIndex = switch (selectedMode) {
      ThemeMode.system => 0,
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
    };
    await showAfriBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance', style: TypographyTokens.titleLarge()),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            'Choose a theme or follow your device setting.',
            style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriSegmentedControl(
            items: const [
              AfriSegment(label: 'System'),
              AfriSegment(label: 'Light'),
              AfriSegment(label: 'Dark'),
            ],
            selectedIndex: selectedIndex,
            onChanged: (index) {
              final mode = switch (index) {
                1 => ThemeMode.light,
                2 => ThemeMode.dark,
                _ => ThemeMode.system,
              };
              unawaited(
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(
                      mode,
                      systemBrightness: MediaQuery.platformBrightnessOf(
                        context,
                      ),
                    ),
              );
              Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
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

    unawaited(FirebaseAnalyticsService.logSupportAccess(channel: 'whatsapp'));
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
