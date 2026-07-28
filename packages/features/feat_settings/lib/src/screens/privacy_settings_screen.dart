import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_sms_ledger/feat_sms_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_privacy_settings.dart';
import '../settings_actions.dart';
import '../settings_providers.dart';
import '../settings_repository.dart';
import '../widgets/settings_navigation_scope.dart';
import '../widgets/settings_overlays.dart';

enum PrivacySettingsFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class PrivacySettingsFailure implements Exception {
  const PrivacySettingsFailure(this.kind);

  final PrivacySettingsFailureKind kind;

  static PrivacySettingsFailure fromError(Object error) {
    if (error is PrivacySettingsFailure) return error;
    if (error is SettingsConflictException) {
      return const PrivacySettingsFailure(PrivacySettingsFailureKind.conflict);
    }
    if (error is TimeoutException) {
      return const PrivacySettingsFailure(
        PrivacySettingsFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const PrivacySettingsFailure(
        PrivacySettingsFailureKind.permissionDenied,
      );
    }
    return const PrivacySettingsFailure(PrivacySettingsFailureKind.unknown);
  }
}

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({
    this.operationTimeout = const Duration(seconds: 12),
    this.saveFocusNode,
    super.key,
  });

  final Duration operationTimeout;
  final FocusNode? saveFocusNode;

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  UserPrivacySettings? _draft;
  String? _draftUserId;
  bool _isSaving = false;
  bool _draftEdited = false;
  bool _saveBlocked = false;
  PrivacySettingsFailure? _operationFailure;
  String? _localStatusMessage;
  late bool _wasOnline;

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    super.dispose();
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;
    if (!mounted || !restored) return;

    if (_draftEdited) {
      setState(() {
        _localStatusMessage =
            'Connection restored. Review your kept changes, then save.';
      });
      return;
    }

