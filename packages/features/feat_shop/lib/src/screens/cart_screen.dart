import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shop_cart_provider.dart';
import '../widgets/cart_item_card.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  late final TextEditingController _addressController;
  bool _submitting = false;
  PartnerPaymentRoute? _paymentRoute;
  String? _paymentRouteMessage;
  String? _paymentRouteLookupKey;

  CurrencyFormatter get _currencyFormatter => CurrencyFormatter(
    currencyCode: context.afriCurrencyCode,
    currencySymbol: context.afriCurrencySymbol,
  );

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _ensurePaymentRouteState(UserProfile? user) {
    final lookupKey = user == null ? 'guest' : '${user.id}:${user.clubId}';
    if (_paymentRouteLookupKey == lookupKey) {
      return;
    }

    _paymentRouteLookupKey = lookupKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPaymentRouteState(user);
    });
  }

  Future<void> _refreshPaymentRouteState(UserProfile? user) async {
    final lookupKey = _paymentRouteLookupKey;
    if (user == null) {
      if (!mounted || lookupKey != _paymentRouteLookupKey) return;
      setState(() {
        _paymentRoute = null;
        _paymentRouteMessage = null;
      });
      return;
    }

    final route = await ref
        .read(clubRepositoryProvider)
        .findActivePaymentRoute(user.clubId);

    if (!mounted || lookupKey != _paymentRouteLookupKey) return;
    setState(() {
      _paymentRoute = route;
      _paymentRouteMessage = route == null
          ? 'No active checkout route for this club.'
          : null;
    });
  }

  Future<void> _checkout(List<CartItem> items, int total) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/onboarding');
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a delivery address first.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final repo = ref.read(clubRepositoryProvider);
      final route =
          _paymentRoute ?? await repo.findActivePaymentRoute(user.clubId);
      if (route == null) {
        if (!mounted) return;
        setState(() {
          _paymentRouteMessage = 'No active checkout route for this club.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This club does not have an active MOMO checkout route yet.',
            ),
            backgroundColor: ColorTokens.error,
          ),
        );
        return;
      }

      final launched = await MomoDialerService.launchMomoUssd(
        recipient: route.recipientCode,
        amount: total,
        country: route.country,
        recipientType: PaymentRecipientType.code,
      );

      if (!mounted) return;

      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch the MOMO dialer.'),
            backgroundColor: ColorTokens.error,
          ),
        );
        return;
      }

      final confirmed = await _showCheckoutConfirmSheet(
        items: items,
        total: total,
      );

      if (!confirmed || !mounted) return;

      final orderId = await repo.placeOrder(
        userId: user.id,
        partnerId: user.clubId,
        items: items,
        deliveryAddress: _addressController.text.trim(),
        paymentReference: 'order-${DateTime.now().millisecondsSinceEpoch}',
      );

      ref.read(shopCartProvider.notifier).clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order $orderId created. Payment verification is still pending.',
          ),
          backgroundColor: ColorTokens.info,
        ),
      );
      context.go('/shop');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checkout failed: $error'),
          backgroundColor: ColorTokens.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<bool> _showCheckoutConfirmSheet({
    required List<CartItem> items,
    required int total,
  }) async {
    final currency = _currencyFormatter;
    final result = await showAfriBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review order', style: TypographyTokens.headlineMedium()),
            const SizedBox(height: SpacingTokens.spacing3),
            ClayCard(
              padding: const EdgeInsets.all(SpacingTokens.spacing5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary', style: TypographyTokens.labelLarge()),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ...items
                      .take(3)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.spacing2,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.product.name}  x${item.quantity}',
                                  style: TypographyTokens.bodyMedium(),
                                ),
                              ),
                              Text(
                                currency.format(item.lineTotal),
                                style: TypographyTokens.labelLarge(),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (items.length > 3)
                    Text(
                      '+${items.length - 3} more items',
                      style: TypographyTokens.bodySmall(),
                    ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text('Deliver to', style: TypographyTokens.labelSmall()),
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    _addressController.text.trim(),
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    currency.format(total),
                    style: TypographyTokens.headlineSmall(
                      ColorTokens.clubAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              'Approve the MOMO prompt, then confirm once you have submitted the payment request. Orders remain pending until verification completes.',
              style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(
              label: 'I submitted the MOMO request',
              fullWidth: true,
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Back'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final config = ClubConfigScope.maybeOf(context);
    final currency = _currencyFormatter;
    final deliveryHint = config == null
        ? 'Enter your delivery address'
        : 'Street, city, ${config.country}';
    _ensurePaymentRouteState(user);

    final items = ref.watch(shopCartProvider);
    final total = ref.watch(shopCartTotalProvider);
    final paymentRouteBlocked = user != null && _paymentRouteMessage != null;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Cart', style: TypographyTokens.headlineSmall()),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 56,
                      color: ColorTokens.onSurfaceVariant,
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    Text(
                      'Cart is empty',
                      style: TypographyTokens.headlineSmall(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      'Add items from the shop to start checkout.',
                      textAlign: TextAlign.center,
                      style: TypographyTokens.bodyMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing6),
                    AfriButton(
                      label: 'Back to shop',
                      onTap: () => context.go('/shop'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: Column(
                children: [
                  ...items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: SpacingTokens.spacing3,
                      ),
                      child: CartItemCard(
                        item: item,
                        priceLabel: currency.format(item.lineTotal),
                        onIncrement: () =>
                            ref.read(shopCartProvider.notifier).increment(item),
                        onDecrement: () =>
                            ref.read(shopCartProvider.notifier).decrement(item),
                        onRemove: () =>
                            ref.read(shopCartProvider.notifier).remove(item),
                      ),
                    );
                  }),
                  const SizedBox(height: SpacingTokens.spacing4),
                  ClayCard(
                    padding: const EdgeInsets.all(SpacingTokens.spacing5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AfriSectionHeader(
                          title: 'Delivery',
                          subtitle: 'Address and total',
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        TextField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: InputDecoration(hintText: deliveryHint),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal',
                              style: TypographyTokens.bodyMedium(),
                            ),
                            Text(
                              currency.format(total),
                              style: TypographyTokens.bodyLarge(),
                            ),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Delivery',
                              style: TypographyTokens.bodyMedium(),
                            ),
                            Text(
                              currency.format(0),
                              style: TypographyTokens.bodyLarge(),
                            ),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TOTAL', style: TypographyTokens.labelLarge()),
                            Text(
                              currency.format(total),
                              style: TypographyTokens.headlineSmall(
                                ColorTokens.clubAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_paymentRouteMessage != null) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriStateView.offline(
                      title: 'Checkout unavailable',
                      message: _paymentRouteMessage!,
                      compact: true,
                    ),
                  ] else if (_paymentRoute != null) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    ClayCard(
                      padding: const EdgeInsets.all(SpacingTokens.spacing4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: ColorTokens.success,
                          ),
                          const SizedBox(width: SpacingTokens.spacing3),
                          Expanded(
                            child: Text(
                              'Pay to ${_paymentRoute!.payToLabel}',
                              style: TypographyTokens.bodyMedium(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: SpacingTokens.spacing6),
                  AfriButton(
                    label: paymentRouteBlocked
                        ? 'Payment route not ready'
                        : _submitting
                        ? 'Processing'
                        : 'Checkout via MOMO',
                    fullWidth: true,
                    isLoading: _submitting,
                    onTap: () => _checkout(items, total),
                    enabled: !_submitting && !paymentRouteBlocked,
                  ),
                ],
              ),
            ),
    );
  }
}
