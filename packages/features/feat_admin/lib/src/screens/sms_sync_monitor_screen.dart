import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SmsSyncMonitorScreen extends ConsumerStatefulWidget {
  const SmsSyncMonitorScreen({super.key});

  @override
  ConsumerState<SmsSyncMonitorScreen> createState() =>
      _SmsSyncMonitorScreenState();
}

class _SmsSyncMonitorScreenState extends ConsumerState<SmsSyncMonitorScreen> {
  Map<String, int> _metrics = const {};
  List<Map<String, dynamic>> _recentSyncRuns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSmsData();
  }

  Future<void> _loadSmsData() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final rawCount = await client
          .from('momo_sms_raw')
          .select('id')
          .count(CountOption.exact);
      final parsedCount = await client
          .from('momo_sms_parsed')
          .select('id')
          .count(CountOption.exact);
      final ledgerCount = await client
          .from('momo_ledger_entries')
          .select('id')
          .count(CountOption.exact);
      final syncRuns = await client
          .from('momo_sms_sync_runs')
          .select('*')
          .order('scan_started_at', ascending: false)
          .limit(10);

      if (!mounted) return;
      setState(() {
        _metrics = {
          'SMS CAPTURED': rawCount.count,
          'SMS PARSED': parsedCount.count,
          'LEDGER ENTRIES': ledgerCount.count,
        };
        _recentSyncRuns = List<Map<String, dynamic>>.from(syncRuns as List);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Tables might not exist yet
        _metrics = {'SMS CAPTURED': 0, 'SMS PARSED': 0, 'LEDGER ENTRIES': 0};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('SMS PIPELINE', style: TypographyTokens.titleLarge()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : AfriRefreshIndicator(
              onRefresh: _loadSmsData,
              child: ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  _buildPipelineMetrics(),
                  const SizedBox(height: SpacingTokens.spacing6),
                  _buildPipelineFlow(),
                  const SizedBox(height: SpacingTokens.spacing6),
                  _buildRecentSyncRuns(),
                ],
              ),
            ),
    );
  }

  Widget _buildPipelineMetrics() {
    final entries = _metrics.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PIPELINE HEALTH',
          style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        Row(
          children: entries
              .map(
                (e) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: e != entries.last ? SpacingTokens.spacing3 : 0,
                    ),
                    child: GlassCard(
                      animate: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key, style: TypographyTokens.labelSmall()),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            '${e.value}',
                            style: TypographyTokens.headlineSmall().copyWith(
                              color: ColorTokens.clubAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPipelineFlow() {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SMS → LEDGER PIPELINE',
            style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          const _PipelineStep(
            step: '1',
            label: 'CAPTURE',
            description: 'Android SMS listener → approved sender filter',
            icon: AfriIcons.sms,
          ),
          const _PipelineStep(
            step: '2',
            label: 'INGEST',
            description: 'SHA256 dedup → Edge Function → momo_sms_raw',
            icon: AfriIcons.cloud,
          ),
          const _PipelineStep(
            step: '3',
            label: 'PARSE',
            description: 'Extract amount, tx_id, fee → momo_sms_parsed',
            icon: AfriIcons.magic,
          ),
          const _PipelineStep(
            step: '4',
            label: 'LEDGER',
            description: 'Create wallet entry → reconcile contributions',
            icon: AfriIcons.wallet,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSyncRuns() {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENT SYNC RUNS',
            style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (_recentSyncRuns.isNotEmpty)
            ..._recentSyncRuns.map(
              (run) => Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
                child: _SyncRunRow(run: run),
              ),
            ),
        ],
      ),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  const _PipelineStep({
    required this.step,
    required this.label,
    required this.description,
    required this.icon,
    this.isLast = false,
  });

  final String step;
  final String label;
  final String description;
  final IconData icon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : SpacingTokens.spacing3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, size: 16, color: ColorTokens.clubAccent),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 16,
                  color: ColorTokens.surfaceContainerLow,
                ),
            ],
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$step. $label', style: TypographyTokens.titleMedium()),
                Text(description, style: TypographyTokens.bodyMedium()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncRunRow extends StatelessWidget {
  const _SyncRunRow({required this.run});

  final Map<String, dynamic> run;

  @override
  Widget build(BuildContext context) {
    final status = run['status']?.toString() ?? 'unknown';
    final trigger = run['trigger']?.toString() ?? '';
    final scanned = (run['scanned_messages'] as num?)?.toInt() ?? 0;
    final uploaded = (run['uploaded_messages'] as num?)?.toInt() ?? 0;
    final startedAt = DateTime.tryParse(
      run['scan_started_at']?.toString() ?? '',
    );

    final statusColor = switch (status) {
      'succeeded' => ColorTokens.success,
      'failed' => ColorTokens.error,
      'rate_limited' => ColorTokens.warning,
      _ => ColorTokens.onSurfaceVariant,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${status.toUpperCase()}  •  $trigger',
                  style: TypographyTokens.bodyLarge(),
                ),
                Text(
                  'Scanned: $scanned  •  Uploaded: $uploaded  •  ${startedAt != null ? DateFormat('dd MMM HH:mm').format(startedAt) : ''}',
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
