import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../settings_actions.dart';
import '../settings_route_content_provider.dart';
import '../widgets/settings_overlays.dart';
import 'appearance_screen.dart';

export '../support_whatsapp_provider.dart' show supportWhatsAppProvider;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
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
        title: Text(
          l10n.settingsTitle,
          style: TypographyTokens.headlineSmall(),
        ),
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
                l10n: l10n,
                onRefresh: () =>
                    ref.read(settingsRouteContentProvider.notifier).refresh(),
              )
              case final Widget banner) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing5),
          ],

          // The profile is the page identity, followed by one membership row.
          Center(
            child: Column(
              children: [
                AfriAvatar(
                  semanticLabel: alias,
                  initials: l10n.settingsRoleSupporter,
                  size: AfriComponentSizes.profileAvatar,
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(alias, style: TypographyTokens.headlineLarge()),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  profile?.isAdmin == true
                      ? l10n.settingsRoleAdmin
                      : l10n.settingsRoleSupporter,
                  style: TypographyTokens.bodyLarge(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          AfriListRow(
            key: const ValueKey<String>('settings-membership-action'),
            icon: AfriIcons.membership,
            title: l10n.settingsMembershipDetails,
            onTap: () => context.push('/membership'),
          ),
          const SizedBox(height: SpacingTokens.spacing6),

          // ── Account ──
          _buildMinimalistSection(l10n.settingsSectionAccount, [
            AfriListRow(
              key: const ValueKey<String>('settings-edit-profile-action'),
              icon: AfriIcons.profile,
              title: l10n.settingsEditProfile,
              onTap: () => context.push('/settings/edit-profile'),
            ),
          ]),

          const SizedBox(height: SpacingTokens.spacing6),

          // ── Preferences ──
          _buildMinimalistSection(l10n.settingsSectionPreferences, [
            AfriListRow(
              key: const ValueKey<String>('settings-appearance-action'),
              icon: AfriIcons.appearance,
              title: l10n.settingsAppearance,
              subtitle: _themeModeLabel(l10n, themeMode),
              onTap: () => _showAppearance(context, ref, themeMode),
            ),
            AfriListRow(
              key: const ValueKey<String>('settings-notifications-action'),
              icon: AfriIcons.notifications,
              title: l10n.settingsNotifications,
              onTap: () => context.push('/settings/notifications'),
            ),
            AfriListRow(
              key: const ValueKey<String>('settings-privacy-action'),
              icon: AfriIcons.privacy,
              title: l10n.settingsPrivacy,
              onTap: () => context.push('/settings/privacy'),
            ),
          ]),

          const SizedBox(height: SpacingTokens.spacing6),

          // ── Support ──
          _buildMinimalistSection(l10n.settingsSectionSupport, [
            AfriListRow(
              key: const ValueKey<String>('settings-support-action'),
              icon: AfriIcons.help,
              title: l10n.settingsHelpSupport,
              subtitle: _supportSubtitle(l10n, asyncContent, content),
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
            label: l10n.settingsSignOut,
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
    required AfriLocalizations l10n,
    required VoidCallback onRefresh,
  }) {
    final content = asyncContent.valueOrNull;
    if (asyncContent.isRefreshing && content != null) {
      return AfriStateBanner(
        key: const ValueKey<String>('settings-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.settingsRefreshingTitle,
        subtitle: l10n.settingsRefreshingMessage,
        tone: AfriStateBannerTone.info,
        trailing: const AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }

    if (content != null) {
      if (content.status == SettingsRouteContentStatus.localFallback) {
        return AfriStateBanner(
          key: const ValueKey<String>('settings-state-offline'),
          icon: AfriIcons.offline,
          title: l10n.settingsOfflineTitle,
          subtitle: l10n.settingsOfflineMessage,
          tone: AfriStateBannerTone.warning,
        );
      }
      if (!content.supportEnabled) {
        return AfriStateBanner(
          key: const ValueKey<String>('settings-state-disabled'),
          icon: AfriIcons.help,
          title: l10n.settingsHelpUnavailableTitle,
          subtitle: content.message ?? l10n.settingsHelpUnavailableTitle,
          tone: AfriStateBannerTone.neutral,
        );
      }
      if (content.isEmpty) {
        return AfriStateBanner(
          key: const ValueKey<String>('settings-state-empty'),
          icon: AfriIcons.help,
          title: l10n.settingsSupportContactUnavailableTitle,
          subtitle: l10n.settingsSupportContactUnavailableMessage,
          onTap: onRefresh,
          tone: AfriStateBannerTone.neutral,
        );
      }
      return null;
    }

    if (asyncContent.isLoading) {
      return AfriStateBanner(
        key: const ValueKey<String>('settings-state-loading'),
        icon: AfriIcons.settings,
        title: l10n.settingsLoadingTitle,
        subtitle: l10n.settingsLoadingMessage,
        tone: AfriStateBannerTone.info,
        trailing: const AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }

    final failure = SettingsRouteContentFailure.fromError(
      asyncContent.error ??
          const SettingsRouteContentFailure(
            SettingsRouteContentFailureKind.unknown,
          ),
    );
    return switch (failure.kind) {
      SettingsRouteContentFailureKind.permissionDenied => AfriStateBanner(
        key: const ValueKey<String>('settings-state-permission-denied'),
        icon: AfriIcons.lock,
        title: l10n.settingsAccessLimitedTitle,
        subtitle: l10n.settingsAccessLimitedMessage,
        tone: AfriStateBannerTone.warning,
      ),
      SettingsRouteContentFailureKind.conflict => AfriStateBanner(
        key: const ValueKey<String>('settings-state-conflict'),
        icon: AfriIcons.refresh,
        title: l10n.settingsChangedTitle,
        subtitle: l10n.settingsChangedMessage,
        onTap: onRefresh,
        tone: AfriStateBannerTone.warning,
      ),
      SettingsRouteContentFailureKind.securityTimeout => AfriStateBanner(
        key: const ValueKey<String>('settings-state-security-timeout'),
        icon: AfriIcons.lock,
        title: l10n.settingsSecurityTimeoutTitle,
        subtitle: l10n.settingsSecurityTimeoutMessage,
        onTap: onRefresh,
        tone: AfriStateBannerTone.warning,
      ),
      SettingsRouteContentFailureKind.unknown => AfriStateBanner(
        key: const ValueKey<String>('settings-state-error'),
        icon: AfriIcons.statusError,
        title: l10n.settingsSupportLoadFailedTitle,
        subtitle: l10n.settingsSupportLoadFailedMessage,
        onTap: onRefresh,
        tone: AfriStateBannerTone.danger,
      ),
    };
  }

  String? _supportSubtitle(
    AfriLocalizations l10n,
    AsyncValue<SettingsRouteContentSnapshot> asyncContent,
    SettingsRouteContentSnapshot? content,
  ) {
    if (asyncContent.isLoading && content == null) return l10n.settingsChecking;
    if (content?.status == SettingsRouteContentStatus.localFallback) {
      return l10n.settingsConnectionRequired;
    }
    if (content != null && !content.supportEnabled) {
      return l10n.settingsUnavailable;
    }
    if (content?.isEmpty == true) return l10n.settingsNotConfigured;
    if (asyncContent.hasError && content == null) {
      return l10n.settingsStatusUnavailable;
    }
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
        AfriListGroup(children: children),
      ],
    );
  }

  String _themeModeLabel(AfriLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => l10n.settingsThemeUseDevice,
      ThemeMode.light => l10n.settingsThemeLight,
      ThemeMode.dark => l10n.settingsThemeDark,
    };
  }

  Future<void> _showAppearance(
    BuildContext context,
    WidgetRef ref,
    ThemeMode selectedMode,
  ) async {
    final mode = await Navigator.of(context).push<ThemeMode>(
      MaterialPageRoute(
        builder: (_) => AppearanceScreen(initialMode: selectedMode),
      ),
    );
    if (mode == null || !context.mounted) return;
    await ref
        .read(themeModeProvider.notifier)
        .setThemeMode(
          mode,
          systemBrightness: MediaQuery.platformBrightnessOf(context),
        );
  }

  Future<void> _openWhatsApp(
    BuildContext context,
    String? supportWhatsApp,
  ) async {
    final phone = supportWhatsApp?.trim() ?? '';
    final l10n = context.afriL10n;
    if (phone.isEmpty) {
      AfriToast.error(context, l10n.settingsSupportNotConfigured);
      return;
    }

    unawaited(FirebaseAnalyticsService.logSupportAccess(channel: 'whatsapp'));
    final uri = Uri.parse(
      'https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(l10n.settingsSupportGreeting(ClubConfigScope.maybeOf(context)?.appName ?? RuntimeBranding.displayAppName))}',
    );
    await launchExternalUri(
      context,
      uri,
      failureMessage: l10n.settingsWhatsAppFailed,
    );
  }
}
