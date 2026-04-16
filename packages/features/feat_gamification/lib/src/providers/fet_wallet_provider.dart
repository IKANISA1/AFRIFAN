import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';

/// Snapshot of read-only wallet data (balance + transactions).
class FetWalletSnapshot {
  const FetWalletSnapshot({
    this.wallet,
    this.transactions = const <FetWalletTransaction>[],
  });

  final FetWalletSummary? wallet;
  final List<FetWalletTransaction> transactions;
}

/// Riverpod AsyncNotifier managing the FET Wallet lifecycle.
///
/// Handles loading and refreshing of wallet summary + transaction history.
/// Interactive form state (transfer/redeem controllers, search, submit flags)
/// stays in the widget since those are UI-local concerns.
///
/// Benefits:
/// - Wallet data cached across navigations
/// - Pull-to-refresh via refresh() preserves previous data
/// - DevTools observability
/// - No setState for load/error states
class FetWalletNotifier extends AsyncNotifier<FetWalletSnapshot> {
  @override
  Future<FetWalletSnapshot> build() async {
    return _load();
  }

  /// Refresh wallet data without blanking the UI.
  Future<void> refresh() async {
    state = const AsyncLoading<FetWalletSnapshot>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<FetWalletSnapshot> _load() async {
    final repo = ref.read(fetRepositoryProvider);
    final results = await Future.wait<Object?>([
      repo.loadWallet(),
      repo.loadWalletTransactions(limit: 40),
    ]);

    return FetWalletSnapshot(
      wallet: results[0] as FetWalletSummary?,
      transactions: results[1] as List<FetWalletTransaction>,
    );
  }
}

/// Provider for the FET Wallet state.
final fetWalletProvider =
    AsyncNotifierProvider<FetWalletNotifier, FetWalletSnapshot>(() {
  return FetWalletNotifier();
});