    setState(() {
      _draft = null;
      _draftUserId = null;
      _localStatusMessage = 'Connection restored. Refreshing privacy settings.';
    });
    ref.invalidate(privacySettingsProvider);
  }

  void _syncDraft(UserPrivacySettings settings) {
    if (_draftUserId == settings.userId) return;

    unawaited(_configureAnalyticsConsent(settings.analyticsEnabled));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _draft = settings;
        _draftUserId = settings.userId;
        _draftEdited = false;
      });
    });
  }

  Future<void> _configureAnalyticsConsent(bool enabled) async {
    try {
      await FirebaseAnalyticsService.configureConsent(
        enabled: enabled,
      ).timeout(widget.operationTimeout);
    } catch (_) {
      // Consent remains fail-closed when the local analytics bridge is absent.
    }
  }

  void _setAnalytics(UserPrivacySettings settings, bool value) {
    if (_isSaving || _saveBlocked) return;
    setState(() {
      _draft = settings.copyWith(analyticsEnabled: value);
      _draftEdited = true;
      _operationFailure = null;
      _localStatusMessage = 'Privacy change ready to save.';
    });
  }

  void _setMomoSmsAutoread(UserPrivacySettings settings, bool value) {
    if (_isSaving || _saveBlocked) return;
    setState(() {
      _draft = settings.copyWith(momoSmsAutoreadEnabled: value);
      _draftEdited = true;
      _operationFailure = null;
      _localStatusMessage = 'Privacy change ready to save.';
    });
  }

  Future<void> _saveSettings(UserPrivacySettings settings) async {
    if (_isSaving || _saveBlocked || !_draftEdited) return;
    if (!ConnectivityService.isOnline) {
      _showMessage('Your changes are kept. Connect before saving.');
      return;
    }

    setState(() {
      _isSaving = true;
      _operationFailure = null;
    });

    try {
      final saved = await ref
          .read(privacySettingsWriterProvider)
          .save(settings)
          .timeout(widget.operationTimeout);
      if (EnvConfig.enableAndroidMomoSmsAutoread) {
        await _synchronizeSmsAutoreadConsent(
          saved,
        ).timeout(widget.operationTimeout);
      }
      await FirebaseAnalyticsService.configureConsent(
        enabled: saved.analyticsEnabled,
      ).timeout(widget.operationTimeout);
      ref.invalidate(privacySettingsProvider);
      if (!mounted) return;
      setState(() {
        _draft = saved;
        _draftUserId = saved.userId;
        _draftEdited = false;
        _saveBlocked = false;
        _operationFailure = null;
        _localStatusMessage = null;
      });
      _showMessage('Privacy settings saved.');
    } catch (error) {
      final failure = PrivacySettingsFailure.fromError(error);
      if (failure.kind == PrivacySettingsFailureKind.conflict) {
        ref.invalidate(privacySettingsProvider);
        if (!mounted) return;
        setState(() {
          _draft = null;
          _draftUserId = null;
          _draftEdited = false;
          _operationFailure = failure;
          _localStatusMessage =
              'Privacy settings changed elsewhere. The latest version is loading; review it before saving again.';
        });
        unawaited(
          FirebaseAnalyticsService.logErrorRecovery(
            surface: 'privacy_settings',
            outcome: 'conflict_refresh',
          ),
        );
        return;
      }
      if (!mounted) return;
      _recordOperationFailure(failure);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _recordOperationFailure(PrivacySettingsFailure failure) {
    final blocksSave =
        failure.kind == PrivacySettingsFailureKind.permissionDenied ||
        failure.kind == PrivacySettingsFailureKind.securityTimeout;
    setState(() {
      _operationFailure = failure;
      _saveBlocked = blocksSave;
      _localStatusMessage = switch (failure.kind) {
        PrivacySettingsFailureKind.permissionDenied =>
          'Privacy changes are not permitted for this account.',
        PrivacySettingsFailureKind.conflict =>
          'Privacy settings changed elsewhere. Refresh before saving again.',
        PrivacySettingsFailureKind.securityTimeout =>
          'Privacy save was not confirmed. Refresh before trying again.',
        PrivacySettingsFailureKind.unknown =>
          'Privacy settings could not be saved. Your draft is kept.',
      };
    });
    _showMessage(_localStatusMessage!);
  }

  Future<void> _recoverSettings() async {
    if (_isSaving) return;
    setState(() {
      _draft = null;
      _draftUserId = null;
      _draftEdited = false;
      _saveBlocked = false;
      _operationFailure = null;
      _localStatusMessage = 'Refreshing privacy settings.';
    });
    ref.invalidate(privacySettingsProvider);
  }

  Future<void> _signOutOtherDevices() async {
    if (_isSaving || _saveBlocked) return;
    if (!ConnectivityService.isOnline) {
      _showMessage('Connect before signing out other devices.');
      return;
    }

    final confirmed = await showSignOutOtherDevicesSheet(context);
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final error = await ref
          .read(authStateProvider.notifier)
          .signOutOtherSessions()
          .timeout(widget.operationTimeout);
      if (!mounted) return;
      _showMessage(
        error == null
            ? 'Other sessions were signed out.'
            : 'Could not sign out other devices. Try again.',
      );
    } on TimeoutException {
      if (!mounted) return;
      _showMessage('Session security check timed out. Try again.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not sign out other devices. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
    if (!mounted || started) return;

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
            'The app reads only approved Mobile Money verification SMS on this device to match contribution payments. It cannot access other messages.',
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

  Widget _buildUnavailableRoute(
    AsyncValue<UserPrivacySettings?> asyncSettings,
    bool isOnline,
  ) {
    if (asyncSettings.isLoading) {
      return AfriStateView.loading(
        key: const ValueKey<String>('privacy-state-loading'),
        title: 'Loading privacy settings',
        message: 'Checking your saved privacy choices.',
      );
    }
    if (!isOnline) {
      return AfriStateView.offline(
        key: const ValueKey<String>('privacy-state-offline'),
        title: 'Privacy settings are offline',
        message: 'Connect to load your saved privacy choices.',
      );
    }
    if (!asyncSettings.hasError) {
      return AfriStateView.empty(
        key: const ValueKey<String>('privacy-state-empty'),
        title: 'Privacy settings unavailable',
        message: 'Sign in to review and manage your privacy choices.',
        icon: AfriIcons.privacy,
      );
    }

    final failure = PrivacySettingsFailure.fromError(asyncSettings.error!);
    return switch (failure.kind) {
      PrivacySettingsFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('privacy-state-permission-denied'),
        title: 'Privacy access limited',
        message: 'Your privacy settings could not be verified. Sign in again.',
        actionLabel: 'Retry',
        onAction: _recoverSettings,
      ),
      PrivacySettingsFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('privacy-state-conflict'),
        title: 'Privacy settings changed',
        message: 'Refresh to load the current choices before editing.',
        actionLabel: 'Refresh',
        onAction: _recoverSettings,
      ),
      PrivacySettingsFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('privacy-state-security-timeout'),
        title: 'Privacy security check timed out',
        message: 'Check your connection and refresh.',
        actionLabel: 'Refresh',
        onAction: _recoverSettings,
      ),
      PrivacySettingsFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('privacy-state-error'),
        title: 'Could not load privacy settings.',
        message: 'Your saved choices are still safe. Try again.',
        actionLabel: 'Retry',
        onAction: _recoverSettings,
      ),
    };
  }

  Widget? _buildRouteStateBanner(
    AsyncValue<UserPrivacySettings?> asyncSettings,
    bool isOnline,
    bool editingEnabled,
  ) {
    if (_isSaving) {
      return const AfriStateBanner(
        key: ValueKey<String>('privacy-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Saving privacy settings',
        subtitle: 'Your choices stay visible while the save is confirmed.',
        tone: AfriStateBannerTone.info,
        trailing: AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (asyncSettings.isRefreshing) {
      return const AfriStateBanner(
        key: ValueKey<String>('privacy-state-refreshing'),
        icon: AfriIcons.refresh,
        title: 'Refreshing privacy settings',
        subtitle: 'Your saved choices stay visible.',
        tone: AfriStateBannerTone.info,
        trailing: AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (_operationFailure != null) {
      return switch (_operationFailure!.kind) {
        PrivacySettingsFailureKind.permissionDenied => const AfriStateBanner(
          key: ValueKey<String>('privacy-state-save-permission-denied'),
          icon: AfriIcons.lock,
          title: 'Privacy editing unavailable',
          subtitle: 'Your saved choices stay visible.',
          tone: AfriStateBannerTone.warning,
        ),
        PrivacySettingsFailureKind.conflict => AfriStateBanner(
          key: const ValueKey<String>('privacy-state-save-conflict'),
          icon: AfriIcons.refresh,
          title: 'Privacy settings changed elsewhere',
          subtitle: 'Refresh and review the latest choices.',
          onTap: _recoverSettings,
          tone: AfriStateBannerTone.warning,
        ),
        PrivacySettingsFailureKind.securityTimeout => AfriStateBanner(
          key: const ValueKey<String>('privacy-state-save-security-timeout'),
          icon: AfriIcons.lock,
          title: 'Privacy save not confirmed',
          subtitle: 'Refresh before trying again. Your draft is kept.',
          onTap: _recoverSettings,
          tone: AfriStateBannerTone.warning,
        ),
        PrivacySettingsFailureKind.unknown => const AfriStateBanner(
          key: ValueKey<String>('privacy-state-save-error'),
          icon: AfriIcons.statusError,
          title: 'Privacy settings could not be saved',
          subtitle: 'Your draft is still here.',
          tone: AfriStateBannerTone.danger,
        ),
      };
    }
    if (!isOnline) {
      return const AfriStateBanner(
        key: ValueKey<String>('privacy-state-offline'),
        icon: AfriIcons.offline,
        title: 'Saved privacy settings',
        subtitle:
            'Values may be out of date. Reconnect before changing or saving.',
        tone: AfriStateBannerTone.warning,
      );
    }
    if (!editingEnabled) {
      return const AfriStateBanner(
        key: ValueKey<String>('privacy-state-disabled'),
        icon: AfriIcons.lock,
        title: 'Privacy editing unavailable',
        subtitle: 'Your saved choices remain visible in this build.',
        tone: AfriStateBannerTone.neutral,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appName =
        ClubConfigScope.maybeOf(context)?.appName ??
        RuntimeBranding.displayAppName;
    final asyncSettings = ref.watch(privacySettingsProvider);
    final editingEnabled = ref.watch(privacySettingsEditingEnabledProvider);
    final loadedSettings = asyncSettings.valueOrNull;
    if (loadedSettings != null) {
      _syncDraft(loadedSettings);
    }
    final settings = _draft ?? loadedSettings;

    return SettingsBackGuard(
      child: AfriScreenScaffold(
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
        scrollable: false,
        child: ConnectivityBuilder(
          builder: (context, isOnline) => settings == null
              ? Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: _buildUnavailableRoute(asyncSettings, isOnline),
                )
              : ListView(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  children: [
                    if (_buildRouteStateBanner(
                          asyncSettings,
                          isOnline,
                          editingEnabled,
                        )
                        case final banner?)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: SpacingTokens.spacing4,
                        ),
                        child: banner,
                      ),
                    GlassCard(
                      animate: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRIVACY CONTROLS',
                            style: TypographyTokens.labelSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            'Choose whether to share coarse, anonymous task events. Queries, contacts, account IDs, codes, messages, and exact payment values are never included.',
                            style: TypographyTokens.bodyMedium(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          if (EnvConfig.enableAndroidMomoSmsAutoread)
                            Semantics(
                              toggled: settings.momoSmsAutoreadEnabled,
                              child: AfriSwitchListTile(
                                key: const ValueKey<String>(
                                  'privacy-sms-toggle',
                                ),
                                value: settings.momoSmsAutoreadEnabled,
                                onChanged:
                                    isOnline &&
                                        editingEnabled &&
                                        !_isSaving &&
                                        !_saveBlocked
                                    ? (value) =>
                                          _setMomoSmsAutoread(settings, value)
                                    : null,
                                title: const Text('MoMo SMS sync'),
                                subtitle: const Text(
                                  'Match approved Mobile Money verification SMS for faster contribution checks.',
                                ),
                              ),
                            ),
                          Semantics(
                            toggled: settings.analyticsEnabled,
                            child: AfriSwitchListTile(
                              key: const ValueKey<String>(
                                'privacy-analytics-toggle',
                              ),
                              value: settings.analyticsEnabled,
                              onChanged:
                                  isOnline &&
                                      editingEnabled &&
                                      !_isSaving &&
                                      !_saveBlocked
                                  ? (value) => _setAnalytics(settings, value)
                                  : null,
                              title: const Text(
                                'Share anonymous usage analytics',
                              ),
                              subtitle: const Text(
                                'Help improve search, tickets, contributions, Fan Zone, and recovery flows.',
                              ),
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            'Analytics stays off unless you opt in and the signed release has an approved analytics configuration.',
                            style: TypographyTokens.bodySmall(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                          if (_localStatusMessage != null) ...[
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              _localStatusMessage!,
                              style: TypographyTokens.bodySmall(
                                ColorTokens.clubAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriButton(
                      key: const ValueKey<String>('privacy-save-action'),
                      label: !isOnline
                          ? 'Connection required'
                          : _isSaving
                          ? 'Saving…'
                          : !_draftEdited
                          ? 'No changes to save'
                          : 'Save privacy settings',
                      fullWidth: true,
                      labelMaxLines: 2,
                      isLoading: _isSaving,
                      focusNode: widget.saveFocusNode,
                      onTap: () => _saveSettings(settings),
                      enabled:
                          isOnline &&
                          editingEnabled &&
                          _draftEdited &&
                          !_isSaving &&
                          !_saveBlocked,
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    GlassCard(
                      animate: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR DATA',
                            style: TypographyTokens.labelSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            'Request an account export through a configured support channel.',
                            style: TypographyTokens.bodyMedium(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriButton(
                            key: const ValueKey<String>(
                              'privacy-export-action',
                            ),
                            label: 'Request data export',
                            fullWidth: true,
                            variant: AfriButtonVariant.outline,
                            onTap: () async {
                              if (AppLinks.hasSupportWhatsApp) {
                                await launchWhatsApp(
                                  context,
                                  message:
                                      'Data export request for $appName. Please send me a copy of my account data.',
                                  failureMessage: 'Could not open WhatsApp.',
                                );
                                return;
                              }
                              await launchMailTo(
                                context,
                                email: AppLinks.supportEmail,
                                subject: '$appName data export request',
                                body:
                                    'Please send me a copy of my account data.',
                                failureMessage: 'Could not open your mail app.',
                              );
                            },
                            enabled:
                                AppLinks.hasSupportWhatsApp ||
                                AppLinks.hasSupportEmail,
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriButton(
                            key: const ValueKey<String>(
                              'privacy-policy-action',
                            ),
                            label: AppLinks.hasPrivacyPolicy
                                ? 'Open privacy policy'
                                : 'Privacy policy unavailable',
                            fullWidth: true,
                            variant: AfriButtonVariant.outline,
                            onTap: () async {
                              final uri = AppLinks.privacyPolicyUri;
                              if (uri == null) return;
                              await launchExternalUri(
                                context,
                                uri,
                                failureMessage:
                                    'Privacy policy is not available yet.',
                              );
                            },
                            enabled: AppLinks.hasPrivacyPolicy,
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          Text(
                            'ACTIVE SESSIONS',
                            style: TypographyTokens.labelSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            'Revoke other active sessions linked to your account.',
                            style: TypographyTokens.bodyMedium(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriButton(
                            key: const ValueKey<String>(
                              'privacy-sessions-action',
                            ),
                            label: !isOnline
                                ? 'Connection required'
                                : 'Sign out other devices',
                            variant: AfriButtonVariant.outline,
                            fullWidth: true,
                            labelMaxLines: 2,
                            onTap: _signOutOtherDevices,
                            enabled: isOnline && !_isSaving && !_saveBlocked,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
