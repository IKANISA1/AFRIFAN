import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Map<String, dynamic>? _feature;
  List<Map<String, dynamic>> _channels = [];
  Map<String, dynamic>? _rules;
  bool _isLoading = true;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = SupabaseClientFactory.client;

      // 1. Load the feature
      final featureResp = await client
          .from('platform_features')
          .select()
          .eq('feature_key', widget.featureKey)
          .maybeSingle();

      if (featureResp == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = 'Feature "${widget.featureKey}" not found.';
        });
        return;
      }

      final featureId = featureResp['id'] as String;

      // 2. Load channels
      final channelsResp = await client
          .from('platform_feature_channels')
          .select()
          .eq('feature_id', featureId)
          .order('channel');

      // 3. Load rules
      final rulesResp = await client
          .from('platform_feature_rules')
          .select()
          .eq('feature_id', featureId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _feature = Map<String, dynamic>.from(featureResp);
        _channels = List<Map<String, dynamic>>.from(channelsResp as List);
        _rules = rulesResp != null
            ? Map<String, dynamic>.from(rulesResp)
            : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
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
                        : RefreshIndicator(
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
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(AfriIcons.chevronLeft),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _feature?['display_name'] as String? ?? widget.featureKey,
                  style: TypographyTokens.titleMedium(),
                ),
                Text(
                  widget.featureKey,
                  style: TypographyTokens.bodySmall().copyWith(
                    color: Colors.white38,
                    fontFamily: 'monospace',
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('GLOBAL STATE'),
          const SizedBox(height: SpacingTokens.spacing3),
          _buildGlobalState(),
          const SizedBox(height: SpacingTokens.spacing6),
          _buildSectionTitle('CHANNEL CONFIG'),
          const SizedBox(height: SpacingTokens.spacing3),
          ..._channels.map(_buildChannelCard),
          if (_channels.isEmpty)
            _buildEmptyState('No channel configs found'),
          const SizedBox(height: SpacingTokens.spacing6),
          _buildSectionTitle('SCHEDULING'),
          const SizedBox(height: SpacingTokens.spacing3),
          _buildScheduleCard(),
          const SizedBox(height: SpacingTokens.spacing6),
          _buildSectionTitle('ACCESS RULES'),
          const SizedBox(height: SpacingTokens.spacing3),
          _buildAccessRulesCard(),
          const SizedBox(height: SpacingTokens.spacing8),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TypographyTokens.titleSmall().copyWith(
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.5,
      ),
    );
  }

  // ──── Global state ────

  Widget _buildGlobalState() {
    final enabled = _feature?['is_enabled'] as bool? ?? true;
    final visibility = _feature?['visibility_state'] as String? ?? 'visible';

    return GlassCard(
      animate: false,
      child: Column(
        children: [
          _buildToggleRow(
            label: 'Enabled',
            subtitle: 'Global kill switch for this feature',
            value: enabled,
            onChanged: (v) => _updateFeature({'is_enabled': v}),
          ),
          const Divider(color: Colors.white10),
          _buildVisibilityRow(
            current: visibility,
            onChanged: (v) => _updateFeature({'visibility_state': v}),
          ),
        ],
      ),
    );
  }

  // ──── Channel config cards ────

  Widget _buildChannelCard(Map<String, dynamic> channel) {
    final channelName = (channel['channel'] as String).toUpperCase();
    final channelEnabled = channel['is_enabled'] as bool? ?? true;
    final channelVisible = channel['is_visible'] as bool? ?? true;
    final showInNav = channel['show_in_navigation'] as bool? ?? false;
    final showOnHome = channel['show_on_home'] as bool? ?? false;
    final sortOrder = channel['sort_order'] as int?;
    final channelId = channel['id'] as String;

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
                  channelName == 'MOBILE'
                      ? Icons.phone_android
                      : Icons.language,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Text(
                  channelName,
                  style: TypographyTokens.titleSmall()
                      .copyWith(letterSpacing: 1.2),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            _buildToggleRow(
              label: 'Enabled',
              subtitle: 'Feature active on $channelName',
              value: channelEnabled,
              onChanged: (v) => _updateChannel(channelId, {'is_enabled': v}),
            ),
            const Divider(color: Colors.white10),
            _buildToggleRow(
              label: 'Visible',
              subtitle: 'Show in $channelName UI',
              value: channelVisible,
              onChanged: (v) => _updateChannel(channelId, {'is_visible': v}),
            ),
            const Divider(color: Colors.white10),
            _buildToggleRow(
              label: 'Show in Navigation',
              subtitle: channelName == 'MOBILE'
                  ? 'Bottom navigation tab'
                  : 'Top navigation menu',
              value: showInNav,
              onChanged: (v) =>
                  _updateChannel(channelId, {'show_in_navigation': v}),
            ),
            const Divider(color: Colors.white10),
            _buildToggleRow(
              label: 'Show on Home',
              subtitle: 'Display on home screen',
              value: showOnHome,
              onChanged: (v) =>
                  _updateChannel(channelId, {'show_on_home': v}),
            ),
            const Divider(color: Colors.white10),
            _buildSortOrderRow(
              current: sortOrder,
              onChanged: (v) =>
                  _updateChannel(channelId, {'sort_order': v}),
            ),
          ],
        ),
      ),
    );
  }

  // ──── Schedule card ────

  Widget _buildScheduleCard() {
    final startAt = _rules?['schedule_start_at'] as String?;
    final endAt = _rules?['schedule_end_at'] as String?;
    final startDate = startAt != null ? DateTime.tryParse(startAt) : null;
    final endDate = endAt != null ? DateTime.tryParse(endAt) : null;

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
          const Divider(color: Colors.white10),
          _buildDatePickerRow(
            label: 'Available Until',
            subtitle: 'Feature deactivates',
            value: endDate,
            onChanged: (date) => _updateRules({
              'schedule_end_at': date?.toUtc().toIso8601String(),
            }),
          ),
          if (startDate != null || endDate != null) ...[
            const Divider(color: Colors.white10),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.spacing2,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.white38),
                  const SizedBox(width: SpacingTokens.spacing2),
                  Expanded(
                    child: Text(
                      _scheduleDescription(startDate, endDate),
                      style: TypographyTokens.bodySmall()
                          .copyWith(color: Colors.white54),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _updateRules({
                      'schedule_start_at': null,
                      'schedule_end_at': null,
                    }),
                    child: Text(
                      'Clear',
                      style: TypographyTokens.bodySmall()
                          .copyWith(color: Colors.red.shade400),
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

  // ──── Access rules card ────

  Widget _buildAccessRulesCard() {
    final authRequired = _rules?['auth_required'] as bool? ?? false;

    return GlassCard(
      animate: false,
      child: Column(
        children: [
          _buildToggleRow(
            label: 'Auth Required',
            subtitle: 'User must be signed in to access',
            value: authRequired,
            onChanged: (v) => _updateRules({'auth_required': v}),
          ),
        ],
      ),
    );
  }

  // ──── Reusable row builders ────

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
                  style: TypographyTokens.bodySmall()
                      .copyWith(color: Colors.white38),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: _isSaving ? null : onChanged,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityRow({
    required String current,
    required ValueChanged<String> onChanged,
  }) {
    final color = switch (current) {
      'visible' => Colors.green.shade400,
      'hidden' => Colors.red.shade400,
      'maintenance' => Colors.orange.shade400,
      _ => Colors.grey,
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
                  style: TypographyTokens.bodySmall()
                      .copyWith(color: Colors.white38),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: onChanged,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'visible', child: Text('Visible')),
              const PopupMenuItem(value: 'hidden', child: Text('Hidden')),
              const PopupMenuItem(
                value: 'maintenance',
                child: Text('Maintenance'),
              ),
            ],
            child: Chip(
              label: Text(
                current.toUpperCase(),
                style: TypographyTokens.bodySmall()
                    .copyWith(color: color, fontSize: 10),
              ),
              side: BorderSide(color: color.withValues(alpha: 0.3)),
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
                  style: TypographyTokens.bodySmall()
                      .copyWith(color: Colors.white38),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: current?.toString() ?? '',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing2,
                  vertical: SpacingTokens.spacing2,
                ),
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) onChanged(parsed);
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
                  style: TypographyTokens.bodySmall()
                      .copyWith(color: Colors.white38),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _pickDateTime(value, onChanged),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
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
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──── Date/time picker ────

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

  // ──── Mutation helpers ────

  Future<void> _updateFeature(Map<String, dynamic> updates) async {
    if (_feature == null) return;
    setState(() => _isSaving = true);
    try {
      final client = SupabaseClientFactory.client;
      await client
          .from('platform_features')
          .update(updates)
          .eq('id', _feature!['id'] as String);
      await _load();
    } catch (e) {
      _showError('Failed to update feature: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateChannel(
    String channelId,
    Map<String, dynamic> updates,
  ) async {
    setState(() => _isSaving = true);
    try {
      final client = SupabaseClientFactory.client;
      await client
          .from('platform_feature_channels')
          .update(updates)
          .eq('id', channelId);
      await _load();
    } catch (e) {
      _showError('Failed to update channel: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateRules(Map<String, dynamic> updates) async {
    if (_feature == null) return;
    setState(() => _isSaving = true);
    try {
      final client = SupabaseClientFactory.client;
      final featureId = _feature!['id'] as String;

      if (_rules != null) {
        await client
            .from('platform_feature_rules')
            .update(updates)
            .eq('feature_id', featureId);
      } else {
        await client.from('platform_feature_rules').insert({
          'feature_id': featureId,
          ...updates,
        });
      }
      await _load();
    } catch (e) {
      _showError('Failed to update rules: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  // ──── Helpers ────

  String _scheduleDescription(DateTime? start, DateTime? end) {
    if (start != null && end != null) {
      return 'Active from ${_formatDate(start)} to ${_formatDate(end)}';
    } else if (start != null) {
      return 'Available from ${_formatDate(start)}';
    } else if (end != null) {
      return 'Available until ${_formatDate(end)}';
    }
    return 'Always available';
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: Center(
        child: Text(
          message,
          style: TypographyTokens.bodySmall().copyWith(color: Colors.white38),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: SpacingTokens.spacing4),
            Text('Failed to load feature', style: TypographyTokens.titleMedium()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              _error ?? 'Unknown error',
              style: TypographyTokens.bodySmall(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
