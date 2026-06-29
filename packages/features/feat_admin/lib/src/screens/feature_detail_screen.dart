import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_providers.dart';
import '../repositories/feature_management_repository.dart';

/// Detail screen for editing a single platform feature's channel configs
/// and scheduling rules.
class FeatureDetailScreen extends ConsumerStatefulWidget {
  const FeatureDetailScreen({super.key, required this.featureKey});

  final String featureKey;

  @override
  ConsumerState<FeatureDetailScreen> createState() =>
      _FeatureDetailScreenState();
}

class _FeatureDetailScreenState extends ConsumerState<FeatureDetailScreen> {
  ManagedPlatformFeature? _feature;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  FeatureManagementRepository get _repository =>
      ref.read(featureManagementRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final feature = await _repository.loadFeature(widget.featureKey);
      if (!mounted) return;

      setState(() {
        _feature = feature;
        _isLoading = false;
        if (feature == null) {
          _error = 'Feature "${widget.featureKey}" not found.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(SpacingTokens.spacing6),
                        child: AfriSkeletonList(),
                      )
                    : _error != null
                    ? _buildError()
                    : AfriRefreshIndicator(
                        onRefresh: _load,
                        child: _buildContent(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: Row(
        children: [
          AfriIconButton(
            icon: AfriIcons.chevronLeft,
            onTap: () => context.pop(),
            tooltip: 'Back',
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _feature?.displayName ?? widget.featureKey,
                  style: TypographyTokens.titleMedium(),
                ),
                Text(
                  widget.featureKey,
                  style: TypographyTokens.bodySmall().copyWith(
                    color: ColorTokens.onDarkFaint,
                    fontFamily: TypographyTokens.borrowedFontFamily,
                    package: 'core_theme',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final feature = _feature;
    if (feature == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 1)],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('GLOBAL STATE'),
          const SizedBox(height: SpacingTokens.spacing3),
          _buildGlobalState(feature),
          const SizedBox(height: SpacingTokens.spacing6),
          _buildSectionTitle('CHANNEL CONFIG'),
          const SizedBox(height: SpacingTokens.spacing3),
          if (feature.channels.isNotEmpty)
            ...feature.channels.map(_buildChannelCard),
          const SizedBox(height: SpacingTokens.spacing6),
          _buildSectionTitle('SCHEDULING'),
          const SizedBox(height: SpacingTokens.spacing3),
          _buildScheduleCard(feature),
          const SizedBox(height: SpacingTokens.spacing6),
          _buildSectionTitle('ACCESS RULES'),
          const SizedBox(height: SpacingTokens.spacing3),
          _buildAccessRulesCard(feature),
          const SizedBox(height: SpacingTokens.spacing8),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TypographyTokens.titleSmall().copyWith(
        color: ColorTokens.clubAccent,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildGlobalState(ManagedPlatformFeature feature) {
    return GlassCard(
      animate: false,
      child: Column(
        children: [
          _buildToggleRow(
            label: 'Enabled',
            subtitle: 'Global kill switch for this feature',
            value: feature.isEnabled,
            onChanged: (value) => _updateGlobalEnabled(value),
          ),
          const AfriDivider(color: ColorTokens.onDarkHairline),
          _buildVisibilityRow(
            current: feature.visibilityState,
            onChanged: _updateVisibility,
          ),
        ],
      ),
    );
  }

  Widget _buildChannelCard(ManagedFeatureChannelConfig channel) {
    final channelName = channel.channel.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  channel.channel == 'mobile'
                      ? AfriIcons.smartphone
                      : AfriIcons.public,
                  size: 18,
                  color: ColorTokens.clubAccent,
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Text(
                  channelName,
                  style: TypographyTokens.titleSmall().copyWith(
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            _buildToggleRow(
              label: 'Enabled',
              subtitle: 'Feature active on $channelName',
              value: channel.isEnabled,
              onChanged: (value) =>
                  _updateChannel(channel.channel, {'is_enabled': value}),
            ),
            const AfriDivider(color: ColorTokens.onDarkHairline),
            _buildToggleRow(
              label: 'Visible',
              subtitle: 'Show in $channelName UI',
              value: channel.isVisible,
              onChanged: (value) =>
                  _updateChannel(channel.channel, {'is_visible': value}),
            ),
            const AfriDivider(color: ColorTokens.onDarkHairline),
            _buildToggleRow(
              label: 'Show in Navigation',
              subtitle: channel.channel == 'mobile'
                  ? 'Bottom navigation tab'
                  : 'Top navigation menu',
              value: channel.showInNavigation,
              onChanged: (value) => _updateChannel(channel.channel, {
                'show_in_navigation': value,
              }),
            ),
            const AfriDivider(color: ColorTokens.onDarkHairline),
            _buildToggleRow(
              label: 'Show on Home',
              subtitle: 'Display on home screen',
              value: channel.showOnHome,
              onChanged: (value) =>
                  _updateChannel(channel.channel, {'show_on_home': value}),
            ),
            const AfriDivider(color: ColorTokens.onDarkHairline),
            _buildSortOrderRow(
              current: channel.sortOrder,
              onChanged: (value) =>
                  _updateChannel(channel.channel, {'sort_order': value}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(ManagedPlatformFeature feature) {
    final startDate = feature.rules?.scheduleStartAt;
    final endDate = feature.rules?.scheduleEndAt;

    return GlassCard(
      animate: false,
      child: Column(
        children: [
          _buildDatePickerRow(
            label: 'Available From',
            subtitle: 'Feature becomes active',
            value: startDate,
            onChanged: (date) => _updateRules({
              'schedule_start_at': date?.toUtc().toIso8601String(),
            }),
          ),
          const AfriDivider(color: ColorTokens.onDarkHairline),
          _buildDatePickerRow(
            label: 'Available Until',
            subtitle: 'Feature deactivates',
            value: endDate,
            onChanged: (date) => _updateRules({
              'schedule_end_at': date?.toUtc().toIso8601String(),
            }),
          ),
          if (startDate != null || endDate != null) ...[
            const AfriDivider(color: ColorTokens.onDarkHairline),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.spacing2,
              ),
              child: Row(
                children: [
                  const Icon(
                    AfriIcons.statusInfo,
                    size: 16,
                    color: ColorTokens.onDarkFaint,
                  ),
                  const SizedBox(width: SpacingTokens.spacing2),
                  Expanded(
                    child: Text(
                      _scheduleDescription(startDate, endDate),
                      style: TypographyTokens.bodySmall().copyWith(
                        color: ColorTokens.onDarkSubtle,
                      ),
                    ),
                  ),
                  AfriTextButton(
                    onPressed: () => _updateRules({
                      'schedule_start_at': null,
                      'schedule_end_at': null,
                    }),
                    child: Text(
                      'Clear',
                      style: TypographyTokens.bodySmall().copyWith(
                        color: ColorTokens.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccessRulesCard(ManagedPlatformFeature feature) {
    return GlassCard(
      animate: false,
      child: Column(
        children: [
          _buildToggleRow(
            label: 'Auth Required',
            subtitle: 'User must be signed in to access',
            value: feature.rules?.authRequired ?? false,
            onChanged: (value) => _updateRules({'auth_required': value}),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TypographyTokens.bodyMedium()),
                Text(
                  subtitle,
                  style: TypographyTokens.bodySmall().copyWith(
                    color: ColorTokens.onDarkFaint,
                  ),
                ),
              ],
            ),
          ),
          AfriSwitch(value: value, onChanged: _isSaving ? null : onChanged),
        ],
      ),
    );
  }

  Widget _buildVisibilityRow({
    required String current,
    required ValueChanged<String> onChanged,
  }) {
    final color = switch (current) {
      'visible' => ColorTokens.success,
      'hidden' => ColorTokens.error,
      'maintenance' => ColorTokens.warning,
      _ => ColorTokens.onSurfaceVariant,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visibility', style: TypographyTokens.bodyMedium()),
                Text(
                  'Controls UI rendering state',
                  style: TypographyTokens.bodySmall().copyWith(
                    color: ColorTokens.onDarkFaint,
                  ),
                ),
              ],
            ),
          ),
          AfriPopupMenuButton<String>(
            onSelected: onChanged,
            enabled: !_isSaving,
            tooltip: 'Change visibility',
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'visible', child: Text('Visible')),
              PopupMenuItem(value: 'hidden', child: Text('Hidden')),
              PopupMenuItem(value: 'maintenance', child: Text('Maintenance')),
            ],
            child: AfriChip(
              label: Text(
                current.toUpperCase(),
                style: TypographyTokens.bodySmall().copyWith(color: color),
              ),
              side: BorderTokens.side(color: color, opacity: 0.3),
              backgroundColor: color.withValues(alpha: 0.1),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortOrderRow({
    required int? current,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sort Order', style: TypographyTokens.bodyMedium()),
                Text(
                  'Lower = higher priority in nav/home',
                  style: TypographyTokens.bodySmall().copyWith(
                    color: ColorTokens.onDarkFaint,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: AfriTextFormField(
              initialValue: current?.toString() ?? '',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing2,
                vertical: SpacingTokens.spacing2,
              ),
              onFieldSubmitted: _isSaving
                  ? null
                  : (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        onChanged(parsed);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerRow({
    required String label,
    required String subtitle,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    final formatted = value != null
        ? '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
              '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}'
        : 'Not set';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TypographyTokens.bodyMedium()),
                Text(
                  subtitle,
                  style: TypographyTokens.bodySmall().copyWith(
                    color: ColorTokens.onDarkFaint,
                  ),
                ),
              ],
            ),
          ),
          AfriPressFeedback(
            onTap: _isSaving ? null : () => _pickDateTime(value, onChanged),
            tooltip: 'Set $label',
            semanticsLabel: '$label: $formatted',
            semanticsHint: 'Opens date and time picker',
            child: Container(
              decoration: BoxDecoration(
                border: BorderTokens.all(
                  color: ColorTokens.onDark,
                  opacity: 0.24,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing3,
                vertical: SpacingTokens.spacing2,
              ),
              child: Text(
                formatted,
                style: TypographyTokens.bodySmall().copyWith(
                  color: value != null
                      ? ColorTokens.clubAccent
                      : ColorTokens.onDarkFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime(
    DateTime? initial,
    ValueChanged<DateTime?> onChanged,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
    );
    if (!mounted) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    onChanged(combined);
  }

  Future<void> _updateGlobalEnabled(bool value) async {
    final feature = _feature;
    if (feature == null) return;
    await _runSave(
      () => _repository.updateFeatureGlobalStatus(feature.id, value),
      errorMessage: 'Failed to update feature.',
    );
  }

  Future<void> _updateVisibility(String value) async {
    final feature = _feature;
    if (feature == null) return;
    await _runSave(
      () => _repository.updateFeatureVisibility(feature.id, value),
      errorMessage: 'Failed to update feature visibility.',
    );
  }

  Future<void> _updateChannel(
    String channel,
    Map<String, dynamic> updates,
  ) async {
    final feature = _feature;
    if (feature == null) return;
    await _runSave(
      () => _repository.updateChannelConfig(feature.id, channel, updates),
      errorMessage: 'Failed to update channel config.',
    );
  }

  Future<void> _updateRules(Map<String, dynamic> updates) async {
    final feature = _feature;
    if (feature == null) return;
    await _runSave(
      () => _repository.updateFeatureRules(feature.id, updates),
      errorMessage: 'Failed to update feature rules.',
    );
  }

  Future<void> _runSave(
    Future<bool> Function() action, {
    required String errorMessage,
  }) async {
    setState(() => _isSaving = true);
    try {
      final success = await action();
      if (!success) {
        _showError(errorMessage);
        return;
      }
      await _load();
    } catch (error) {
      _showError('$errorMessage $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AfriToast.error(context, message);
  }

  String _scheduleDescription(DateTime? start, DateTime? end) {
    if (start != null && end != null) {
      return 'Active from ${_formatDate(start)} to ${_formatDate(end)}';
    }
    if (start != null) {
      return 'Available from ${_formatDate(start)}';
    }
    if (end != null) {
      return 'Available until ${_formatDate(end)}';
    }
    return 'Always available';
  }

  String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              AfriIcons.statusError,
              size: 48,
              color: ColorTokens.error,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'Failed to load feature',
              style: TypographyTokens.titleMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              _error ?? 'Unknown error',
              style: TypographyTokens.bodySmall(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
