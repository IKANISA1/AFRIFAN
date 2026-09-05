import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_notification_settings.dart';
import '../settings_providers.dart';
import '../settings_repository.dart';
import '../widgets/settings_navigation_scope.dart';
import '../widgets/settings_overlays.dart';

enum NotificationPreferencesFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class NotificationPreferencesFailure implements Exception {
  const NotificationPreferencesFailure(this.kind);

  final NotificationPreferencesFailureKind kind;

  static NotificationPreferencesFailure fromError(Object error) {
    if (error is NotificationPreferencesFailure) return error;
    if (error is SettingsConflictException) {
      return const NotificationPreferencesFailure(
        NotificationPreferencesFailureKind.conflict,
      );
    }
    if (error is TimeoutException) {
      return const NotificationPreferencesFailure(
        NotificationPreferencesFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const NotificationPreferencesFailure(
        NotificationPreferencesFailureKind.permissionDenied,
      );
    }
    return const NotificationPreferencesFailure(
      NotificationPreferencesFailureKind.unknown,
    );
  }
}

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({
    this.operationTimeout = const Duration(seconds: 12),
    this.deliveryFocusNode,
    super.key,
  });

  final Duration operationTimeout;
  final FocusNode? deliveryFocusNode;

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  UserNotificationSettings? _draft;
  String? _draftUserId;
  bool _isSaving = false;
  PushPermissionStatus? _permissionStatus;
  String? _localStatusMessage;
  bool _draftEdited = false;
  bool _saveBlocked = false;
  NotificationPreferencesFailure? _operationFailure;
  late bool _wasOnline;

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
    unawaited(_refreshPermissionStatus());
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
            context.afriL10n.notificationPreferencesConnectionRestoredReview;
      });
      return;
    }

    setState(() {
      _draft = null;
      _draftUserId = null;
      _localStatusMessage =
          context.afriL10n.notificationPreferencesConnectionRestoredRefreshing;
    });
    ref.invalidate(notificationSettingsProvider);
  }

  Future<void> _refreshPermissionStatus() async {
    PushPermissionStatus status;
    try {
      status = await ref
          .read(notificationPermissionGatewayProvider)
          .getPermissionStatus()
          .timeout(widget.operationTimeout);
    } catch (_) {
      status = PushPermissionStatus.unavailable;
    }
    if (!mounted) return;
    setState(() => _permissionStatus = status);
  }

  void _syncDraft(UserNotificationSettings settings) {
    if (_draftUserId == settings.userId) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _draft = settings;
        _draftUserId = settings.userId;
        _draftEdited = false;
      });
    });
  }

  UserNotificationSettings _normalizeForSave(
    UserNotificationSettings settings,
  ) {
    final enabled = settings.pushEnabled;
    return settings.copyWith(
      allowAll: enabled,
      matchAlerts: enabled,
      contributionReceipts: enabled,
      fetMilestones: enabled,
      teamNews: enabled,
      challenges: enabled,
      groupChat: enabled,
    );
  }

  Future<void> _togglePush(UserNotificationSettings settings) async {
    if (_isSaving ||
        _saveBlocked ||
        _permissionStatus == PushPermissionStatus.unavailable) {
      return;
    }
    if (!ConnectivityService.isOnline) {
      _showMessage(
        context.afriL10n.notificationPreferencesConnectBeforeChanging,
      );
      return;
    }
    if (settings.pushEnabled) {
      try {
        await ref
            .read(notificationPermissionGatewayProvider)
            .unregisterCurrentDevice()
            .timeout(widget.operationTimeout);
      } catch (error) {
        if (!mounted) return;
        _recordOperationFailure(
          NotificationPreferencesFailure.fromError(error),
        );
        return;
      }
      setState(() {
        _draft = settings.copyWith(pushEnabled: false);
        _draftEdited = true;
        _localStatusMessage =
            context.afriL10n.notificationPreferencesDeviceTurnedOff;
      });
      await _refreshPermissionStatus();
      return;
    }

    final enabled = await showNotificationPermissionModal(context);
    if (!enabled || !mounted) return;

    PushPermissionStatus status;
    try {
      status = await ref
          .read(notificationPermissionGatewayProvider)
          .requestPermission()
          .timeout(widget.operationTimeout);
    } catch (error) {
      if (!mounted) return;
      _recordOperationFailure(NotificationPreferencesFailure.fromError(error));
      return;
    }
    if (!mounted) return;

    switch (status) {
      case PushPermissionStatus.authorized:
      case PushPermissionStatus.provisional:
        setState(() {
          _draft = settings.copyWith(pushEnabled: true);
          _draftEdited = true;
          _localStatusMessage =
              context.afriL10n.notificationPreferencesPermissionGranted;
        });
        break;
      case PushPermissionStatus.denied:
        _showMessage(context.afriL10n.notificationPreferencesBlocked);
        break;
      case PushPermissionStatus.notDetermined:
        _showMessage(context.afriL10n.notificationPreferencesPermissionPending);
        break;
      case PushPermissionStatus.unavailable:
        _showMessage(context.afriL10n.notificationPreferencesPushUnavailable);
        break;
    }

    await _refreshPermissionStatus();
  }

  Future<void> _saveSettings(UserNotificationSettings settings) async {
    if (_isSaving || _saveBlocked) return;
    if (!ConnectivityService.isOnline) {
      _showMessage(context.afriL10n.notificationPreferencesDraftKeptConnect);
      return;
    }

    setState(() {
      _isSaving = true;
      _operationFailure = null;
    });

    try {
      final saved = await ref
          .read(notificationSettingsWriterProvider)
          .save(_normalizeForSave(settings))
          .timeout(widget.operationTimeout);
      if (saved.pushEnabled) {
        await ref
            .read(notificationPermissionGatewayProvider)
            .syncToken()
            .timeout(widget.operationTimeout);
      } else {
        await ref
            .read(notificationPermissionGatewayProvider)
            .unregisterCurrentDevice()
            .timeout(widget.operationTimeout);
      }
      ref.invalidate(notificationSettingsProvider);
      if (!mounted) return;
      setState(() {
        _draft = saved;
        _draftEdited = false;
        _localStatusMessage = null;
        _saveBlocked = false;
      });
      _showMessage(context.afriL10n.notificationPreferencesSaved);
    } catch (error) {
      final failure = NotificationPreferencesFailure.fromError(error);
      if (failure.kind == NotificationPreferencesFailureKind.conflict) {
        ref.invalidate(notificationSettingsProvider);
        if (!mounted) return;
        setState(() {
          _draft = null;
          _draftUserId = null;
          _operationFailure = failure;
          _localStatusMessage =
              context.afriL10n.notificationPreferencesChangedElsewhereLoading;
        });
        unawaited(
          FirebaseAnalyticsService.logErrorRecovery(
            surface: 'notification_settings',
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

  void _recordOperationFailure(NotificationPreferencesFailure failure) {
    if (!mounted) return;
    final blocksSave =
        failure.kind == NotificationPreferencesFailureKind.permissionDenied ||
        failure.kind == NotificationPreferencesFailureKind.securityTimeout;
    setState(() {
      _operationFailure = failure;
      _saveBlocked = blocksSave;
      _localStatusMessage = switch (failure.kind) {
        NotificationPreferencesFailureKind.permissionDenied =>
          context.afriL10n.notificationPreferencesChangeNotPermitted,
        NotificationPreferencesFailureKind.conflict =>
          context.afriL10n.notificationPreferencesChangedRefresh,
        NotificationPreferencesFailureKind.securityTimeout =>
          context.afriL10n.notificationPreferencesSaveUnconfirmed,
        NotificationPreferencesFailureKind.unknown =>
          context.afriL10n.notificationPreferencesSaveFailedDraftKept,
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
      _localStatusMessage = context.afriL10n.notificationPreferencesRefreshing;
    });
    ref.invalidate(notificationSettingsProvider);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    AfriToast.info(context, message);
  }

  Widget _buildUnavailableRoute(
    AsyncValue<UserNotificationSettings?> asyncSettings,
    bool isOnline,
  ) {
    final l10n = context.afriL10n;
    if (asyncSettings.isLoading) {
      return AfriStateView.loading(
        key: const ValueKey<String>('notifications-state-loading'),
        title: l10n.notificationPreferencesLoadingTitle,
        message: l10n.notificationPreferencesLoadingMessage,
      );
    }

    if (!isOnline) {
      return AfriStateView.offline(
        key: const ValueKey<String>('notifications-state-offline'),
        title: l10n.notificationPreferencesOfflineTitle,
        message: l10n.notificationPreferencesOfflineMessage,
      );
    }

    if (!asyncSettings.hasError) {
      return AfriStateView.empty(
        key: const ValueKey<String>('notifications-state-empty'),
        title: l10n.notificationPreferencesUnavailableTitle,
        message: l10n.notificationPreferencesUnavailableMessage,
        icon: AfriIcons.notifications,
      );
    }

    final failure = NotificationPreferencesFailure.fromError(
      asyncSettings.error!,
    );
    return switch (failure.kind) {
      NotificationPreferencesFailureKind.permissionDenied =>
        AfriStateView.error(
          key: const ValueKey<String>('notifications-state-permission-denied'),
          title: l10n.notificationPreferencesAccessLimitedTitle,
          message: l10n.notificationPreferencesAccessLimitedMessage,
          actionLabel: l10n.retry,
          onAction: _recoverSettings,
        ),
      NotificationPreferencesFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('notifications-state-conflict'),
        title: l10n.notificationPreferencesChangedTitle,
        message: l10n.notificationPreferencesChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: _recoverSettings,
      ),
      NotificationPreferencesFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('notifications-state-security-timeout'),
        title: l10n.notificationPreferencesSecurityTimeoutTitle,
        message: l10n.notificationPreferencesSecurityTimeoutMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: _recoverSettings,
      ),
      NotificationPreferencesFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('notifications-state-error'),
        title: l10n.notificationPreferencesLoadFailedTitle,
        message: l10n.notificationPreferencesLoadFailedMessage,
        actionLabel: l10n.retry,
        onAction: _recoverSettings,
      ),
    };
  }

  Widget? _buildRouteStateBanner(
    AsyncValue<UserNotificationSettings?> asyncSettings,
    bool isOnline,
  ) {
    final l10n = context.afriL10n;
    if (_isSaving) {
      return AfriStateBanner(
        key: const ValueKey<String>('notifications-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.notificationPreferencesSavingTitle,
        subtitle: l10n.notificationPreferencesSavingMessage,
        tone: AfriStateBannerTone.info,
        trailing: const AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (asyncSettings.isRefreshing) {
      return AfriStateBanner(
        key: const ValueKey<String>('notifications-state-refreshing'),
        icon: AfriIcons.refresh,
        title: l10n.notificationPreferencesRefreshingTitle,
        subtitle: l10n.notificationPreferencesRefreshingMessage,
        tone: AfriStateBannerTone.info,
        trailing: const AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (_operationFailure != null) {
      return switch (_operationFailure!.kind) {
        NotificationPreferencesFailureKind.permissionDenied => AfriStateBanner(
          key: const ValueKey<String>(
            'notifications-state-save-permission-denied',
          ),
          icon: AfriIcons.lock,
          title: l10n.notificationPreferencesEditingUnavailableTitle,
          subtitle: l10n.notificationPreferencesEditingUnavailableMessage,
          tone: AfriStateBannerTone.warning,
        ),
        NotificationPreferencesFailureKind.conflict => AfriStateBanner(
          key: const ValueKey<String>('notifications-state-save-conflict'),
          icon: AfriIcons.refresh,
          title: l10n.notificationPreferencesChangedElsewhereTitle,
          subtitle: l10n.notificationPreferencesChangedElsewhereMessage,
          onTap: _recoverSettings,
          tone: AfriStateBannerTone.warning,
        ),
        NotificationPreferencesFailureKind.securityTimeout => AfriStateBanner(
          key: const ValueKey<String>(
            'notifications-state-save-security-timeout',
          ),
          icon: AfriIcons.lock,
          title: l10n.notificationPreferencesSaveNotConfirmedTitle,
          subtitle: l10n.notificationPreferencesSaveNotConfirmedMessage,
          onTap: _recoverSettings,
          tone: AfriStateBannerTone.warning,
        ),
        NotificationPreferencesFailureKind.unknown => AfriStateBanner(
          key: const ValueKey<String>('notifications-state-save-error'),
          icon: AfriIcons.statusError,
          title: l10n.notificationPreferencesSaveFailedTitle,
          subtitle: l10n.notificationPreferencesSaveFailedMessage,
          tone: AfriStateBannerTone.danger,
        ),
      };
    }
    if (!isOnline) {
      return AfriStateBanner(
        key: const ValueKey<String>('notifications-state-offline'),
        icon: AfriIcons.offline,
        title: l10n.notificationPreferencesSavedSettingsTitle,
        subtitle: l10n.notificationPreferencesSavedSettingsMessage,
        tone: AfriStateBannerTone.warning,
      );
    }
    if (_permissionStatus == null) {
      return AfriStateBanner(
        key: const ValueKey<String>('notifications-state-permission-check'),
        icon: AfriIcons.notifications,
        title: l10n.notificationPreferencesCheckingPermissionsTitle,
        subtitle: l10n.notificationPreferencesCheckingPermissionsMessage,
        tone: AfriStateBannerTone.info,
        trailing: const AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (_permissionStatus == PushPermissionStatus.unavailable) {
      return AfriStateBanner(
        key: const ValueKey<String>('notifications-state-disabled'),
        icon: AfriIcons.notifications,
        title: l10n.notificationPreferencesDeviceAlertsUnavailableTitle,
        subtitle: l10n.notificationPreferencesDeviceAlertsUnavailableMessage,
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
    final asyncSettings = ref.watch(notificationSettingsProvider);
    final loadedSettings = asyncSettings.valueOrNull;
    if (loadedSettings != null) {
      _syncDraft(loadedSettings);
    }

    final settings = _draft ?? loadedSettings;
    final permissionStatus = _permissionStatus;
    final permissionCopy = switch (permissionStatus) {
      PushPermissionStatus.authorized || PushPermissionStatus.provisional =>
        l10n.notificationPreferencesPermissionEnabled,
      PushPermissionStatus.denied =>
        l10n.notificationPreferencesPermissionBlocked,
      PushPermissionStatus.notDetermined =>
        l10n.notificationPreferencesPermissionNotRequested,
      PushPermissionStatus.unavailable =>
        l10n.notificationPreferencesPermissionNotConfigured,
      null => l10n.notificationPreferencesPermissionChecking,
    };

    return SettingsBackGuard(
      child: AfriScreenScaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          title: Text(
            l10n.notificationPreferencesTitle,
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
                    if (_buildRouteStateBanner(asyncSettings, isOnline)
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
                            l10n.notificationPreferencesDeliverySection,
                            style: TypographyTokens.labelSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            settings.pushEnabled
                                ? l10n.notificationPreferencesAlertsEnabled
                                : l10n.notificationPreferencesEnableAlertsDescription,
                            style: TypographyTokens.bodyMedium(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            permissionCopy,
                            style: TypographyTokens.bodySmall(),
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
                          const SizedBox(height: SpacingTokens.spacing4),
                          Semantics(
                            toggled: settings.pushEnabled,
                            label: l10n.notificationPreferencesDeviceDelivery,
                            child: AfriButton(
                              key: const ValueKey<String>(
                                'notifications-delivery-action',
                              ),
                              label: !isOnline
                                  ? l10n.notificationPreferencesConnectionRequiredUpper
                                  : settings.pushEnabled
                                  ? l10n.notificationPreferencesDisableAlerts
                                  : l10n.notificationPreferencesEnableAlerts,
                              variant: AfriButtonVariant.outline,
                              fullWidth: true,
                              labelMaxLines: 2,
                              focusNode: widget.deliveryFocusNode,
                              onTap: () => _togglePush(settings),
                              enabled:
                                  isOnline &&
                                  !_isSaving &&
                                  !_saveBlocked &&
                                  permissionStatus != null &&
                                  permissionStatus !=
                                      PushPermissionStatus.unavailable,
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
                          Text(
                            l10n.notificationPreferencesDeliveryModel,
                            style: TypographyTokens.labelSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            l10n.notificationPreferencesFullStream(appName),
                            style: TypographyTokens.bodyMedium(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            l10n.notificationPreferencesPerCategory,
                            style: TypographyTokens.bodySmall(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing6),
                    AfriButton(
                      key: const ValueKey<String>('notifications-save-action'),
                      label: !isOnline
                          ? l10n.settingsConnectionRequired
                          : _isSaving
                          ? l10n.editProfileSaving
                          : l10n.notificationPreferencesSave,
                      fullWidth: true,
                      isLoading: _isSaving,
                      onTap: () => _saveSettings(settings),
                      enabled: isOnline && !_isSaving && !_saveBlocked,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
