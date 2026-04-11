import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatementDownloadScreen extends ConsumerStatefulWidget {
  const StatementDownloadScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<StatementDownloadScreen> createState() =>
      _StatementDownloadScreenState();
}

class _StatementDownloadScreenState
    extends ConsumerState<StatementDownloadScreen> {
  CurrencyFormatter get _currencyFormatter => CurrencyFormatter(
    currencyCode: context.afriCurrencyCode,
    currencySymbol: context.afriCurrencySymbol,
  );

  List<_StatementEntry> _entries = const <_StatementEntry>[];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;
  DateTime? _from;
  DateTime? _to;
  String _format = 'CSV';
  final String _sort = 'date';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final rows = await _loadGroupContributionRows(client);
      final userIds = rows
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      final aliases = <String, String>{};

      if (userIds.isNotEmpty) {
        final profiles = await client
            .from('profiles')
            .select('id, public_user_id')
            .inFilter('id', userIds);
        for (final profile in profiles) {
          aliases[profile['id']?.toString() ?? ''] =
              profile['public_user_id']?.toString() ?? '000000';
        }
      }

      if (!mounted) return;

      setState(() {
        _entries = rows
            .map((row) {
              final createdAt = DateTime.tryParse(
                row['created_at']?.toString() ?? '',
              );
              final alias =
                  aliases[row['user_id']?.toString() ?? ''] ?? '000000';
              final status = row['status']?.toString() ?? 'pending';
              return _StatementEntry(
                id: row['id']?.toString() ?? '',
                alias: '#$alias',
                amount: (row['amount'] as num?)?.toInt() ?? 0,
                status: status,
                reference: row['momo_reference']?.toString() ?? '',
                createdAt: createdAt ?? DateTime.now(),
              );
            })
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load statement entries for this circle.';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadGroupContributionRows(
    SupabaseClient client,
  ) async {
    var contributionQuery = client
        .from('group_contributions')
        .select('id, user_id, amount, status, momo_reference, created_at')
        .eq('group_id', widget.groupId);

    if (_from != null) {
      contributionQuery = contributionQuery.gte(
        'created_at',
        DateTime(
          _from!.year,
          _from!.month,
          _from!.day,
        ).toUtc().toIso8601String(),
      );
    }
    if (_to != null) {
      contributionQuery = contributionQuery.lt(
        'created_at',
        DateTime(_to!.year, _to!.month, _to!.day + 1).toUtc().toIso8601String(),
      );
    }

    return List<Map<String, dynamic>>.from(
      await contributionQuery.order('created_at', ascending: false) as List,
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initialDate = isFrom
        ? (_from ?? DateTime.now())
        : (_to ?? _from ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to != null && _to!.isBefore(_from!)) {
          _to = _from;
        }
      } else {
        _to = picked;
      }
    });
    await _loadEntries();
  }

  List<_StatementEntry> get _sortedEntries {
    final entries = List<_StatementEntry>.from(_entries);
    switch (_sort) {
      case 'amount':
        entries.sort((a, b) => b.amount.compareTo(a.amount));
      case 'alias':
        entries.sort((a, b) => a.alias.compareTo(b.alias));
      case 'date':
        entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return entries;
  }

  int get _statementTotal {
    return _entries
        .where(
          (entry) => entry.status != 'failed' && entry.status != 'reversed',
        )
        .fold<int>(0, (sum, entry) => sum + entry.amount);
  }

  Future<void> _downloadStatement() async {
    if (_format == 'PDF') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF export not available yet. Use CSV.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    final rows = _sortedEntries;
    final buffer = StringBuffer()
      ..writeln('Alias,Amount,Status,Reference,Date');

    for (final row in rows) {
      buffer.writeln(
        [
          row.alias,
          row.amount,
          row.status,
          row.reference,
          row.createdAt.toIso8601String(),
        ].map(_escapeCsv).join(','),
      );
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;

    setState(() => _isExporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          rows.isEmpty
              ? 'No rows matched. Empty CSV copied.'
              : 'CSV copied to clipboard.',
        ),
      ),
    );
  }

  String _escapeCsv(Object? value) {
    final field = value?.toString() ?? '';
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  @override
  Widget build(BuildContext context) {
    final currency = _currencyFormatter;
    final previewEntries = _sortedEntries.take(5).toList(growable: false);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'DOWNLOAD STATEMENT',
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : RefreshIndicator(
              onRefresh: _loadEntries,
              child: ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  if (_error != null)
                    GlassCard(
                      animate: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_error!, style: TypographyTokens.bodyMedium()),
                          const SizedBox(height: SpacingTokens.spacing3),
                          ClaymorphicButton(
                            label: 'TRY AGAIN',
                            width: double.infinity,
                            onPressed: _loadEntries,
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _DateInputCard(
                            label: 'FROM',
                            value: _from == null
                                ? 'All time'
                                : DateFormat('dd MMM yyyy').format(_from!),
                            onTap: () => _pickDate(isFrom: true),
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.spacing3),
                        Expanded(
                          child: _DateInputCard(
                            label: 'TO',
                            value: _to == null
                                ? 'Now'
                                : DateFormat('dd MMM yyyy').format(_to!),
                            onTap: () => _pickDate(isFrom: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    GlassCard(
                      animate: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SORT', style: TypographyTokens.labelSmall()),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Wrap(
                            spacing: SpacingTokens.spacing2,
                            children:
                                const [
                                      ('date', 'BY DATE'),
                                      ('amount', 'BY AMOUNT'),
                                      ('alias', 'BY ALIAS'),
                                    ]
                                    .map(
                                      (option) => const ChoiceChip(
                                        selected: false,
                                        label: Text(''),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    Row(
                      children: [
                        Expanded(
                          child: _FormatCard(
                            label: 'PDF',
                            icon: Icons.picture_as_pdf_rounded,
                            selected: _format == 'PDF',
                            onTap: () => setState(() => _format = 'PDF'),
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.spacing3),
                        Expanded(
                          child: _FormatCard(
                            label: 'CSV',
                            icon: Icons.table_chart_rounded,
                            selected: _format == 'CSV',
                            onTap: () => setState(() => _format = 'CSV'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    GlassCard(
                      animate: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'PREVIEW',
                                  style: TypographyTokens.labelSmall(),
                                ),
                              ),
                              Text(
                                currency.format(_statementTotal),
                                style: TypographyTokens.monolithFont(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: ColorTokens.clubAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            'Alias IDs only — no names or phone numbers.',
                            style: TypographyTokens.bodySmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          if (previewEntries.isEmpty)
                            Text(
                              'No contributions in this range.',
                              style: TypographyTokens.bodyMedium(),
                            )
                          else
                            ...previewEntries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: SpacingTokens.spacing2,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        entry.alias,
                                        style: TypographyTokens.bodySmall(),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        currency.format(entry.amount),
                                        style: TypographyTokens.bodySmall(),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        DateFormat(
                                          'dd MMM',
                                        ).format(entry.createdAt),
                                        style: TypographyTokens.bodySmall(),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing6),
                    ClaymorphicButton(
                      label: _isExporting ? 'EXPORTING…' : 'DOWNLOAD',
                      width: double.infinity,
                      onPressed: _isExporting ? null : _downloadStatement,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _DateInputCard extends StatelessWidget {
  const _DateInputCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TypographyTokens.labelSmall()),
            const SizedBox(height: SpacingTokens.spacing2),
            Row(
              children: [
                Expanded(
                  child: Text(value, style: TypographyTokens.bodyMedium()),
                ),
                const Icon(Icons.calendar_today_rounded, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: GlassCard(
        animate: false,
        borderColor: selected
            ? ColorTokens.clubPrimary.withValues(alpha: 0.8)
            : ColorTokens.ghostBorder,
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? ColorTokens.clubPrimary : ColorTokens.onSurface,
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              label,
              style: TypographyTokens.monolithFont(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: ColorTokens.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatementEntry {
  const _StatementEntry({
    required this.id,
    required this.alias,
    required this.amount,
    required this.status,
    required this.reference,
    required this.createdAt,
  });

  final String id;
  final String alias;
  final int amount;
  final String status;
  final String reference;
  final DateTime createdAt;
}
