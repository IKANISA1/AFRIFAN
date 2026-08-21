import 'dart:convert';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Statement export service for generating contribution and ledger reports.
///
/// Generates CSV-formatted data for download/sharing. Reports are scoped
/// to the authenticated user's club via RLS.
class StatementExportService {
  StatementExportService({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  String get _defaultCurrency => RuntimeBranding.displayCurrencyCode;

  /// Export all contributions for a specific group as CSV.
  Future<String> exportGroupContributions(String groupId) async {
    final rows = await _loadContributionRows(groupId);
    return _toCsv(
      headers: [
        'ID',
        'User ID',
        'Amount',
        'Currency',
        'Status',
        'Reference',
        'Confirmed At',
        'Created At',
      ],
      rows: rows
          .map(
            (r) => [
              r['id'],
              r['user_id'],
              r['amount'],
              r['currency'] ?? _defaultCurrency,
              r['status'],
              r['momo_reference'] ?? r['client_request_reference'] ?? '',
              r['confirmed_at'] ?? '',
              r['created_at'],
            ],
          )
          .toList(),
    );
  }

  /// Export the user's MoMo ledger entries as CSV.
  Future<String> exportLedgerEntries({
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) async {
    var query = _client
        .from('momo_ledger_entries')
        .select(
          'id, amount, currency, external_reference, '
          'counterparty_name, description, tx_category, '
          'cashflow_bucket, ledger_status, tx_datetime, created_at',
        );

    if (from != null) {
      query = query.gte('tx_datetime', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lte('tx_datetime', to.toUtc().toIso8601String());
    }

    final data = await query.order('created_at', ascending: false).limit(limit);

    final rows = List<Map<String, dynamic>>.from(data as List);
    return _toCsv(
      headers: [
        'ID',
        'Amount',
        'Currency',
        'Reference',
        'Counterparty',
        'Description',
        'Category',
        'Cashflow',
        'Ledger Status',
        'Occurred At',
        'Created At',
      ],
      rows: rows
          .map(
            (r) => [
              r['id'],
              r['amount'],
              r['currency'] ?? _defaultCurrency,
              r['external_reference'] ?? '',
              r['counterparty_name'] ?? '',
              r['description'] ?? '',
              r['tx_category'] ?? '',
              r['cashflow_bucket'] ?? '',
              r['ledger_status'] ?? '',
              r['tx_datetime'] ?? '',
              r['created_at'],
            ],
          )
          .toList(),
    );
  }

  /// Export a summary of all contribution groups.
  Future<String> exportGroupsSummary() async {
    final rows = await _loadGroupRows();
    return _toCsv(
      headers: [
        'ID',
        'Name',
        'Type',
        'Target',
        'Current Total',
        'Currency',
        'Members',
        'Active',
        'Created At',
      ],
      rows: rows
          .map(
            (r) => [
              r['id'],
              r['name'],
              r['group_type'],
              r['target_amount'],
              r['current_total'],
              r['currency'] ?? _defaultCurrency,
              r['member_count'],
              r['is_active'] ?? !(r['is_closed'] as bool? ?? false),
              r['created_at'],
            ],
          )
          .toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _loadContributionRows(
    String groupId,
  ) async {
    final contributions = await _client
        .from('group_contributions')
        .select(
          'id, user_id, amount, status, client_request_reference, '
          'momo_reference, confirmed_at, created_at',
        )
        .eq('group_id', groupId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      (contributions as List).map(
        (row) => <String, dynamic>{
          ...Map<String, dynamic>.from(row as Map),
          'currency': _defaultCurrency,
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadGroupRows() async {
    final data = await _client
        .from('contribution_groups')
        .select(
          'id, name, group_type, target_amount, '
          'current_total, currency, member_count, is_active, '
          'is_closed, created_at',
        )
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List)
        .map(
          (row) => <String, dynamic>{
            ...row,
            'currency': row['currency'] ?? _defaultCurrency,
            'is_active':
                row['is_active'] ?? !(row['is_closed'] as bool? ?? false),
          },
        )
        .toList(growable: false);
  }

  /// Convert rows to CSV string.
  String _toCsv({
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeCsvField).join(','));
    for (final row in rows) {
      buffer.writeln(
        row.map((field) => _escapeCsvField(field.toString())).join(','),
      );
    }
    return buffer.toString();
  }

  /// Escape a CSV field (handle commas, quotes, newlines).
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Generate a base64-encoded CSV for easy sharing via URIs.
  String toCsvDataUri(String csvContent) {
    final bytes = utf8.encode(csvContent);
    final base64Data = base64Encode(bytes);
    return 'data:text/csv;base64,$base64Data';
  }
}

// ── Provider ──

final statementExportServiceProvider = Provider<StatementExportService>((ref) {
  return StatementExportService(client: ref.watch(supabaseClientProvider));
});
