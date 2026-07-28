import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ledger reconciliation service.
///
/// Matches pending contributions against confirmed MoMo ledger entries
/// based on amount, timing, and transaction metadata. This closes the
/// SMS → Ledger → Contribution loop.
class LedgerReconciliationService {
  LedgerReconciliationService({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  /// Run a reconciliation pass for all pending contributions.
  ///
  /// For each pending contribution, find a matching ledger entry by:
  /// 1. Same user_id
  /// 2. Same amount (±tolerance for fees)
  /// 3. Created within ±30 minutes of the contribution
  /// 4. Not already reconciled
  ///
  /// Returns the number of contributions reconciled.
  Future<int> reconcilePending({
    int amountTolerancePercent = 5,
    Duration timeWindow = const Duration(minutes: 30),
  }) async {
    int reconciled = 0;

    try {
      final pendingState = await _loadPendingContributions();
      final pendingList = pendingState.rows;

      if (pendingList.isEmpty) {
        AfriLogger.info(
          'Reconciliation',
          'Pending contribution queue is empty.',
        );
        return 0;
      }

      for (final contribution in pendingList) {
        final userId = contribution['user_id']?.toString();
        final amount = (contribution['amount'] as num?)?.toInt() ?? 0;
        final createdAt =
            DateTime.tryParse(contribution['created_at']?.toString() ?? '');

        if (userId == null || amount == 0 || createdAt == null) continue;

        // Calculate time window
        final windowStart =
            createdAt.subtract(timeWindow).toUtc().toIso8601String();
        final windowEnd = createdAt.add(timeWindow).toUtc().toIso8601String();

        // Calculate amount tolerance
        final tolerance = (amount * amountTolerancePercent / 100).ceil();
        final minAmount = amount - tolerance;
        final maxAmount = amount + tolerance;

        // Find matching unreconciled ledger entry
        final matches = await _client
            .from('momo_ledger_entries')
            .select('id, parsed_sms_id, amount, external_reference, '
                'target_table, target_record_id, tx_datetime, created_at')
            .eq('user_id', userId)
            .gte('amount', minAmount)
            .lte('amount', maxAmount)
            .gte('tx_datetime', windowStart)
            .lte('tx_datetime', windowEnd)
            .isFilter('target_record_id', null)
            .order('tx_datetime', ascending: true)
            .limit(1);

        final matchList = List<Map<String, dynamic>>.from(matches as List);

        if (matchList.isEmpty) continue;

        final ledgerEntry = matchList.first;
        final ledgerId = ledgerEntry['id']?.toString();
        final parsedSmsId = ledgerEntry['parsed_sms_id']?.toString();
        final txId = ledgerEntry['external_reference']?.toString();

        if (ledgerId == null) continue;

        // Execute reconciliation atomically
        try {
          await _confirmContribution(
            pendingState.schema,
            contribution,
            ledgerId: ledgerId,
            txId: txId,
          );

          // 2. Mark ledger entry as posted and linked
          await _client.from('momo_ledger_entries').update({
            'target_table': pendingState.targetTable,
            'target_record_id': contribution['id'],
            'ledger_status': 'posted',
          }).eq('id', ledgerId);

          // 3. Record reconciliation event
          if (parsedSmsId != null && parsedSmsId.isNotEmpty) {
            await _client.from('momo_reconciliations').upsert({
              'parsed_sms_id': parsedSmsId,
              'user_id': userId,
              'target_table': pendingState.targetTable,
              'target_record_id': contribution['id'],
              'match_type': 'auto_match',
              'match_status': 'matched',
              'confidence': _calculateConfidence(
                amount,
                (ledgerEntry['amount'] as num?)?.toInt() ?? 0,
              ),
              'reconciled_at': DateTime.now().toUtc().toIso8601String(),
              if (contribution['club_id'] != null)
                'club_id': contribution['club_id'],
              'metadata': {
                'source': 'bootstrap_reconciliation',
                'ledger_entry_id': ledgerId,
              },
            });
          }

          reconciled++;
          AfriLogger.info(
            'Reconciliation',
            'Matched contribution ${contribution['id']} '
                '→ ledger $ledgerId (tx: $txId)',
          );
        } catch (e) {
          AfriLogger.warn(
            'Reconciliation',
            'Failed to reconcile ${contribution['id']}: $e',
          );
        }
      }

      AfriLogger.info(
        'Reconciliation',
        'Pass complete: $reconciled of '
            '${pendingList.length} contributions reconciled.',
      );
    } catch (e) {
      AfriLogger.error('Reconciliation', 'Service error', e);
    }

    return reconciled;
  }

  Future<_PendingContributionState> _loadPendingContributions() async {
    final pending = await _client
        .from('group_contributions')
        .select(
          'id, user_id, amount, created_at, updated_at, '
          'group_id, momo_reference',
        )
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .limit(100);
    return _PendingContributionState(
      schema: _ContributionSchema.groupContributions,
      targetTable: 'group_contributions',
      rows: List<Map<String, dynamic>>.from(pending as List),
    );
  }

  Future<void> _confirmContribution(
    _ContributionSchema schema,
    Map<String, dynamic> contribution, {
    required String ledgerId,
    required String? txId,
  }) async {
    switch (schema) {
      case _ContributionSchema.groupContributions:
        final expectedUpdatedAt = contribution['updated_at']?.toString();
        if (expectedUpdatedAt == null || expectedUpdatedAt.isEmpty) {
          throw const ContributionConflictException();
        }
        final updated = await _client
            .from('group_contributions')
            .update({
              'status': 'confirmed',
              'momo_reference': txId ?? contribution['momo_reference'],
              'confirmed_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', contribution['id'])
            .eq('status', 'pending')
            .eq('updated_at', expectedUpdatedAt)
            .select('id')
            .maybeSingle();
        if (updated == null) {
          throw const ContributionConflictException();
        }
    }
  }

  /// Calculate match confidence based on amount difference.
  double _calculateConfidence(int expectedAmount, int actualAmount) {
    if (expectedAmount == 0) return 0.0;
    final diff = (expectedAmount - actualAmount).abs();
    final ratio = diff / expectedAmount;
    return (1.0 - ratio).clamp(0.0, 1.0);
  }
}

class ContributionConflictException implements Exception {
  const ContributionConflictException();

  @override
  String toString() =>
      'Contribution changed during reconciliation. Refresh the queue and review the latest status.';
}

enum _ContributionSchema { groupContributions }

class _PendingContributionState {
  const _PendingContributionState({
    required this.schema,
    required this.targetTable,
    required this.rows,
  });

  final _ContributionSchema schema;
  final String targetTable;
  final List<Map<String, dynamic>> rows;

  _PendingContributionState copyWith({
    _ContributionSchema? schema,
    String? targetTable,
    List<Map<String, dynamic>>? rows,
  }) {
    return _PendingContributionState(
      schema: schema ?? this.schema,
      targetTable: targetTable ?? this.targetTable,
      rows: rows ?? this.rows,
    );
  }
}

// ── Provider ──

final ledgerReconciliationServiceProvider =
    Provider<LedgerReconciliationService>((ref) {
  return LedgerReconciliationService(client: ref.watch(supabaseClientProvider));
});
