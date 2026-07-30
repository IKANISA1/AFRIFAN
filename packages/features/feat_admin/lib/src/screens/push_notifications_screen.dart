import 'dart:async';
import 'dart:convert';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../admin_notifications_controller.dart';
import '../widgets/notification_widgets.dart';

class PushNotificationsScreen extends ConsumerStatefulWidget {
  const PushNotificationsScreen({this.firstActionFocusNode, super.key});

  final FocusNode? firstActionFocusNode;

  @override
  ConsumerState<PushNotificationsScreen> createState() =>
      _PushNotificationsScreenState();
}

class _PushNotificationsScreenState
    extends ConsumerState<PushNotificationsScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String _audience = 'ALL FANS';
  String _scheduleMode = 'SEND NOW';
  String? _selectedTier;
  String? _selectedGroupId;
  DateTime? _scheduledAt;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    final initialDate =
        _scheduledAt ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String? _selectedGroupName(List<AdminNotificationGroup> groups) {
    if (_selectedGroupId == null) return null;
    for (final group in groups) {
      if (group.id == _selectedGroupId) {
        return group.name;
      }
    }
    return null;
  }

  Map<String, dynamic> _buildPayload(AdminNotificationsSnapshot snapshot) {
    final groupName = _selectedGroupName(snapshot.groups);
    return <String, dynamic>{
      'audience': switch (_audience) {
        'BY TIER' => 'by_tier',
        'BY GROUP' => 'by_group',
        _ => 'all_fans',
      },
      if (_audience == 'BY TIER' && _selectedTier != null)
        'tier': _selectedTier,
      if (_audience == 'BY GROUP' && _selectedGroupId != null)
        'group_id': _selectedGroupId,
      if (_audience == 'BY GROUP' && groupName != null) 'group_name': groupName,
      'title': _titleController.text.trim(),
      'body': _bodyController.text.trim(),
      if (_imageUrlController.text.trim().isNotEmpty)
        'image_url': _imageUrlController.text.trim(),
      'delivery_mode': _scheduleMode == 'SCHEDULE' ? 'schedule' : 'send_now',
      if (_scheduleMode == 'SCHEDULE' && _scheduledAt != null)
        'scheduled_at': _scheduledAt!.toUtc().toIso8601String(),
    };
  }

  String? _validateComposer() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      return 'Add a title and message body first.';
    }
    if (_audience == 'BY TIER' && _selectedTier == null) {
      return 'Choose the target tier first.';
    }
    if (_audience == 'BY GROUP' && _selectedGroupId == null) {
      return 'Choose the target group first.';
    }
    if (_scheduleMode == 'SCHEDULE' && _scheduledAt == null) {
      return 'Pick the delivery date and time first.';
    }
    return null;
  }

  String _formatDeliveryMessage(AdminNotificationDelivery delivery) {
    return switch (delivery.status) {
      'scheduled' =>
        delivery.scheduledAt == null
            ? 'Notification queued for scheduled delivery.'
            : 'Notification scheduled for ${DateFormat('dd MMM yyyy • HH:mm').format(delivery.scheduledAt!.toLocal())}.',
      'sent' =>
        'Sent to ${delivery.requestedCount} supporters. ${delivery.sentCount} delivered.',
      'partial' =>
        'Partial: ${delivery.sentCount} delivered, ${delivery.failedCount} failed.',
      'failed' => 'Notification delivery failed.',
      _ => 'Notification request recorded.',
    };
  }

  String _historyMetrics(AdminNotificationRecord item) {
    if (item.requestedCount == 0 &&
        item.sentCount == 0 &&
        item.failedCount == 0) {
      return '';
    }
    return ' • ${item.requestedCount} targets • ${item.sentCount} sent • ${item.failedCount} failed';
  }

  Widget _choiceLabel(String value, {required bool selected}) {
    return Text(
      value,
      style: TypographyTokens.labelMedium(
        selected ? ColorTokens.onDark : ColorTokens.onSurfaceVariant,
      ),
    );
  }

  Future<void> _submitNotification() async {
    final validationError = _validateComposer();
    if (validationError != null) {
      AfriToast.error(context, validationError);
      return;
    }

    try {
      final snapshot = ref.read(adminNotificationsProvider).valueOrNull;
      if (snapshot == null || !snapshot.actionsEnabled) return;
      final delivery = await ref
          .read(adminNotificationsProvider.notifier)
          .send(_buildPayload(snapshot));
      if (!mounted) return;
      if (delivery != null) {
        AfriToast.success(context, _formatDeliveryMessage(delivery));
      }
    } on FormatException {
      if (!mounted) return;
      AfriToast.error(context, 'Review the notification fields and try again.');
    } catch (_) {
      if (!mounted) return;
      AfriToast.error(context, 'Notification request was not confirmed.');
    }
  }

  Future<void> _copyPayload(AdminNotificationsSnapshot snapshot) async {
    final validationError = _validateComposer();
    if (validationError != null) {
      AfriToast.error(context, validationError);
      return;
    }

    try {
      final payload = const JsonEncoder.withIndent(
        '  ',
      ).convert(_buildPayload(snapshot));
      await Clipboard.setData(ClipboardData(text: payload));
      if (!mounted) return;
      AfriToast.success(context, 'Payload copied to clipboard.');
    } on FormatException {
      if (!mounted) return;
      AfriToast.error(context, 'Review the notification fields and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(adminNotificationsEnabledProvider);
    final notifications = ref.watch(adminNotificationsProvider);
    final snapshot = notifications.valueOrNull;
    final denied =
        snapshot?.failure?.kind ==
        AdminNotificationsFailureKind.permissionDenied;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('SEND NOTIFICATION', style: TypographyTokens.titleLarge()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? _disabled()
          : denied
          ? _unavailable(
              const AdminNotificationsFailure(
                AdminNotificationsFailureKind.permissionDenied,
              ),
            )
          : notifications.isLoading && snapshot == null
          ? Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.loading(
                key: const ValueKey<String>(
                  'admin-notifications-state-loading',
                ),
                title: 'Loading notification workspace',
                message: 'Checking controlled delivery information.',
              ),
            )
          : notifications.hasError && snapshot == null
          ? _unavailable(
              AdminNotificationsFailure.fromError(notifications.error!),
            )
          : _content(notifications),
    );
  }

  Widget _content(AsyncValue<AdminNotificationsSnapshot> notifications) {
    final snapshot = notifications.requireValue;
    final controlsEnabled = snapshot.actionsEnabled && !notifications.isLoading;
    final bodyText = _bodyController.text.trim();
    final charCount = bodyText.length;
    final selectedGroupName = _selectedGroupName(snapshot.groups);
    final previewAudience = switch (_audience) {
      'BY TIER' =>
        _selectedTier == null ? 'Tier not selected' : 'Tier • $_selectedTier',
      'BY GROUP' =>
        selectedGroupName == null
            ? 'Group not selected'
            : 'Group • ${selectedGroupName.toUpperCase()}',
      _ => 'All supporters',
    };

    return AfriRefreshIndicator(
      onRefresh: ref.read(adminNotificationsProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        children: [
          if (_statusBanner(notifications) case final banner?) ...[
            banner,
            const SizedBox(height: SpacingTokens.spacing4),
          ],
          GlassCard(
            animate: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DELIVERY STATUS', style: TypographyTokens.labelLarge()),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  'Delivery via Edge Functions. Scheduled sends dispatch on cron.',
                  style: TypographyTokens.bodyMedium(),
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
                Text('AUDIENCE', style: TypographyTokens.labelLarge()),
                const SizedBox(height: SpacingTokens.spacing2),
                Wrap(
                  spacing: SpacingTokens.spacing2,
                  runSpacing: SpacingTokens.spacing2,
                  children: ['ALL FANS', 'BY TIER', 'BY GROUP']
                      .map(
                        (item) => AfriChoiceChip(
                          selected: _audience == item,
                          label: _choiceLabel(
                            item,
                            selected: _audience == item,
                          ),
                          onSelected: controlsEnabled
                              ? (_) {
                                  setState(() {
                                    _audience = item;
                                    if (item != 'BY TIER') {
                                      _selectedTier = null;
                                    }
                                    if (item != 'BY GROUP') {
                                      _selectedGroupId = null;
                                    }
                                  });
                                }
                              : null,
                        ),
                      )
                      .toList(),
                ),
                if (_audience == 'BY TIER') ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  Wrap(
                    spacing: SpacingTokens.spacing2,
                    runSpacing: SpacingTokens.spacing2,
                    children: ['FAN', 'BRONZE', 'GOLD', 'PLATINUM']
                        .map(
                          (tier) => AfriChoiceChip(
                            selected: _selectedTier == tier,
                            label: _choiceLabel(
                              tier,
                              selected: _selectedTier == tier,
                            ),
                            onSelected: controlsEnabled
                                ? (_) => setState(() => _selectedTier = tier)
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (_audience == 'BY GROUP') ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriDropdownField<String>(
                    initialValue: _selectedGroupId,
                    label: 'Select group',
                    items: snapshot.groups
                        .map(
                          (group) => DropdownMenuItem<String>(
                            value: group.id,
                            child: Text(group.name),
                          ),
                        )
                        .toList(),
                    onChanged: controlsEnabled
                        ? (value) => setState(() => _selectedGroupId = value)
                        : null,
                  ),
                ],
                const SizedBox(height: SpacingTokens.spacing5),
                AfriInputField(
                  controller: _titleController,
                  label: 'Notification title',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriInputField(
                  controller: _bodyController,
                  maxLines: 2,
                  label: 'Message body',
                  helperText: '$charCount characters',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriInputField(
                  controller: _imageUrlController,
                  label: 'Optional image URL',
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
                Text('SCHEDULE', style: TypographyTokens.labelLarge()),
                const SizedBox(height: SpacingTokens.spacing2),
                Wrap(
                  spacing: SpacingTokens.spacing2,
                  children: ['SEND NOW', 'SCHEDULE']
                      .map(
                        (mode) => AfriChoiceChip(
                          selected: _scheduleMode == mode,
                          label: _choiceLabel(
                            mode,
                            selected: _scheduleMode == mode,
                          ),
                          onSelected: controlsEnabled
                              ? (_) {
                                  setState(() {
                                    _scheduleMode = mode;
                                    if (mode == 'SEND NOW') {
                                      _scheduledAt = null;
                                    }
                                  });
                                }
                              : null,
                        ),
                      )
                      .toList(),
                ),
                if (_scheduleMode == 'SCHEDULE') ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriOutlinedIconButton(
                    onPressed: controlsEnabled ? _pickSchedule : null,
                    icon: const Icon(AfriIcons.statusPending),
                    label: Text(
                      _scheduledAt == null
                          ? 'Pick date & time'
                          : DateFormat(
                              'dd MMM yyyy • HH:mm',
                            ).format(_scheduledAt!.toLocal()),
                    ),
                    style: AfriOutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          NotificationPreviewCard(
            audience: previewAudience,
            title: _titleController.text.trim(),
            body: bodyText,
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          AfriButton(
            key: const ValueKey<String>('admin-notifications-send'),
            label: _scheduleMode == 'SCHEDULE'
                ? 'Schedule notification'
                : 'Send notification',
            fullWidth: true,
            isLoading: snapshot.isMutating,
            onTap: _submitNotification,
            enabled: controlsEnabled,
            focusNode: widget.firstActionFocusNode,
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriTextIconButton(
            onPressed: controlsEnabled
                ? () => unawaited(_copyPayload(snapshot))
                : null,
            icon: const Icon(AfriIcons.copy),
            label: const Text('COPY PAYLOAD'),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          Text(
            'SEND HISTORY',
            style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (snapshot.history.isEmpty)
            AfriStateView.empty(
              key: const ValueKey<String>('admin-notifications-state-empty'),
              title: 'No notification history',
              message:
                  'Confirmed delivery records will appear here after a request.',
              compact: true,
            )
          else
            ...snapshot.history.map(
              (item) => NotificationHistoryCard(
                title: item.title,
                body: item.body,
                status: item.status,
                date: item.sentAt ?? item.scheduledAt ?? item.createdAt,
                metrics: _historyMetrics(item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _disabled() {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-notifications-state-disabled'),
        title: 'Notification management unavailable',
        message:
            'Notification controls are disabled for this controlled build.',
        icon: AfriIcons.lock,
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(AdminNotificationsFailure failure) {
    void retry() =>
        unawaited(ref.read(adminNotificationsProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminNotificationsFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-notifications-state-offline'),
        title: 'Notification workspace offline',
        message: 'Reconnect before loading private delivery information.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
      AdminNotificationsFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-notifications-state-permission-denied',
        ),
        title: 'Notification access unavailable',
        message: 'This account cannot view or send notifications.',
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
      AdminNotificationsFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-notifications-state-conflict'),
        title: 'Delivery information changed',
        message: 'Refresh before making another notification request.',
        actionLabel: 'Refresh',
        onAction: retry,
      ),
      AdminNotificationsFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-notifications-state-security-timeout',
        ),
        title: 'Security check timed out',
        message: 'No delivery information was shown. Check your connection.',
        actionLabel: 'Retry',
        onAction: retry,
      ),
      AdminNotificationsFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-notifications-state-error'),
        title: 'Notification workspace unavailable',
        message: 'Private delivery information remains hidden. Try again.',
        actionLabel: 'Try again',
        onAction: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminNotificationsSnapshot> notifications) {
    final snapshot = notifications.valueOrNull;
    if (snapshot == null) return null;
    if (notifications.isLoading || snapshot.isMutating) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-notifications-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Checking delivery information',
        subtitle:
            'Showing the last confirmed state while current data is checked.',
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = snapshot.failure;
    if (snapshot.phase != AdminNotificationsPhase.degraded || failure == null) {
      return null;
    }
    return AfriStateBanner(
      key: ValueKey<String>('admin-notifications-state-${failure.kind.name}'),
      icon: failure.kind == AdminNotificationsFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: switch (failure.kind) {
        AdminNotificationsFailureKind.conflict =>
          'Delivery information changed',
        AdminNotificationsFailureKind.securityTimeout =>
          'Security check timed out',
        AdminNotificationsFailureKind.offline =>
          'Notification workspace offline',
        _ => 'Notification workspace unavailable',
      },
      subtitle: snapshot.mutationOutcomeUnconfirmed
          ? 'The last request is unconfirmed. Controls stay paused until refresh succeeds.'
          : 'Last confirmed delivery information remains visible. Controls are paused.',
      tone: AfriStateBannerTone.warning,
    );
  }
}
