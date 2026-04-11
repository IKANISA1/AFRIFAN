import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  static const Map<String, String> _visibilityOptions = <String, String>{
    'PUBLIC': 'public',
    'MEMBERS ONLY': 'members',
    'PRIVATE': 'private',
  };

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        appBar: AppBar(
          title: Text(
            'PRIVACY',
            style: TypographyTokens.monolithFont(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          leading: IconButton(
            onPressed: () => closeSettingsChild(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: settings == null
            ? asyncSettings.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(SpacingTokens.spacing6),
                        child: Text(
                          'Could not load privacy settings.',
                          style: TypographyTokens.bodyMedium(),
                          textAlign: TextAlign.center,
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
                          'GROUP VISIBILITY',
                          style: TypographyTokens.labelSmall(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Wrap(
                          spacing: SpacingTokens.spacing2,
                          children: _visibilityOptions.entries.map((entry) {
                            return ChoiceChip(
                              selected: settings.groupVisibility == entry.value,
                              label: Text(entry.key),
                              onSelected: (_) => setState(
                                () => _draft = settings.copyWith(
                                  groupVisibility: entry.value,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        SwitchListTile(
                          value: settings.analyticsEnabled,
                          onChanged: (value) => setState(
                            () => _draft = settings.copyWith(
                              analyticsEnabled: value,
                            ),
                          ),
                          title: const Text('Analytics data'),
                        ),
                        SwitchListTile(
                          value: settings.biometricLoginEnabled,
                          onChanged: (value) => setState(
                            () => _draft = settings.copyWith(
                              biometricLoginEnabled: value,
                            ),
                          ),
                          title: const Text('Biometric login'),
                        ),
                        SwitchListTile(
                          value: settings.showActivityStatus,
                          onChanged: (value) => setState(
                            () => _draft = settings.copyWith(
                              showActivityStatus: value,
                            ),
                          ),
                          title: const Text('Show activity status'),
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
                          'Request a data export via club support.',
                          style: TypographyTokens.bodyMedium(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        ClaymorphicButton(
                          label: 'REQUEST DATA EXPORT',
                          width: double.infinity,
                          onPressed: () async {
                            await launchWhatsApp(
                              context,
                              message:
                                  'Data export request for $appName. Please send me a copy of my account data.',
                              failureMessage: 'Could not open WhatsApp.',
                            );
                          },
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        OutlinedButton(
                          onPressed: () async {
                            await launchExternalUri(
                              context,
                              Uri.parse(AppLinks.privacyPolicyUrl),
                              failureMessage:
                                  'Privacy policy is not available yet.',
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
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
                          'Current device session  •  Active now',
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  ClaymorphicButton(
                    label: _isSaving ? 'SAVING...' : 'SAVE PRIVACY SETTINGS',
                    width: double.infinity,
                    onPressed: _isSaving ? null : () => _saveSettings(settings),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  OutlinedButton(
                    onPressed: _isSaving ? null : _signOutOtherDevices,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
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
