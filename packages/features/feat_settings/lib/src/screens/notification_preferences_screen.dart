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

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

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
    final status = await ref
        .read(notificationPermissionGatewayProvider)
        .getPermissionStatus();
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
    if (_isSaving) {
      return;
    }
    if (!ConnectivityService.isOnline) {
      _showMessage(
        'Connect before changing notification delivery on this device.',
      );
      return;
    }
    if (settings.pushEnabled) {
      await ref
          .read(notificationPermissionGatewayProvider)
          .unregisterCurrentDevice();
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

    final status = await ref
        .read(notificationPermissionGatewayProvider)
        .requestPermission();
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
    if (!ConnectivityService.isOnline) {
      _showMessage('Your changes are kept. Connect before saving.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .updateNotificationSettings(_normalizeForSave(settings));
      if (saved.pushEnabled) {
        await ref.read(notificationPermissionGatewayProvider).syncToken();
      } else {
        await ref
            .read(notificationPermissionGatewayProvider)
            .unregisterCurrentDevice();
      }
      ref.invalidate(notificationSettingsProvider);
      if (!mounted) return;
      setState(() {
        _draft = saved;
        _draftEdited = false;
        _localStatusMessage = null;
      });
      _showMessage('Notification preferences saved.');
    } on SettingsConflictException {
      ref.invalidate(notificationSettingsProvider);
      if (!mounted) return;
      setState(() {
        _draft = null;
        _draftUserId = null;
        _localStatusMessage =
            'Preferences changed elsewhere. The latest version is loading; review it before saving again.';
      });
      unawaited(
        FirebaseAnalyticsService.logErrorRecovery(
          surface: 'notification_settings',
          outcome: 'conflict_refresh',
        ),
      );
      _showMessage(_localStatusMessage!);
    } catch (error) {
      _showMessage(error.toString());
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
        child: settings == null
            ? asyncSettings.hasError
                  ? ConnectivityBuilder(
                      builder: (context, isOnline) => AfriErrorView(
                        message: isOnline
                            ? 'Could not load notification settings.'
                            : 'Connect to load notification settings.',
                        actionLabel: isOnline ? 'Retry' : 'Connection required',
                        onRetry: isOnline
                            ? () => ref.invalidate(notificationSettingsProvider)
                            : null,
                      ),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(SpacingTokens.spacing6),
                      child: AfriSkeletonList(),
                    )
            : ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  ConnectivityBuilder(
                    builder: (context, isOnline) => isOnline
                        ? const SizedBox.shrink()
                        : const Padding(
                            padding: EdgeInsets.only(
                              bottom: SpacingTokens.spacing4,
                            ),
                            child: AfriStateBanner(
                              icon: AfriIcons.statusWarning,
                              title: 'Saved notification settings',
                              subtitle:
                                  'Values may be out of date. Reconnect before making changes or saving.',
                              tone: AfriStateBannerTone.warning,
                            ),
                          ),
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
                        ConnectivityBuilder(
                          builder: (context, isOnline) => AfriOutlinedButton(
                            onPressed: isOnline && !_isSaving
                                ? () => _togglePush(settings)
                                : null,
                            style: AfriOutlinedButton.styleFrom(
                              minimumSize: const Size(
                                double.infinity,
                                SizeTokens.buttonMinHeight,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: ShapeTokens.buttonRadius,
                              ),
                            ),
                            child: Text(
                              !isOnline
                                  ? 'CONNECTION REQUIRED'
                                  : settings.pushEnabled
                                  ? 'DISABLE ALERTS'
                                  : 'ENABLE ALERTS',
                            ),
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
                  ConnectivityBuilder(
                    builder: (context, isOnline) => AfriButton(
                      label: !isOnline
                          ? 'Connection required'
                          : _isSaving
                          ? 'Saving…'
                          : 'Save',
                      fullWidth: true,
                      isLoading: _isSaving,
                      onTap: () => _saveSettings(settings),
                      enabled: isOnline && !_isSaving,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
