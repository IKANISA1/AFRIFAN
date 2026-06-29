import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_sms_ledger/feat_sms_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_privacy_settings.dart';
import '../settings_actions.dart';
import '../settings_providers.dart';
import '../widgets/settings_navigation_scope.dart';
import '../widgets/settings_overlays.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  UserPrivacySettings? _draft;
  String? _draftUserId;
  bool _isSaving = false;

  void _syncDraft(UserPrivacySettings settings) {
    if (_draftUserId == settings.userId) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _draft = settings;
        _draftUserId = settings.userId;
      });
    });
  }

  Future<void> _saveSettings(UserPrivacySettings settings) async {
    setState(() => _isSaving = true);

    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .updatePrivacySettings(settings);
      await _synchronizeSmsAutoreadConsent(saved);
      ref.invalidate(privacySettingsProvider);
      if (!mounted) return;
      setState(() => _draft = saved);
      _showMessage('Privacy settings saved.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _signOutOtherDevices() async {
    final confirmed = await showSignOutOtherDevicesSheet(context);
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    final error = await ref
        .read(authStateProvider.notifier)
        .signOutOtherSessions();
    if (!mounted) return;
    setState(() => _isSaving = false);
    _showMessage(error ?? 'Other sessions were signed out.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    AfriToast.info(context, message);
  }

  Future<void> _synchronizeSmsAutoreadConsent(
    UserPrivacySettings settings,
  ) async {
    final appAccessService = AppAccessService(openBox: openHiveBox<bool>);
    await appAccessService.setEnabled(
      AppAccessPermission.sms,
      settings.momoSmsAutoreadEnabled,
    );

    final smsService = ref.read(momoSmsAutoreadServiceProvider);
    if (!settings.momoSmsAutoreadEnabled) {
      await smsService.stop(resetPermissionPromptState: true);
      return;
    }

    await smsService.syncConsentFromServer();
    final started = await smsService.refresh(
      forcePermissionRequest: true,
      onShowRationale: _showMomoSmsConsentDisclosure,
    );
    if (!mounted || started) {
      return;
    }

    _showMessage(
      'SMS sync stays off until you grant Android SMS access for MoMo verification.',
    );
  }

  Future<bool> _showMomoSmsConsentDisclosure() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AfriAlertDialog(
          title: const Text('Enable MoMo SMS sync'),
          content: const Text(
            'The app can read only approved Mobile Money verification SMS on this device to match your contribution payments automatically. This does not enable general message access in the app UI.',
          ),
          actions: [
            AfriTextButton(
              onPressed: () => context.pop(false),
              child: const Text('Not now'),
            ),
            AfriButton(
              label: 'Continue',
              onTap: () => context.pop(true),
              fullWidth: false,
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final appName =
        ClubConfigScope.maybeOf(context)?.appName ??
        RuntimeBranding.displayAppName;
    final asyncSettings = ref.watch(privacySettingsProvider);
    final loadedSettings = asyncSettings.valueOrNull;
    if (loadedSettings != null) {
      _syncDraft(loadedSettings);
    }

    final settings = _draft ?? loadedSettings;

    return SettingsBackGuard(
      child: Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          title: Text(
            'PRIVACY',
            style: TypographyTokens.headlineSmall().copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: AfriIconButton(
            icon: AfriIcons.back,
            onTap: () => closeSettingsChild(context),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
        ),
        body: settings == null
            ? asyncSettings.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(SpacingTokens.spacing6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Could not load privacy settings.',
                              style: TypographyTokens.bodyMedium(),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            AfriButton(
                              label: 'Retry',
                              onTap: () =>
                                  ref.invalidate(privacySettingsProvider),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(SpacingTokens.spacing6),
                      child: AfriSkeletonList(),
                    )
            : ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTRIBUTION PRIVACY',
                          style: TypographyTokens.labelSmall(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          'Fan clubs, team projects, and communities are public and admin-managed in this release. You can join and contribute, but you cannot create or hide groups.',
                          style: TypographyTokens.bodyMedium(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        if (EnvConfig.enableAndroidMomoSmsAutoread)
                          AfriSwitchListTile(
                            value: settings.momoSmsAutoreadEnabled,
                            onChanged: (value) => setState(
                              () => _draft = settings.copyWith(
                                momoSmsAutoreadEnabled: value,
                              ),
                            ),
                            title: const Text('MoMo SMS sync'),
                            subtitle: const Text(
                              'Allow approved Mobile Money SMS to be matched automatically for faster contribution verification.',
                            ),
                          ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          'Additional analytics, device security, and presence controls are managed by app policy and by your phone in this release.',
                          style: TypographyTokens.bodySmall(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR DATA', style: TypographyTokens.labelSmall()),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          'Request a data export through a configured support channel.',
                          style: TypographyTokens.bodyMedium(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        AfriButton(
                          label: 'Request data export',
                          fullWidth: true,
                          onTap:
                              AppLinks.hasSupportWhatsApp ||
                                  AppLinks.hasSupportEmail
                              ? () async {
                                  if (AppLinks.hasSupportWhatsApp) {
                                    await launchWhatsApp(
                                      context,
                                      message:
                                          'Data export request for $appName. Please send me a copy of my account data.',
                                      failureMessage:
                                          'Could not open WhatsApp.',
                                    );
                                    return;
                                  }
                                  await launchMailTo(
                                    context,
                                    email: AppLinks.supportEmail,
                                    subject: '$appName data export request',
                                    body:
                                        'Please send me a copy of my account data.',
                                    failureMessage:
                                        'Could not open your mail app.',
                                  );
                                }
                              : () {},
                          enabled:
                              AppLinks.hasSupportWhatsApp ||
                              AppLinks.hasSupportEmail,
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        AfriOutlinedButton(
                          onPressed: () async {
                            final uri = AppLinks.privacyPolicyUri;
                            if (uri == null) {
                              _showMessage(
                                'Privacy policy is not configured for this build.',
                              );
                              return;
                            }
                            await launchExternalUri(
                              context,
                              uri,
                              failureMessage:
                                  'Privacy policy is not available yet.',
                            );
                          },
                          style: AfriOutlinedButton.styleFrom(
                            minimumSize: const Size(
                              double.infinity,
                              SizeTokens.buttonMinHeight,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: ShapeTokens.buttonRadius,
                            ),
                          ),
                          child: const Text('OPEN PRIVACY POLICY'),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Text(
                          'ACTIVE SESSIONS',
                          style: TypographyTokens.labelSmall(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          'Use the action below to revoke any other active sessions linked to your account.',
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  AfriButton(
                    label: _isSaving ? 'Saving…' : 'Save privacy settings',
                    fullWidth: true,
                    isLoading: _isSaving,
                    onTap: () => _saveSettings(settings),
                    enabled: !_isSaving,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriOutlinedButton(
                    onPressed: _isSaving ? null : _signOutOtherDevices,
                    style: AfriOutlinedButton.styleFrom(
                      minimumSize: const Size(
                        double.infinity,
                        SizeTokens.buttonMinHeight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: ShapeTokens.buttonRadius,
                      ),
                    ),
                    child: const Text('SIGN OUT OTHER DEVICES'),
                  ),
                ],
              ),
      ),
    );
  }
}
