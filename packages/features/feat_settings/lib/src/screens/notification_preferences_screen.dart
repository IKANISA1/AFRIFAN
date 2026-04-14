import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_notification_settings.dart';
import '../settings_providers.dart';
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

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
  }

  Future<void> _refreshPermissionStatus() async {
    final status = await PushNotificationService.getPermissionStatus();
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
    if (settings.pushEnabled) {
      await PushNotificationService.unregisterCurrentDevice();
      setState(() => _draft = settings.copyWith(pushEnabled: false));
      await _refreshPermissionStatus();
      _showMessage('Notifications disabled for this device.');
      return;
    }

    final enabled = await showNotificationPermissionModal(context);
    if (!enabled || !mounted) return;

    final status = await PushNotificationService.requestPermission();
    if (!mounted) return;

    switch (status) {
      case PushPermissionStatus.authorized:
      case PushPermissionStatus.provisional:
        setState(() => _draft = settings.copyWith(pushEnabled: true));
        _showMessage('Notifications enabled for this device.');
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
    setState(() => _isSaving = true);

    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .updateNotificationSettings(_normalizeForSave(settings));
      if (saved.pushEnabled) {
        await PushNotificationService.syncToken();
      } else {
        await PushNotificationService.unregisterCurrentDevice();
      }
      ref.invalidate(notificationSettingsProvider);
      if (!mounted) return;
      setState(() => _draft = saved);
      _showMessage('Notification preferences saved.');
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      child: Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AppBar(
          title: Text(
            'NOTIFICATIONS',
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
                          'Could not load notification settings.',
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
                        const SizedBox(height: SpacingTokens.spacing4),
                        OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => _togglePush(settings),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            settings.pushEnabled
                                ? 'DISABLE ALERTS'
                                : 'ENABLE ALERTS',
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
                  ClaymorphicButton(
                    label: _isSaving ? 'SAVING...' : 'SAVE',
                    width: double.infinity,
                    onPressed: _isSaving ? null : () => _saveSettings(settings),
                  ),
                ],
              ),
      ),
    );
  }
}
