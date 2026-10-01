import 'dart:async';
import 'dart:convert';

import 'package:core_l10n/core_l10n.dart';
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
    final l10n = context.afriL10n;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      return l10n.adminNotificationValidationTitleBody;
    }
    if (_audience == 'BY TIER' && _selectedTier == null) {
      return l10n.adminNotificationValidationTier;
    }
    if (_audience == 'BY GROUP' && _selectedGroupId == null) {
      return l10n.adminNotificationValidationGroup;
    }
    if (_scheduleMode == 'SCHEDULE' && _scheduledAt == null) {
      return l10n.adminNotificationValidationSchedule;
    }
    return null;
  }

  String _formatDeliveryMessage(AdminNotificationDelivery delivery) {
    final l10n = context.afriL10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return switch (delivery.status) {
      'scheduled' =>
        delivery.scheduledAt == null
            ? l10n.adminNotificationQueued
            : l10n.adminNotificationScheduledFor(
                DateFormat(
                  'dd MMM yyyy • HH:mm',
                  locale,
                ).format(delivery.scheduledAt!.toLocal()),
              ),
      'sent' => l10n.adminNotificationSentSummary(
        delivery.requestedCount,
        delivery.sentCount,
      ),
      'partial' => l10n.adminNotificationPartialSummary(
        delivery.sentCount,
        delivery.failedCount,
      ),
      'failed' => l10n.adminNotificationDeliveryFailed,
      _ => l10n.adminNotificationRequestRecorded,
    };
  }

  String _historyMetrics(AdminNotificationRecord item) {
    if (item.requestedCount == 0 &&
        item.sentCount == 0 &&
        item.failedCount == 0) {
      return '';
    }
    return context.afriL10n.adminNotificationHistoryMetrics(
      item.requestedCount,
      item.sentCount,
      item.failedCount,
    );
  }

  String _audienceLabel(String audience) {
    final l10n = context.afriL10n;
    return switch (audience) {
      'BY TIER' => l10n.adminNotificationAudienceByTier,
      'BY GROUP' => l10n.adminNotificationAudienceByGroup,
      _ => l10n.adminNotificationAudienceAllFans,
    };
  }

  String _tierLabel(String tier) {
    final l10n = context.afriL10n;
    return switch (tier) {
      'BRONZE' => l10n.adminNotificationTierBronze,
      'GOLD' => l10n.adminNotificationTierGold,
      'PLATINUM' => l10n.adminNotificationTierPlatinum,
      _ => l10n.adminNotificationTierFan,
    };
  }

  String _scheduleLabel(String mode) {
    return mode == 'SCHEDULE'
        ? context.afriL10n.adminNotificationSchedule
        : context.afriL10n.adminNotificationSendNow;
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
      AfriToast.error(context, context.afriL10n.adminNotificationFieldsInvalid);
    } catch (_) {
      if (!mounted) return;
      AfriToast.error(
        context,
        context.afriL10n.adminNotificationRequestUnconfirmed,
      );
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
      AfriToast.success(
        context,
        context.afriL10n.adminNotificationPayloadCopied,
      );
    } on FormatException {
      if (!mounted) return;
      AfriToast.error(context, context.afriL10n.adminNotificationFieldsInvalid);
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
      title: context.afriL10n.adminNotificationSendTitle,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.adminBack,
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
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.spacing4,
              ),
              child: AfriStateView.loading(
                key: const ValueKey<String>(
                  'admin-notifications-state-loading',
                ),
                title: context.afriL10n.adminNotificationLoading,
                message: context.afriL10n.adminNotificationLoadingMessage,
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
        _selectedTier == null
            ? context.afriL10n.adminNotificationTierNotSelected
            : context.afriL10n.adminNotificationTierPreview(
                _tierLabel(_selectedTier!),
              ),
      'BY GROUP' =>
        selectedGroupName == null
            ? context.afriL10n.adminNotificationGroupNotSelected
            : context.afriL10n.adminNotificationGroupPreview(selectedGroupName),
      _ => context.afriL10n.adminNotificationAllSupporters,
    };

    return AfriRefreshIndicator(
      onRefresh: ref.read(adminNotificationsProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
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
                Text(
                  context.afriL10n.adminNotificationDeliveryStatus,
                  style: TypographyTokens.labelLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  context.afriL10n.adminNotificationDeliveryStatusMessage,
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
                Text(
                  context.afriL10n.adminNotificationAudience,
                  style: TypographyTokens.labelLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Wrap(
                  spacing: SpacingTokens.spacing2,
                  runSpacing: SpacingTokens.spacing2,
                  children: ['ALL FANS', 'BY TIER', 'BY GROUP']
                      .map(
                        (item) => AfriChoiceChip(
                          selected: _audience == item,
                          label: Text(_audienceLabel(item)),
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
                            label: Text(_tierLabel(tier)),
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
                    label: context.afriL10n.adminNotificationSelectGroup,
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
                  label: context.afriL10n.adminNotificationTitleLabel,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriInputField(
                  controller: _bodyController,
                  maxLines: 2,
                  label: context.afriL10n.adminNotificationBodyLabel,
                  helperText: context.afriL10n.adminNotificationCharacterCount(
                    charCount,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriInputField(
                  controller: _imageUrlController,
                  label: context.afriL10n.adminNotificationImageUrl,
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
                  context.afriL10n.adminNotificationSchedule,
                  style: TypographyTokens.labelLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Wrap(
                  spacing: SpacingTokens.spacing2,
                  children: ['SEND NOW', 'SCHEDULE']
                      .map(
                        (mode) => AfriChoiceChip(
                          selected: _scheduleMode == mode,
                          label: Text(_scheduleLabel(mode)),
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
                          ? context.afriL10n.adminNotificationPickDateTime
                          : DateFormat(
                              'dd MMM yyyy • HH:mm',
                              Localizations.localeOf(context).toLanguageTag(),
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
                ? context.afriL10n.adminNotificationScheduleAction
                : context.afriL10n.adminNotificationSendAction,
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
            label: Text(context.afriL10n.adminNotificationCopyPayload),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          Text(
            context.afriL10n.adminNotificationSendHistory,
            style: TypographyTokens.titleMedium().copyWith(
              letterSpacing: TypographyTokens.trackingNone,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (snapshot.history.isEmpty)
            AfriStateView.empty(
              key: const ValueKey<String>('admin-notifications-state-empty'),
              title: context.afriL10n.adminNotificationHistoryEmpty,
              message: context.afriL10n.adminNotificationHistoryEmptyMessage,
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
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
      child: AfriStateView.empty(
        key: const ValueKey<String>('admin-notifications-state-disabled'),
        title: context.afriL10n.adminNotificationManagementUnavailable,
        message: context.afriL10n.adminNotificationControlsDisabled,
        icon: AfriIcons.lock,
        actionLabel: context.afriL10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
    );
  }

  Widget _unavailable(AdminNotificationsFailure failure) {
    final l10n = context.afriL10n;
    void retry() =>
        unawaited(ref.read(adminNotificationsProvider.notifier).refresh());
    final view = switch (failure.kind) {
      AdminNotificationsFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-notifications-state-offline'),
        title: l10n.adminNotificationWorkspaceOffline,
        message: l10n.adminNotificationOfflineMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
      AdminNotificationsFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-notifications-state-permission-denied',
        ),
        title: l10n.adminNotificationAccessUnavailable,
        message: l10n.adminNotificationAccessMessage,
        actionLabel: l10n.adminBackToAdmin,
        onAction: () => context.pop(),
      ),
      AdminNotificationsFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-notifications-state-conflict'),
        title: l10n.adminNotificationDataChanged,
        message: l10n.adminNotificationDataChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: retry,
      ),
      AdminNotificationsFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>(
          'admin-notifications-state-security-timeout',
        ),
        title: l10n.adminSecurityTimeout,
        message: l10n.adminNotificationSecurityMessage,
        actionLabel: l10n.retry,
        onAction: retry,
      ),
      AdminNotificationsFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-notifications-state-error'),
        title: l10n.adminNotificationWorkspaceUnavailable,
        message: l10n.adminNotificationHiddenMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: retry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing4),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminNotificationsSnapshot> notifications) {
    final snapshot = notifications.valueOrNull;
    if (snapshot == null) return null;
    if (notifications.isLoading || snapshot.isMutating) {
      return AfriStateBanner(
        key: const ValueKey<String>('admin-notifications-state-syncing'),
        icon: AfriIcons.refresh,
        title: context.afriL10n.adminNotificationChecking,
        subtitle: context.afriL10n.adminNotificationCheckingMessage,
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
          context.afriL10n.adminNotificationDataChanged,
        AdminNotificationsFailureKind.securityTimeout =>
          context.afriL10n.adminSecurityTimeout,
        AdminNotificationsFailureKind.offline =>
          context.afriL10n.adminNotificationWorkspaceOffline,
        _ => context.afriL10n.adminNotificationWorkspaceUnavailable,
      },
      subtitle: snapshot.mutationOutcomeUnconfirmed
          ? context.afriL10n.adminNotificationOutcomeUnconfirmed
          : context.afriL10n.adminNotificationLastConfirmed,
      tone: AfriStateBannerTone.warning,
    );
  }
}
