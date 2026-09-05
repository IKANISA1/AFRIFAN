import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shop_cart_provider.dart';
import '../widgets/cart_item_card.dart';

typedef CartPaymentRouteLoader =
    Future<PartnerPaymentRoute?> Function(String clubId);

typedef CartOrderPlacer =
    Future<String> Function({
      required String userId,
      required String partnerId,
      required List<CartItem> items,
      required String deliveryAddress,
      required String paymentReference,
    });

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({
    super.key,
    this.paymentRouteLoader,
    this.orderPlacer,
    this.checkoutTimeout = const Duration(seconds: 30),
  });

  final CartPaymentRouteLoader? paymentRouteLoader;
  final CartOrderPlacer? orderPlacer;
  final Duration checkoutTimeout;

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  late final TextEditingController _addressController;
  late final FocusNode _addressFocusNode;
  bool _submitting = false;
  String? _addressError;
  PartnerPaymentRoute? _paymentRoute;
  String? _paymentRouteMessage;
  String? _paymentRouteError;
  bool _paymentRouteLoading = false;
  String? _paymentRouteLookupKey;
  _CartCheckoutFailure? _checkoutFailure;
  late bool _wasOnline;

  CurrencyFormatter get _currencyFormatter => CurrencyFormatter(
    currencyCode: context.afriCurrencyCode,
    currencySymbol: context.afriCurrencySymbol,
  );

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _addressFocusNode = FocusNode(debugLabel: 'Delivery address');
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;
    if (!mounted) return;

    if (!isOnline) {
      setState(() {
        _paymentRouteLoading = false;
        _paymentRouteError = null;
        _paymentRouteMessage = context.afriL10n.shopConnectPaymentAvailability;
      });
    } else if (restored) {
      unawaited(_refreshPaymentRouteState(ref.read(currentUserProvider)));
    }
  }

  void _ensurePaymentRouteState(UserProfile? user) {
    final lookupKey = user == null ? 'guest' : '${user.id}:${user.clubId}';
    if (_paymentRouteLookupKey == lookupKey) {
      return;
    }

    _paymentRouteLookupKey = lookupKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshPaymentRouteState(user));
    });
  }

  Future<void> _refreshPaymentRouteState(UserProfile? user) async {
    final lookupKey = _paymentRouteLookupKey;
    if (user == null) {
      if (!mounted || lookupKey != _paymentRouteLookupKey) return;
      setState(() {
        _paymentRoute = null;
        _paymentRouteLoading = false;
        _paymentRouteError = null;
        _paymentRouteMessage = null;
      });
      return;
    }
    if (!ConnectivityService.isOnline) {
      if (!mounted || lookupKey != _paymentRouteLookupKey) return;
      setState(() {
        _paymentRouteLoading = false;
        _paymentRouteError = null;
        _paymentRouteMessage = context.afriL10n.shopConnectPaymentAvailability;
      });
      return;
    }

    setState(() {
      _paymentRouteLoading = true;
      _paymentRouteError = null;
      _paymentRouteMessage = null;
    });

    try {
      final loader =
          widget.paymentRouteLoader ??
          ref.read(clubRepositoryProvider).findActivePaymentRoute;
      final route = await loader(user.clubId);

      if (!mounted || lookupKey != _paymentRouteLookupKey) return;
      setState(() {
        _paymentRoute = route;
        _paymentRouteError = null;
        _paymentRouteMessage = route == null
            ? context.afriL10n.shopPaymentSetupPending
            : null;
      });
    } catch (_) {
      AfriLogger.warn(
        'CartScreen',
        'Payment availability could not be checked.',
      );
      if (!mounted || lookupKey != _paymentRouteLookupKey) return;
      setState(() {
        _paymentRoute = null;
        _paymentRouteMessage = null;
        _paymentRouteError = context.afriL10n.shopPaymentCheckError;
      });
    } finally {
      if (mounted && lookupKey == _paymentRouteLookupKey) {
        setState(() => _paymentRouteLoading = false);
      }
    }
  }

  Future<void> _checkout(List<CartItem> items, int total) async {
    if (_submitting) return;
    if (!ref
        .read(storeReleasePolicyProvider)
        .allowsUnreconciledExternalPaymentLaunch) {
      AfriToast.error(context, context.afriL10n.shopCheckoutNotPermitted);
      return;
    }
    if (!ConnectivityService.isOnline) {
      AfriToast.error(context, context.afriL10n.shopConnectBeforeCheckout);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/onboarding');
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      final message = context.afriL10n.shopAddressRequired;
      setState(() => _addressError = message);
      _addressFocusNode.requestFocus();
      AfriToast.info(context, message);
      return;
    }

    setState(() {
      _submitting = true;
      _addressError = null;
      _checkoutFailure = null;
    });

    try {
      final repository = widget.orderPlacer == null || _paymentRoute == null
          ? ref.read(clubRepositoryProvider)
          : null;
      final route =
          _paymentRoute ??
          await repository!.findActivePaymentRoute(user.clubId);
      if (route == null) {
        if (!mounted) return;
        setState(() {
          _paymentRouteMessage = context.afriL10n.shopPaymentSetupPending;
        });
        AfriToast.error(context, context.afriL10n.shopMomoSetupPending);
        return;
      }

      final confirmed = await _showCheckoutConfirmSheet(
        items: items,
        total: total,
      );

      if (!confirmed || !mounted) return;

      final paymentReference = 'order-${DateTime.now().millisecondsSinceEpoch}';
      final orderPlacer = widget.orderPlacer ?? repository!.placeOrder;
      final orderId = await orderPlacer(
        userId: user.id,
        partnerId: user.clubId,
        items: items,
        deliveryAddress: _addressController.text.trim(),
        paymentReference: paymentReference,
      ).timeout(widget.checkoutTimeout);

      ref.read(shopCartProvider.notifier).clear();

      if (!mounted) return;

      final launched = await MomoDialerService.launchMomoUssd(
        recipient: route.recipientCode,
        amount: total,
        country: route.country,
        recipientType: PaymentRecipientType.code,
      );

      if (!mounted) return;

      if (!launched) {
        AfriToast.error(
          context,
          context.afriL10n.shopOrderDialerFailure(orderId),
        );
        context.go('/shop');
        return;
      }

      AfriToast.success(context, context.afriL10n.shopOrderCreated(orderId));
      context.go('/shop');
    } catch (error) {
      final failure = _CartCheckoutFailure.fromError(error, context.afriL10n);
      AfriLogger.warn(
        'CartScreen',
        'Checkout could not be completed (${failure.kind.name}).',
      );
      if (!mounted) return;
      setState(() {
        _checkoutFailure = failure;
      });
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
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.afriL10n.shopReviewOrder,
                style: TypographyTokens.headlineSmall(),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              AfriSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...items
                        .take(3)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: SpacingTokens.spacing3,
                            ),
                            child: _CartSummaryRow(
                              label: context.afriL10n.shopItemQuantitySummary(
                                item.product.name,
                                item.quantity,
                              ),
                              value: currency.format(item.lineTotal),
                              valueStyle: TypographyTokens.titleSmall(),
                            ),
                          ),
                        ),
                    if (items.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: SpacingTokens.spacing3,
                        ),
                        child: Text(
                          context.afriL10n.shopMoreItems(items.length - 3),
                          style: TypographyTokens.bodySmall(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      context.afriL10n.shopDeliverTo,
                      style: TypographyTokens.labelSmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      _addressController.text.trim(),
                      style: TypographyTokens.bodyMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    _CartSummaryRow(
                      label: context.afriL10n.shopTotal,
                      value: currency.format(total),
                      labelStyle: TypographyTokens.titleMedium(),
                      valueStyle: TypographyTokens.titleLarge(
                        ColorTokens.clubAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              Text(
                context.afriL10n.shopPaymentInstructions,
                style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              AfriButton(
                label: context.afriL10n.shopPaymentSubmitted,
                fullWidth: true,
                onTap: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriButton(
                label: context.afriL10n.shopBack,
                variant: AfriButtonVariant.outline,
                fullWidth: true,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final checkoutAllowed = ref.watch(
      storeReleasePolicyProvider.select(
        (policy) => policy.allowsUnreconciledExternalPaymentLaunch,
      ),
    );
    final config = ClubConfigScope.maybeOf(context);
    final currency = _currencyFormatter;
    final deliveryHint = config == null
        ? context.afriL10n.shopEnterDeliveryAddress
        : context.afriL10n.shopStreetCityCountry(config.country);
    final usesLargeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    if (checkoutAllowed) {
      _ensurePaymentRouteState(user);
    }

    final items = ref.watch(shopCartProvider);
    final total = ref.watch(shopCartTotalProvider);
    final paymentRouteBlocked =
        !checkoutAllowed ||
        (user != null &&
            (_paymentRouteLoading ||
                _paymentRouteError != null ||
                _paymentRouteMessage != null));
    final checkoutHardBlocked =
        _checkoutFailure?.kind == _CartCheckoutFailureKind.permissionDenied ||
        _checkoutFailure?.kind == _CartCheckoutFailureKind.securityTimeout;
    final cartChromeState =
        '${items.length}:$total:${!checkoutAllowed
            ? 'release_blocked'
            : _paymentRouteLoading
            ? 'loading'
            : _paymentRouteError != null
            ? 'error'
            : _paymentRouteMessage != null
            ? 'unavailable'
            : _paymentRoute != null
            ? 'ready'
            : 'idle'}';

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.shopCart,
          key: ValueKey<String>('cart-title-$cartChromeState'),
          style: usesLargeText
              ? TypographyTokens.titleLarge()
              : TypographyTokens.headlineSmall(),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.shopBack,
        ),
      ),
      scrollable: false,
      child: items.isEmpty
          ? Center(
              key: const ValueKey('cart-empty-state'),
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AfriIcons.cart,
                      size: 56,
                      color: ColorTokens.onSurfaceVariant,
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    Text(
                      context.afriL10n.shopCartEmptyTitle,
                      style: TypographyTokens.headlineSmall(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      context.afriL10n.shopCartEmptyMessage,
                      textAlign: TextAlign.center,
                      style: TypographyTokens.bodyMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing6),
                    AfriButton(
                      label: context.afriL10n.shopBackToShop,
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
                  AfriSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AfriSectionHeader(
                          title: context.afriL10n.shopDelivery,
                          subtitle: context.afriL10n.shopAddressAndTotal,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        AfriInputField(
                          controller: _addressController,
                          focusNode: _addressFocusNode,
                          minLines: 1,
                          maxLines: 2,
                          hint: context.afriL10n.shopDeliveryAddress,
                          helperText: deliveryHint,
                          helperMaxLines: 2,
                          errorText: _addressError,
                          autofillHints: const <String>[
                            AutofillHints.fullStreetAddress,
                          ],
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            if (_addressError != null ||
                                (_checkoutFailure != null &&
                                    !checkoutHardBlocked)) {
                              setState(() {
                                _addressError = null;
                                if (!checkoutHardBlocked) {
                                  _checkoutFailure = null;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: SpacingTokens.spacing6),
                        _CartSummaryRow(
                          label: context.afriL10n.shopSubtotal,
                          value: currency.format(total),
                          labelStyle: TypographyTokens.bodyMedium(
                            ColorTokens.onSurfaceVariant,
                          ),
                          valueStyle: TypographyTokens.titleSmall(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        _CartSummaryRow(
                          label: context.afriL10n.shopDelivery,
                          value: currency.format(0),
                          labelStyle: TypographyTokens.bodyMedium(
                            ColorTokens.onSurfaceVariant,
                          ),
                          valueStyle: TypographyTokens.titleSmall(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        _CartSummaryRow(
                          label: context.afriL10n.shopTotal,
                          value: currency.format(total),
                          labelStyle: TypographyTokens.titleMedium(),
                          valueStyle: TypographyTokens.titleLarge(
                            ColorTokens.clubAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_paymentRouteLoading) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriStateView.loading(
                      title: context.afriL10n.shopCheckingPayment,
                      message: context.afriL10n.shopCheckingPaymentMessage,
                      compact: true,
                    ),
                  ] else if (_paymentRouteError != null) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriStateView.error(
                      title: context.afriL10n.shopPaymentCheckFailed,
                      message: _paymentRouteError!,
                      actionLabel: context.afriL10n.shopRetry,
                      onAction: () => _refreshPaymentRouteState(user),
                      compact: true,
                    ),
                  ] else if (_paymentRouteMessage != null) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriStateView.offline(
                      title: context.afriL10n.shopCheckoutUnavailable,
                      message: _paymentRouteMessage!,
                      compact: true,
                    ),
                  ] else if (_paymentRoute != null) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriSurfaceCard(
                      child: Row(
                        children: [
                          Icon(
                            AfriIcons.verified,
                            color: ColorTokens.success,
                            size: 20,
                          ),
                          const SizedBox(width: SpacingTokens.spacing3),
                          Expanded(
                            child: Text(
                              context.afriL10n.shopPayTo(
                                _paymentRoute!.payToLabel,
                              ),
                              style: TypographyTokens.bodySmall(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_checkoutFailure case final failure?) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriStateView.error(
                      key: const ValueKey<String>('cart-checkout-failure'),
                      title: failure.title,
                      message: failure.message,
                      actionLabel: failure.canDismiss
                          ? context.afriL10n.shopReviewCart
                          : null,
                      onAction: failure.canDismiss
                          ? () => setState(() => _checkoutFailure = null)
                          : null,
                      compact: true,
                    ),
                  ],
                  const SizedBox(height: SpacingTokens.spacing8),
                  ConnectivityBuilder(
                    builder: (context, isOnline) => AfriButton(
                      label: !isOnline
                          ? context.afriL10n.shopConnectionRequired
                          : !checkoutAllowed
                          ? context.afriL10n.shopCheckoutNotPermitted
                          : _paymentRouteLoading
                          ? context.afriL10n.shopCheckingPayment
                          : _paymentRouteError != null
                          ? context.afriL10n.shopPaymentCheckFailed
                          : paymentRouteBlocked
                          ? context.afriL10n.shopPaymentRouteNotReady
                          : _checkoutFailure?.kind ==
                                _CartCheckoutFailureKind.permissionDenied
                          ? context.afriL10n.shopCheckoutNotPermitted
                          : _checkoutFailure?.kind ==
                                _CartCheckoutFailureKind.securityTimeout
                          ? context.afriL10n.shopStatusUncertain
                          : _submitting
                          ? context.afriL10n.shopProcessing
                          : usesLargeText
                          ? context.afriL10n.shopPayWithMomo
                          : context.afriL10n.shopCheckoutViaMomo,
                      fullWidth: true,
                      isLoading: _submitting,
                      onTap: () => _checkout(items, total),
                      enabled:
                          isOnline &&
                          checkoutAllowed &&
                          !_submitting &&
                          !paymentRouteBlocked &&
                          !checkoutHardBlocked,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing10),
                ],
              ),
            ),
    );
  }
}

enum _CartCheckoutFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class _CartCheckoutFailure {
  const _CartCheckoutFailure({
    required this.kind,
    required this.title,
    required this.message,
    required this.canDismiss,
  });

  final _CartCheckoutFailureKind kind;
  final String title;
  final String message;
  final bool canDismiss;

  factory _CartCheckoutFailure.fromError(Object error, AfriLocalizations l10n) {
    if (error is TimeoutException) {
      return _CartCheckoutFailure(
        kind: _CartCheckoutFailureKind.securityTimeout,
        title: l10n.shopOrderUncertainTitle,
        message: l10n.shopOrderUncertainMessage,
        canDismiss: false,
      );
    }
    if (error is OrderConflictException) {
      return _CartCheckoutFailure(
        kind: _CartCheckoutFailureKind.conflict,
        title: l10n.shopOrderChangedTitle,
        message: l10n.shopOrderChangedMessage,
        canDismiss: true,
      );
    }

    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission denied') ||
        normalized.contains('row-level security') ||
        normalized.contains('not authorized') ||
        normalized.contains('unauthorized') ||
        normalized.contains('forbidden')) {
      return _CartCheckoutFailure(
        kind: _CartCheckoutFailureKind.permissionDenied,
        title: l10n.shopCheckoutNotPermitted,
        message: l10n.shopCheckoutDeniedMessage,
        canDismiss: false,
      );
    }

    return _CartCheckoutFailure(
      kind: _CartCheckoutFailureKind.unknown,
      title: l10n.shopCheckoutFailureTitle,
      message: l10n.shopCheckoutFailureMessage,
      canDismiss: true,
    );
  }
}

class _CartSummaryRow extends StatelessWidget {
  const _CartSummaryRow({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: SpacingTokens.spacing3),
        Flexible(
          child: Text(value, textAlign: TextAlign.end, style: valueStyle),
        ),
      ],
    );
  }
}
