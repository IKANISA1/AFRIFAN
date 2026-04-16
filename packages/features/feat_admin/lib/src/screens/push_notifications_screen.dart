import 'dart:convert';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../repositories/admin_repository.dart';
import '../widgets/notification_widgets.dart';

class PushNotificationsScreen extends ConsumerStatefulWidget {
  const PushNotificationsScreen({super.key});

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
  bool _isLoading = true;
  bool _submitting = false;
  String? _error;

  List<Map<String, dynamic>> _groups = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _history = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();

      var groupsQuery = client
          .from('contribution_groups')
          .select('id, name')
          .eq('is_closed', false);
      groupsQuery = resolver.apply(groupsQuery, scope);

      var historyQuery = client.from('notifications').select();
      historyQuery = resolver.apply(historyQuery, scope);
      final results = await Future.wait([
        groupsQuery.order('name', ascending: true).limit(50),
        historyQuery.order('created_at', ascending: false).limit(10),
      ]);

      if (!mounted) return;
      setState(() {
        _groups = List<Map<String, dynamic>>.from(results[0] as List);
        _history = List<Map<String, dynamic>>.from(results[1] as List);
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _groups = const <Map<String, dynamic>>[];
        _history = const <Map<String, dynamic>>[];
        _error = error.toString();
        _isLoading = false;
      });
    }
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

  String? get _selectedGroupName {
    if (_selectedGroupId == null) return null;
    for (final group in _groups) {
      if (group['id']?.toString() == _selectedGroupId) {
        return group['name']?.toString();
      }
    }
    return null;
  }

  Map<String, dynamic> _buildPayload() {
    return <String, dynamic>{
      'audience': _audience,
      if (_audience == 'BY TIER' && _selectedTier != null)
        'tier': _selectedTier,
      if (_audience == 'BY GROUP' && _selectedGroupId != null)
        'group_id': _selectedGroupId,
      if (_audience == 'BY GROUP' && _selectedGroupName != null)
        'group_name': _selectedGroupName,
      'title': _titleController.text.trim(),
      'body': _bodyController.text.trim(),
      if (_imageUrlController.text.trim().isNotEmpty)
        'image_url': _imageUrlController.text.trim(),
      'delivery_mode': _scheduleMode,
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

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDeliveryMessage(Map<String, dynamic> delivery) {
    final status = delivery['status']?.toString() ?? 'queued';
    final requested = _asInt(delivery['requested_recipient_count']);
    final sent = _asInt(delivery['sent_count']);
    final failed = _asInt(delivery['failed_count']);
    final scheduledAt = DateTime.tryParse(
      delivery['scheduled_at']?.toString() ?? '',
    );
    final errors = (delivery['errors'] as List?)
        ?.map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return switch (status) {
      'scheduled' =>
        scheduledAt == null
            ? 'Notification queued for scheduled delivery.'
            : 'Notification scheduled for ${DateFormat('dd MMM yyyy • HH:mm').format(scheduledAt.toLocal())}.',
      'sent' => 'Sent to $requested supporters. $sent delivered.',
      'partial' => 'Partial: $sent delivered, $failed failed.',
      'failed' =>
        errors != null && errors.isNotEmpty
            ? errors.first
            : 'Notification delivery failed.',
      _ => 'Notification request recorded.',
    };
  }

  String _historyMetrics(Map<String, dynamic> item) {
    final requested = _asInt(item['requested_recipient_count']);
    final sent = _asInt(item['sent_count']);
    final failed = _asInt(item['failed_count']);
    if (requested == 0 && sent == 0 && failed == 0) {
      return '';
    }
    return ' • $requested targets • $sent sent • $failed failed';
  }

  Future<void> _submitNotification() async {
    final validationError = _validateComposer();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: ColorTokens.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(adminRepositoryProvider)
          .submitAdminNotification(_buildPayload());
      if (!mounted) return;

      final delivery = Map<String, dynamic>.from(
        result['delivery'] as Map? ?? const <String, dynamic>{},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_formatDeliveryMessage(delivery))));
      await _loadContext();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: ColorTokens.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _copyPayload() async {
    final validationError = _validateComposer();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: ColorTokens.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = const JsonEncoder.withIndent(
        '  ',
      ).convert(_buildPayload());
      await Clipboard.setData(ClipboardData(text: payload));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payload copied to clipboard.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _historyTitle(Map<String, dynamic> item) {
    return item['title']?.toString() ??
        item['notification_title']?.toString() ??
        'Recorded notification';
  }

  String _historyBody(Map<String, dynamic> item) {
    return item['body']?.toString() ??
        item['message']?.toString() ??
        item['content']?.toString() ??
        'No message body available.';
  }

  DateTime? _historyDate(Map<String, dynamic> item) {
    return DateTime.tryParse(
      item['created_at']?.toString() ??
          item['scheduled_at']?.toString() ??
          item['scheduled_for']?.toString() ??
          '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyText = _bodyController.text.trim();
    final charCount = bodyText.length;
    final previewAudience = switch (_audience) {
      'BY TIER' =>
        _selectedTier == null ? 'Tier not selected' : 'Tier • $_selectedTier',
      'BY GROUP' =>
        _selectedGroupName == null
            ? 'Group not selected'
            : 'Group • ${_selectedGroupName!.toUpperCase()}',
      _ => 'All supporters',
    };

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('SEND NOTIFICATION', style: TypographyTokens.titleLarge()),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : RefreshIndicator(
              onRefresh: _loadContext,
              child: ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DELIVERY STATUS',
                          style: TypographyTokens.labelLarge(),
                        ),
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
                                (item) => ChoiceChip(
                                  selected: _audience == item,
                                  label: Text(item),
                                  onSelected: (_) {
                                    setState(() {
                                      _audience = item;
                                      if (item != 'BY TIER') {
                                        _selectedTier = null;
                                      }
                                      if (item != 'BY GROUP') {
                                        _selectedGroupId = null;
                                      }
                                    });
                                  },
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
                                  (tier) => ChoiceChip(
                                    selected: _selectedTier == tier,
                                    label: Text(tier),
                                    onSelected: (_) =>
                                        setState(() => _selectedTier = tier),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (_audience == 'BY GROUP') ...[
                          const SizedBox(height: SpacingTokens.spacing4),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedGroupId,
                            decoration: const InputDecoration(
                              labelText: 'Select group',
                            ),
                            items: _groups
                                .map(
                                  (group) => DropdownMenuItem<String>(
                                    value: group['id']?.toString(),
                                    child: Text(
                                      group['name']?.toString() ?? 'Group',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedGroupId = value),
                          ),
                          if (_groups.isEmpty) ...[
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              'No active Groups for group targeting.',
                              style: TypographyTokens.bodySmall(),
                            ),
                          ],
                        ],
                        const SizedBox(height: SpacingTokens.spacing5),
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Notification title',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        TextField(
                          controller: _bodyController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Message body',
                            helperText: '$charCount characters',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        TextField(
                          controller: _imageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Optional image URL',
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
                        Text('SCHEDULE', style: TypographyTokens.labelLarge()),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Wrap(
                          spacing: SpacingTokens.spacing2,
                          children: ['SEND NOW', 'SCHEDULE']
                              .map(
                                (mode) => ChoiceChip(
                                  selected: _scheduleMode == mode,
                                  label: Text(mode),
                                  onSelected: (_) {
                                    setState(() {
                                      _scheduleMode = mode;
                                      if (mode == 'SEND NOW') {
                                        _scheduledAt = null;
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        if (_scheduleMode == 'SCHEDULE') ...[
                          const SizedBox(height: SpacingTokens.spacing4),
                          OutlinedButton.icon(
                            onPressed: _pickSchedule,
                            icon: const Icon(Icons.schedule_rounded),
                            label: Text(
                              _scheduledAt == null
                                  ? 'Pick date & time'
                                  : DateFormat(
                                      'dd MMM yyyy • HH:mm',
                                    ).format(_scheduledAt!.toLocal()),
                            ),
                            style: OutlinedButton.styleFrom(
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
                    label: _submitting
                        ? _scheduleMode == 'SCHEDULE'
                              ? 'Scheduling…'
                              : 'Sending…'
                        : _scheduleMode == 'SCHEDULE'
                        ? 'Schedule notification'
                        : 'Send notification',
                    fullWidth: true,
                    isLoading: _submitting,
                    onTap: _submitNotification,
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  TextButton.icon(
                    onPressed: _submitting ? null : _copyPayload,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('COPY PAYLOAD'),
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  Text(
                    'SEND HISTORY',
                    style: TypographyTokens.titleMedium().copyWith(
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  if (_error != null)
                    GlassCard(
                      animate: false,
                      child: Text(
                        'Could not load history. You can still compose payloads.',
                        style: TypographyTokens.bodyMedium(),
                      ),
                    )
                  else if (_history.isEmpty)
                    GlassCard(
                      animate: false,
                      child: Text(
                        'No notifications have been recorded yet.',
                        style: TypographyTokens.bodyMedium(),
                      ),
                    )
                  else
                    ..._history.map(
                      (item) => NotificationHistoryCard(
                        title: _historyTitle(item),
                        body: _historyBody(item),
                        status: item['status']?.toString() ?? 'RECORDED',
                        date: _historyDate(item),
                        metrics: _historyMetrics(item),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
