import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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

  UserNotificationSettings _recomputeAllowAll(
    UserNotificationSettings settings,
  ) {
    final allowAll =
        settings.matchAlerts &&
        settings.contributionReceipts &&
        settings.xpMilestones &&
        settings.teamNews &&
        settings.challenges &&
        settings.groupChat;

    return settings.copyWith(allowAll: allowAll);
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
          .updateNotificationSettings(_recomputeAllowAll(settings));
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
    final authState = ref.watch(authStateProvider);
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
            style: GoogleFonts.barlowCondensed(
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
                      children: [
                        SwitchListTile(
                          value: settings.allowAll,
                          activeThumbColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          title: Text(
                            'Allow all',
                            style: TypographyTokens.bodyLarge(),
                          ),
                          subtitle: Text(
                            'All $appName categories',
                            style: TypographyTokens.bodySmall(),
                          ),
                          onChanged: (value) {
                            setState(
                              () => _draft = settings.copyWith(
                                allowAll: value,
                                matchAlerts: value,
                                contributionReceipts: value,
                                xpMilestones: value,
                                teamNews: value,
                                challenges: value,
                                groupChat: value,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        _NotificationToggle(
                          label: 'Match alerts',
                          value: settings.matchAlerts,
                          onChanged: (value) => setState(
                            () => _draft = _recomputeAllowAll(
                              settings.copyWith(matchAlerts: value),
                            ),
                          ),
                        ),
                        _NotificationToggle(
                          label: 'Contribution receipts',
                          value: settings.contributionReceipts,
                          onChanged: (value) => setState(
                            () => _draft = _recomputeAllowAll(
                              settings.copyWith(contributionReceipts: value),
                            ),
                          ),
                        ),
                        _NotificationToggle(
                          label: 'XP milestones',
                          value: settings.xpMilestones,
                          onChanged: (value) => setState(
                            () => _draft = _recomputeAllowAll(
                              settings.copyWith(xpMilestones: value),
                            ),
                          ),
                        ),
                        _NotificationToggle(
                          label: 'Team news',
                          value: settings.teamNews,
                          onChanged: (value) => setState(
                            () => _draft = _recomputeAllowAll(
                              settings.copyWith(teamNews: value),
                            ),
                          ),
                        ),
                        _NotificationToggle(
                          label: 'Challenges',
                          value: settings.challenges,
                          onChanged: (value) => setState(
                            () => _draft = _recomputeAllowAll(
                              settings.copyWith(challenges: value),
                            ),
                          ),
                        ),
                        _NotificationToggle(
                          label: 'Group chat',
                          value: settings.groupChat,
                          onChanged: (value) => setState(
                            () => _draft = _recomputeAllowAll(
                              settings.copyWith(groupChat: value),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  ClaymorphicButton(
                    label: _isSaving ? 'SAVING...' : 'SAVE',
                    width: double.infinity,
                    onPressed: _isSaving || authState.user == null
                        ? null
                        : () => _saveSettings(settings),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  const _NotificationToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      activeThumbColor: Theme.of(context).colorScheme.primary,
      title: Text(label, style: TypographyTokens.bodyLarge()),
      onChanged: onChanged,
    );
  }
}
