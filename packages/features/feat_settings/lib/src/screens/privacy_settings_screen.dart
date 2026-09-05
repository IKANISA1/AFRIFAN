import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
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
            context.afriL10n.privacySettingsConnectionRestoredReview;
      });
      return;
    }

    setState(() {
      _draft = null;
      _draftUserId = null;
      _localStatusMessage =
          context.afriL10n.privacySettingsConnectionRestoredRefreshing;
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
      _localStatusMessage = context.afriL10n.privacySettingsChangeReady;
    });
  }

  void _setMomoSmsAutoread(UserPrivacySettings settings, bool value) {
    if (_isSaving || _saveBlocked) return;
    setState(() {
      _draft = settings.copyWith(momoSmsAutoreadEnabled: value);
      _draftEdited = true;
      _operationFailure = null;
      _localStatusMessage = context.afriL10n.privacySettingsChangeReady;
    });
  }

  Future<void> _saveSettings(UserPrivacySettings settings) async {
    if (_isSaving || _saveBlocked || !_draftEdited) return;
    if (!ConnectivityService.isOnline) {
      _showMessage(context.afriL10n.privacySettingsDraftKeptConnect);
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
      _showMessage(context.afriL10n.privacySettingsSaved);
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
              context.afriL10n.privacySettingsChangedElsewhereLoading;
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
          context.afriL10n.privacySettingsChangeNotPermitted,
        PrivacySettingsFailureKind.conflict =>
          context.afriL10n.privacySettingsChangedRefresh,
        PrivacySettingsFailureKind.securityTimeout =>
          context.afriL10n.privacySettingsSaveUnconfirmed,
        PrivacySettingsFailureKind.unknown =>
          context.afriL10n.privacySettingsSaveFailedDraftKept,
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
      _localStatusMessage = context.afriL10n.privacySettingsRefreshing;
    });
    ref.invalidate(privacySettingsProvider);
  }

  Future<void> _signOutOtherDevices() async {
    if (_isSaving || _saveBlocked) return;
    if (!ConnectivityService.isOnline) {
      _showMessage(context.afriL10n.privacySettingsConnectBeforeSigningOut);
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
            ? context.afriL10n.privacySettingsSessionsSignedOut
            : context.afriL10n.privacySettingsSessionsSignOutFailed,
      );
    } on TimeoutException {
      if (!mounted) return;
      _showMessage(context.afriL10n.privacySettingsSessionSecurityTimeout);
    } catch (_) {
      if (!mounted) return;
      _showMessage(context.afriL10n.privacySettingsSessionsSignOutFailed);
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

    _showMessage(context.afriL10n.privacySettingsSmsAccessRequired);
  }

  Future<bool> _showMomoSmsConsentDisclosure() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.afriL10n;
        return AfriAlertDialog(
          title: Text(l10n.privacySettingsEnableMomoSmsTitle),
          content: Text(l10n.privacySettingsMomoSmsDisclosure),
          actions: [
            AfriTextButton(
              onPressed: () => context.pop(false),
              child: Text(l10n.privacySettingsNotNow),
            ),
            AfriButton(
              label: l10n.privacySettingsContinue,
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
    final l10n = context.afriL10n;
    if (asyncSettings.isLoading) {
      return AfriStateView.loading(
        key: const ValueKey<String>('privacy-state-loading'),
        title: l10n.privacySettingsLoadingTitle,
        message: l10n.privacySettingsLoadingMessage,
      );
    }
    if (!isOnline) {
      return AfriStateView.offline(
        key: const ValueKey<String>('privacy-state-offline'),
        title: l10n.privacySettingsOfflineTitle,
        message: l10n.privacySettingsOfflineMessage,
      );
    }
    if (!asyncSettings.hasError) {
      return AfriStateView.empty(
        key: const ValueKey<String>('privacy-state-empty'),
        title: l10n.privacySettingsUnavailableTitle,
        message: l10n.privacySettingsUnavailableMessage,
        icon: AfriIcons.privacy,
      );
    }

    final failure = PrivacySettingsFailure.fromError(asyncSettings.error!);
    return switch (failure.kind) {
      PrivacySettingsFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('privacy-state-permission-denied'),
        title: l10n.privacySettingsAccessLimitedTitle,
        message: l10n.privacySettingsAccessLimitedMessage,
        actionLabel: l10n.retry,
        onAction: _recoverSettings,
      ),
      PrivacySettingsFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('privacy-state-conflict'),
        title: l10n.privacySettingsChangedTitle,
        message: l10n.privacySettingsChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: _recoverSettings,
      ),
      PrivacySettingsFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('privacy-state-security-timeout'),
        title: l10n.privacySettingsSecurityTimeoutTitle,
        message: l10n.privacySettingsSecurityTimeoutMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: _recoverSettings,
      ),
      PrivacySettingsFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('privacy-state-error'),
        title: l10n.privacySettingsLoadFailedTitle,
        message: l10n.privacySettingsLoadFailedMessage,
        actionLabel: l10n.retry,
        onAction: _recoverSettings,
      ),
    };
  }

  Widget? _buildRouteStateBanner(
    AsyncValue<UserPrivacySettings?> asyncSettings,
    bool isOnline,
    bool editingEnabled,
  ) {
    final l10n = context.afriL10n;
    if (_isSaving) {
      return AfriStateBanner(
        key: const ValueKey<String>('privacy-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.privacySettingsSavingTitle,
        subtitle: l10n.privacySettingsSavingMessage,
        tone: AfriStateBannerTone.info,
        trailing: const AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (asyncSettings.isRefreshing) {
      return AfriStateBanner(
        key: const ValueKey<String>('privacy-state-refreshing'),
        icon: AfriIcons.refresh,
        title: l10n.privacySettingsRefreshingTitle,
        subtitle: l10n.privacySettingsRefreshingMessage,
        tone: AfriStateBannerTone.info,
        trailing: const AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (_operationFailure != null) {
      return switch (_operationFailure!.kind) {
        PrivacySettingsFailureKind.permissionDenied => AfriStateBanner(
          key: const ValueKey<String>('privacy-state-save-permission-denied'),
          icon: AfriIcons.lock,
          title: l10n.privacySettingsEditingUnavailableTitle,
          subtitle: l10n.privacySettingsEditingUnavailableMessage,
          tone: AfriStateBannerTone.warning,
        ),
        PrivacySettingsFailureKind.conflict => AfriStateBanner(
          key: const ValueKey<String>('privacy-state-save-conflict'),
          icon: AfriIcons.refresh,
          title: l10n.privacySettingsChangedElsewhereTitle,
          subtitle: l10n.privacySettingsChangedElsewhereMessage,
          onTap: _recoverSettings,
          tone: AfriStateBannerTone.warning,
        ),
        PrivacySettingsFailureKind.securityTimeout => AfriStateBanner(
          key: const ValueKey<String>('privacy-state-save-security-timeout'),
          icon: AfriIcons.lock,
          title: l10n.privacySettingsSaveNotConfirmedTitle,
          subtitle: l10n.privacySettingsSaveNotConfirmedMessage,
          onTap: _recoverSettings,
          tone: AfriStateBannerTone.warning,
        ),
        PrivacySettingsFailureKind.unknown => AfriStateBanner(
          key: const ValueKey<String>('privacy-state-save-error'),
          icon: AfriIcons.statusError,
          title: l10n.privacySettingsSaveFailedTitle,
          subtitle: l10n.privacySettingsSaveFailedMessage,
          tone: AfriStateBannerTone.danger,
        ),
      };
    }
    if (!isOnline) {
      return AfriStateBanner(
        key: const ValueKey<String>('privacy-state-offline'),
        icon: AfriIcons.offline,
        title: l10n.privacySettingsSavedSettingsTitle,
        subtitle: l10n.privacySettingsSavedSettingsMessage,
        tone: AfriStateBannerTone.warning,
      );
    }
    if (!editingEnabled) {
      return AfriStateBanner(
        key: const ValueKey<String>('privacy-state-disabled'),
        icon: AfriIcons.lock,
        title: l10n.privacySettingsEditingUnavailableTitle,
        subtitle: l10n.privacySettingsEditingUnavailableBuildMessage,
        tone: AfriStateBannerTone.neutral,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
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
            l10n.privacySettingsTitle,
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
                            l10n.privacySettingsControls,
                            style: TypographyTokens.labelSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            l10n.privacySettingsControlsDescription,
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
                                title: Text(l10n.privacySettingsMomoSmsSync),
                                subtitle: Text(
                                  l10n.privacySettingsMomoSmsSyncDescription,
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
                              title: Text(l10n.privacySettingsShareAnalytics),
                              subtitle: Text(
                                l10n.privacySettingsShareAnalyticsDescription,
                              ),
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            l10n.privacySettingsAnalyticsFailClosed,
                            style: TypographyTokens.bodySmall(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                          if (_localStatusMessage != null) ...[
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              _localStatusMessage!,
                              style: TypographyTokens.bodySmall(
                                ColorTokens.primaryContainer,
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
                          ? l10n.settingsConnectionRequired
                          : _isSaving
                          ? l10n.editProfileSaving
                          : !_draftEdited
                          ? l10n.privacySettingsNoChanges
                          : l10n.privacySettingsSave,
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
                            l10n.privacySettingsYourData,
                            style: TypographyTokens.labelSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            l10n.privacySettingsExportDescription,
                            style: TypographyTokens.bodyMedium(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriButton(
                            key: const ValueKey<String>(
                              'privacy-export-action',
                            ),
                            label: l10n.privacySettingsExportAction,
                            fullWidth: true,
                            variant: AfriButtonVariant.outline,
                            onTap: () async {
                              if (AppLinks.hasSupportWhatsApp) {
                                await launchWhatsApp(
                                  context,
                                  message: l10n
                                      .privacySettingsExportWhatsAppMessage(
                                        appName,
                                      ),
                                  failureMessage: l10n.settingsWhatsAppFailed,
                                );
                                return;
                              }
                              await launchMailTo(
                                context,
                                email: AppLinks.supportEmail,
                                subject: l10n.privacySettingsExportEmailSubject(
                                  appName,
                                ),
                                body: l10n.privacySettingsExportEmailBody,
                                failureMessage: l10n.privacySettingsMailFailed,
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
                                ? l10n.privacySettingsOpenPolicy
                                : l10n.privacySettingsPolicyUnavailable,
                            fullWidth: true,
                            variant: AfriButtonVariant.outline,
                            onTap: () async {
                              final uri = AppLinks.privacyPolicyUri;
                              if (uri == null) return;
                              await launchExternalUri(
                                context,
                                uri,
                                failureMessage:
                                    l10n.privacySettingsPolicyNotAvailableYet,
                              );
                            },
                            enabled: AppLinks.hasPrivacyPolicy,
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          Text(
                            l10n.privacySettingsActiveSessions,
                            style: TypographyTokens.labelSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            l10n.privacySettingsActiveSessionsDescription,
                            style: TypographyTokens.bodyMedium(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriButton(
                            key: const ValueKey<String>(
                              'privacy-sessions-action',
                            ),
                            label: !isOnline
                                ? l10n.settingsConnectionRequired
                                : l10n.privacySettingsSignOutOtherDevices,
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
