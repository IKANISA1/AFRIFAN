import 'dart:async';

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
            'Connection restored. Review your kept changes, then save.';
      });
      return;
    }

    setState(() {
      _draft = null;
      _draftUserId = null;
      _localStatusMessage = 'Connection restored. Refreshing preferences.';
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
        'Connect before changing notification delivery on this device.',
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
            'Device notifications were turned off. Save to update your account preference.';
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
              'Permission granted on this device. Save to enable alerts on your account.';
        });
        break;
      case PushPermissionStatus.denied:
        _showMessage('Notifications blocked. Enable in device settings.');
        break;
      case PushPermissionStatus.notDetermined:
        _showMessage('Notification permission is still pending.');
        break;
      case PushPermissionStatus.unavailable:
        _showMessage('Push unavailable in this build.');
        break;
    }

    await _refreshPermissionStatus();
  }

  Future<void> _saveSettings(UserNotificationSettings settings) async {
    if (_isSaving || _saveBlocked) return;
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
      _showMessage('Notification preferences saved.');
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
              'Preferences changed elsewhere. The latest version is loading; review it before saving again.';
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
          'Notification changes are not permitted for this account.',
        NotificationPreferencesFailureKind.conflict =>
          'Preferences changed elsewhere. Refresh before saving again.',
        NotificationPreferencesFailureKind.securityTimeout =>
          'Notification save was not confirmed. Refresh before trying again.',
        NotificationPreferencesFailureKind.unknown =>
          'Notification preferences could not be saved. Your draft is kept.',
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
      _localStatusMessage = 'Refreshing notification preferences.';
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
    if (asyncSettings.isLoading) {
      return AfriStateView.loading(
        key: const ValueKey<String>('notifications-state-loading'),
        title: 'Loading notifications',
        message: 'Checking your saved delivery preference.',
      );
    }

    if (!isOnline) {
      return AfriStateView.offline(
        key: const ValueKey<String>('notifications-state-offline'),
        title: 'Notifications are offline',
        message: 'Connect to load your saved notification preference.',
      );
    }

    if (!asyncSettings.hasError) {
      return AfriStateView.empty(
        key: const ValueKey<String>('notifications-state-empty'),
        title: 'Notification preferences unavailable',
        message: 'Sign in to manage notification delivery.',
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
          title: 'Notification access limited',
          message: 'Your preferences could not be verified. Sign in again.',
          actionLabel: 'Retry',
          onAction: _recoverSettings,
        ),
      NotificationPreferencesFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('notifications-state-conflict'),
        title: 'Notification settings changed',
        message: 'Refresh to load the current preference before editing.',
        actionLabel: 'Refresh',
        onAction: _recoverSettings,
      ),
      NotificationPreferencesFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('notifications-state-security-timeout'),
        title: 'Notification security check timed out',
        message: 'Check your connection and refresh.',
        actionLabel: 'Refresh',
        onAction: _recoverSettings,
      ),
      NotificationPreferencesFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('notifications-state-error'),
        title: 'Could not load notification settings.',
        message: 'Your saved preference is still safe. Try again.',
        actionLabel: 'Retry',
        onAction: _recoverSettings,
      ),
    };
  }

  Widget? _buildRouteStateBanner(
    AsyncValue<UserNotificationSettings?> asyncSettings,
    bool isOnline,
  ) {
    if (_isSaving) {
      return const AfriStateBanner(
        key: ValueKey<String>('notifications-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Saving notification preferences',
        subtitle: 'Your choices stay visible while the save is confirmed.',
        tone: AfriStateBannerTone.info,
        trailing: AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (asyncSettings.isRefreshing) {
      return const AfriStateBanner(
        key: ValueKey<String>('notifications-state-refreshing'),
        icon: AfriIcons.refresh,
        title: 'Refreshing notification preferences',
        subtitle: 'Your saved delivery preference stays visible.',
        tone: AfriStateBannerTone.info,
        trailing: AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (_operationFailure != null) {
      return switch (_operationFailure!.kind) {
        NotificationPreferencesFailureKind.permissionDenied =>
          const AfriStateBanner(
            key: ValueKey<String>('notifications-state-save-permission-denied'),
            icon: AfriIcons.lock,
            title: 'Notification editing unavailable',
            subtitle: 'Your saved preference stays visible.',
            tone: AfriStateBannerTone.warning,
          ),
        NotificationPreferencesFailureKind.conflict => AfriStateBanner(
          key: const ValueKey<String>('notifications-state-save-conflict'),
          icon: AfriIcons.refresh,
          title: 'Notification settings changed elsewhere',
          subtitle: 'Refresh and review the latest preference.',
          onTap: _recoverSettings,
          tone: AfriStateBannerTone.warning,
        ),
        NotificationPreferencesFailureKind.securityTimeout => AfriStateBanner(
          key: const ValueKey<String>(
            'notifications-state-save-security-timeout',
          ),
          icon: AfriIcons.lock,
          title: 'Notification save not confirmed',
          subtitle: 'Refresh before trying again. Your draft is kept.',
          onTap: _recoverSettings,
          tone: AfriStateBannerTone.warning,
        ),
        NotificationPreferencesFailureKind.unknown => const AfriStateBanner(
          key: ValueKey<String>('notifications-state-save-error'),
          icon: AfriIcons.statusError,
          title: 'Notification preferences could not be saved',
          subtitle: 'Your draft is still here.',
          tone: AfriStateBannerTone.danger,
        ),
      };
    }
    if (!isOnline) {
      return const AfriStateBanner(
        key: ValueKey<String>('notifications-state-offline'),
        icon: AfriIcons.offline,
        title: 'Saved notification settings',
        subtitle:
            'Values may be out of date. Reconnect before changing or saving.',
        tone: AfriStateBannerTone.warning,
      );
    }
    if (_permissionStatus == null) {
      return const AfriStateBanner(
        key: ValueKey<String>('notifications-state-permission-check'),
        icon: AfriIcons.notifications,
        title: 'Checking device permissions',
        subtitle: 'Delivery controls will be available after this check.',
        tone: AfriStateBannerTone.info,
        trailing: AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (_permissionStatus == PushPermissionStatus.unavailable) {
      return const AfriStateBanner(
        key: ValueKey<String>('notifications-state-disabled'),
        icon: AfriIcons.notifications,
        title: 'Device alerts unavailable',
        subtitle: 'Push delivery is not configured in this build.',
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
    final asyncSettings = ref.watch(notificationSettingsProvider);
    final loadedSettings = asyncSettings.valueOrNull;
    if (loadedSettings != null) {
      _syncDraft(loadedSettings);
    }

    final settings = _draft ?? loadedSettings;
    final permissionStatus = _permissionStatus;
    final permissionCopy = switch (permissionStatus) {
      PushPermissionStatus.authorized || PushPermissionStatus.provisional =>
        'System notifications are enabled on this device.',
      PushPermissionStatus.denied =>
        'System notifications are blocked at the device level.',
      PushPermissionStatus.notDetermined => 'Permission not yet requested.',
      PushPermissionStatus.unavailable => 'Push not configured in this build.',
      null => 'Checking device notification permissions…',
    };

    return SettingsBackGuard(
      child: AfriScreenScaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          title: Text(
            'NOTIFICATIONS',
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
                            'NOTIFICATION DELIVERY',
                            style: TypographyTokens.labelSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            settings.pushEnabled
                                ? 'Alerts enabled.'
                                : 'Enable alerts for matches, receipts & updates.',
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
                                ColorTokens.clubAccent,
                              ),
                            ),
                          ],
                          const SizedBox(height: SpacingTokens.spacing4),
                          Semantics(
                            toggled: settings.pushEnabled,
                            label: 'Device alert delivery',
                            child: AfriButton(
                              key: const ValueKey<String>(
                                'notifications-delivery-action',
                              ),
                              label: !isOnline
                                  ? 'CONNECTION REQUIRED'
                                  : settings.pushEnabled
                                  ? 'DISABLE ALERTS'
                                  : 'ENABLE ALERTS',
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
                            'DELIVERY MODEL',
                            style: TypographyTokens.labelSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            'When alerts are enabled, this release delivers the full $appName notification stream available for your account.',
                            style: TypographyTokens.bodyMedium(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            'Per-category tuning is not configurable on this build yet, so this switch controls the entire device delivery state.',
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
                          ? 'Connection required'
                          : _isSaving
                          ? 'Saving…'
                          : 'Save',
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
