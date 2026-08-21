import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Raised when released-client code attempts to reconcile financial records.
///
/// Contribution confirmation requires a trusted service to call the atomic
/// `reconcile_group_contribution_from_sms` database boundary. A mobile session
/// never receives permission to update a contribution, ledger entry, or
/// reconciliation record directly.
class ClientReconciliationDisabledException implements Exception {
  const ClientReconciliationDisabledException();

  @override
  String toString() =>
      'Contribution reconciliation is server-controlled. The released client '
      'cannot confirm or mutate payment records.';
}

/// Legacy conflict type retained for callers that surface a stale-review
/// message. The released mobile client no longer performs that review itself.
class ContributionConflictException implements Exception {
  const ContributionConflictException();

  @override
  String toString() =>
      'Contribution changed during reconciliation. Refresh the queue and review the latest status.';
}

/// Fail-closed mobile boundary for contribution reconciliation.
///
/// The constructor keeps its existing shape so dependency injection remains
/// source-compatible. The client is intentionally not retained: possessing a
/// supporter Supabase session must never become a payment-confirmation path.
class LedgerReconciliationService {
  const LedgerReconciliationService({required SupabaseClient client});

  /// Reconciliation is intentionally unavailable to the released client.
  ///
  /// Trusted backend code must load exact `updated_at` tokens and invoke
  /// `reconcile_group_contribution_from_sms` with an audit actor and idempotency
  /// key. Keeping this method fail-closed prevents a future UI caller from
  /// silently restoring the former multi-write client transaction.
  Future<int> reconcilePending({
    int amountTolerancePercent = 5,
    Duration timeWindow = const Duration(minutes: 30),
  }) async {
    throw const ClientReconciliationDisabledException();
  }
}

final ledgerReconciliationServiceProvider =
    Provider<LedgerReconciliationService>((ref) {
      return LedgerReconciliationService(
        client: ref.watch(supabaseClientProvider),
      );
    });
