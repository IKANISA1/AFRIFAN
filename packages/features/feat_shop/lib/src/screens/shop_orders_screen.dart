import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Owner-scoped server history. A pending order is never shown as paid and
/// historical receipts do not grant permission to launch a payment.
class ShopOrdersScreen extends ConsumerStatefulWidget {
  const ShopOrdersScreen({super.key});
  @override
  ConsumerState<ShopOrdersScreen> createState() => _ShopOrdersScreenState();
}

class _ShopOrdersScreenState extends ConsumerState<ShopOrdersScreen> {
  List<ShopCheckoutReceipt> _orders = const [];
  String? _scope;
  bool _loading = true;
  bool _failed = false;
  int _request = 0;

  Future<void> _load(UserProfile user, String scope) async {
    final request = ++_request;
    if (!mounted || _scope != scope) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (!ConnectivityService.isOnline) throw StateError('OFFLINE');
      final rows = await ref
          .read(clubRepositoryProvider)
          .getMyShopCheckouts(user.id)
          .timeout(const Duration(seconds: 20));
      if (!mounted || request != _request || _scope != scope) return;
      setState(() => _orders = rows);
    } catch (_) {
      if (!mounted || request != _request || _scope != scope) return;
      setState(() => _failed = true);
    } finally {
      if (mounted && request == _request && _scope == scope) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final scope = user == null ? 'guest' : '${user.clubId}:${user.id}';
    if (_scope != scope) {
      _scope = scope;
      _orders = const [];
      _failed = false;
      _loading = user != null;
      ++_request;
      if (user != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scope == scope) unawaited(_load(user, scope));
        });
      }
    }
    return AfriScreenScaffold(
      title: context.afriL10n.shopOrderHistory,
      scrollable: true,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading) const Center(child: AfriLoadingIndicator()),
            if (_failed) Text(context.afriL10n.shopOrderHistoryUnavailable),
            if (!_loading && !_failed && _orders.isEmpty)
              Text(context.afriL10n.shopOrderHistoryEmpty),
            for (final receipt in _orders) ...[
              AfriSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.afriL10n.shopOriginalOrderStatus(
                        receipt.serverStatus,
                      ),
                      style: TypographyTokens.titleMedium(),
                    ),
                    SelectableText(
                      context.afriL10n.shopOrderReference(receipt.id),
                    ),
                    Text(
                      CurrencyFormatter(
                        currencyCode: receipt.currency,
                        currencySymbol: receipt.currency,
                      ).format(receipt.total),
                      style: TypographyTokens.titleLarge(),
                    ),
                    for (final item in receipt.order.items)
                      Text(
                        context.afriL10n.shopItemQuantitySummary(
                          item.product.name,
                          item.quantity,
                        ),
                      ),
                    if (receipt.pending)
                      Text(context.afriL10n.shopPreparedIsNotPaid),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
            ],
            if (user != null)
              AfriButton(
                label: context.afriL10n.shopOrderHistoryRefresh,
                enabled: !_loading,
                onTap: () => _load(user, scope),
                fullWidth: true,
              ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriButton(
              label: context.afriL10n.shopViewCart,
              variant: AfriButtonVariant.outline,
              onTap: () => context.push('/shop/cart'),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
