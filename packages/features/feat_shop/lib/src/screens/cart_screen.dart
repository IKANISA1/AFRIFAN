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
import '../shop_checkout_recovery.dart';
import '../widgets/cart_item_card.dart';
import '../widgets/shop_product_image.dart';

typedef CartPaymentRouteLoader =
    Future<PartnerPaymentRoute?> Function(String clubId);

typedef CartOrderPlacer = ShopOrderPlacer;

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({
    super.key,
    this.paymentRouteLoader,
    this.orderPlacer,
    this.orderRecoverer,
    this.paymentValidator,
    this.dialerLauncher,
    this.paymentReferenceFactory,
    this.checkoutTimeout = const Duration(seconds: 30),
  });

  final CartPaymentRouteLoader? paymentRouteLoader;
  final CartOrderPlacer? orderPlacer;
  final ShopOrderRecoverer? orderRecoverer;
  final Future<ShopCheckoutReceipt> Function(ShopCheckoutReceipt)?
  paymentValidator;
  final Future<bool> Function(String)? dialerLauncher;
  final String Function()? paymentReferenceFactory;
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
  ShopCheckoutFlow? _flow;
  bool _restoringCheckout = false;
  bool _missingOrder = false;
  String? _recoveryError;
  String? _paymentOutcome;
  BuildContext? _checkoutSheetContext;

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
    final sheet = _checkoutSheetContext;
    if (sheet != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sheet.mounted) Navigator.of(sheet).pop(false);
      });
    }
    _addressController.clear();
    _paymentRoute = null;
    _paymentRouteError = null;
    _paymentRouteMessage = null;
    _flow = null;
    _recoveryError = null;
    _paymentOutcome = null;
    _missingOrder = false;
    _restoringCheckout = user != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _paymentRouteLookupKey != lookupKey) return;
      if (ref
          .read(storeReleasePolicyProvider)
          .allowsUnreconciledExternalPaymentLaunch) {
        unawaited(_refreshPaymentRouteState(user));
      }
      unawaited(_restoreCheckout(user, lookupKey));
    });
  }

  Future<void> _restoreCheckout(UserProfile? user, String key) async {
    if (user == null || !mounted || _paymentRouteLookupKey != key) return;
    bool current() {
      if (!mounted) return false;
      final actor = ref.read(currentUserProvider);
      return mounted &&
          _paymentRouteLookupKey == key &&
          actor?.id == user.id &&
          actor?.clubId == user.clubId;
    }

    final flow = ShopCheckoutFlow(
      userId: user.id,
      clubId: user.clubId,
      journal: ref.read(shopCheckoutJournalProvider),
      timeout: widget.checkoutTimeout,
      referenceFactory:
          widget.paymentReferenceFactory ?? newShopPaymentReference,
      place:
          widget.orderPlacer ??
          ({
            required userId,
            required partnerId,
            required items,
            required deliveryAddress,
            required paymentReference,
          }) => ref
              .read(clubRepositoryProvider)
              .placeShopOrder(
                userId: userId,
                partnerId: partnerId,
                items: items,
                deliveryAddress: deliveryAddress,
                paymentReference: paymentReference,
              ),
      recover:
          widget.orderRecoverer ??
          ({required userId, required clubId, required paymentReference}) => ref
              .read(clubRepositoryProvider)
              .recoverShopOrder(
                userId: userId,
                clubId: clubId,
                paymentReference: paymentReference,
              ),
      validate:
          widget.paymentValidator ??
          (receipt) =>
              ref.read(clubRepositoryProvider).validateShopPayment(receipt),
      launch: (ussd) async {
        if (!current() ||
            !ConnectivityService.isOnline ||
            !ref
                .read(storeReleasePolicyProvider)
                .allowsUnreconciledExternalPaymentLaunch) {
          throw StateError('SHOP_PAYMENT_UNAVAILABLE');
        }
        return (widget.dialerLauncher ?? MomoDialerService.launchPreparedUssd)(
          ussd,
        );
      },
      isCurrent: current,
    );
    try {
      await flow.restore();
      if (!current()) return;
      _flow = flow;
      if (flow.attempt != null) {
        _addressController.text = flow.attempt!.address;
        if (ConnectivityService.isOnline) {
          _missingOrder = await flow.check() == null;
        }
      }
      if (!current()) return;
      setState(() {
        _restoringCheckout = false;
        _recoveryError = null;
      });
    } catch (_) {
      if (!current()) return;
      setState(() {
        _flow = flow;
        _restoringCheckout = false;
        _recoveryError = context.afriL10n.shopRecoveryCheckFailed;
      });
    }
  }

  Future<void> _checkOriginal({bool retry = false}) async {
    final flow = _flow;
    if (flow == null || _submitting || !ConnectivityService.isOnline) return;
    setState(() {
      _submitting = true;
      _recoveryError = null;
    });
    try {
      if (retry) {
        await flow.retryOriginal();
        _missingOrder = false;
      } else {
        _missingOrder = await flow.check() == null;
      }
      if (!mounted || !identical(_flow, flow)) return;
      setState(() => _checkoutFailure = null);
    } catch (_) {
      if (!mounted || !identical(_flow, flow)) return;
      setState(
        () => _recoveryError = context.afriL10n.shopOriginalResultUnavailable,
      );
    } finally {
      if (mounted && identical(_flow, flow)) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _reviewPreparedPayment() async {
    final flow = _flow;
    final review = flow?.receipt;
    if (flow == null ||
        review == null ||
        _submitting ||
        flow.attempt?.handoffStarted == true ||
        !ref
            .read(storeReleasePolicyProvider)
            .allowsUnreconciledExternalPaymentLaunch) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final catalogTotal = flow.attempt!.items.fold<int>(
        0,
        (sum, item) => sum + item.lineTotal,
      );
      final changed =
          catalogTotal != review.total ||
          review.currency != context.afriCurrencyCode;
      var acknowledged = !changed;
      final currency = CurrencyFormatter(
        currencyCode: review.currency,
        currencySymbol: review.currency,
      );
      final confirmed = await showAfriBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          _checkoutSheetContext = sheetContext;
          return StatefulBuilder(
            builder: (context, update) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.afriL10n.shopReviewPayment,
                    style: TypographyTokens.headlineMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in review.order.items) ...[
                          Text(
                            context.afriL10n.shopItemQuantitySummary(
                              item.product.name,
                              item.quantity,
                            ),
                            style: TypographyTokens.titleMedium(),
                          ),
                          Text(
                            currency.format(item.lineTotal),
                            style: TypographyTokens.bodyLarge(),
                          ),
                          if (item.selectedVariant != null)
                            Text(
                              item.selectedVariant!,
                              style: TypographyTokens.bodyMedium(),
                            ),
                          const SizedBox(height: SpacingTokens.spacing3),
                        ],
                        Text(
                          currency.format(review.total),
                          style: TypographyTokens.headlineSmall(),
                        ),
                        Text(
                          context.afriL10n.shopReceiptCurrency(review.currency),
                          style: TypographyTokens.bodyMedium(),
                        ),
                        Text(
                          context.afriL10n.shopReceiptRecipient(
                            review.recipientCode,
                          ),
                          style: TypographyTokens.bodyMedium(),
                        ),
                        Text(
                          context.afriL10n.shopReceiptCountry(review.country),
                          style: TypographyTokens.bodyMedium(),
                        ),
                        Text(
                          context.afriL10n.shopReceiptInstruction(
                            review.ussdCode,
                          ),
                          style: TypographyTokens.bodyMedium(),
                        ),
                        Text(
                          context.afriL10n.shopReceiptExpiry(
                            review.expiresAt.toLocal().toString(),
                          ),
                          style: TypographyTokens.bodySmall(),
                        ),
                        Text(
                          review.order.deliveryAddress,
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  if (changed) ...[
                    Text(
                      context.afriL10n.shopCatalogPriceChanged(
                        _currencyFormatter.format(catalogTotal),
                        currency.format(review.total),
                      ),
                      style: TypographyTokens.bodyMedium(),
                    ),
                    AfriCheckbox(
                      value: acknowledged,
                      onChanged: (value) =>
                          update(() => acknowledged = value ?? false),
                      label: context.afriL10n.shopAcceptUpdatedAmount,
                    ),
                  ],
                  Text(
                    context.afriL10n.shopDialerBoundary,
                    style: TypographyTokens.bodySmall(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  AfriButton(
                    label: context.afriL10n.shopConfirmOpenMomo,
                    enabled: acknowledged && review.canPay,
                    onTap: () => Navigator.of(sheetContext).pop(true),
                    fullWidth: true,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriButton(
                    label: context.afriL10n.shopBack,
                    variant: AfriButtonVariant.outline,
                    onTap: () => Navigator.of(sheetContext).pop(false),
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          );
        },
      );
      _checkoutSheetContext = null;
      if (confirmed != true || !mounted || !identical(_flow, flow)) return;
      if (!ref
              .read(storeReleasePolicyProvider)
              .allowsUnreconciledExternalPaymentLaunch ||
          !ConnectivityService.isOnline) {
        throw StateError('SHOP_PAYMENT_UNAVAILABLE');
      }
      final launched = await flow.confirm(review);
      if (!mounted || !identical(_flow, flow)) return;
      ref.read(shopCartProvider.notifier).clear();
      setState(
        () => _paymentOutcome = launched
            ? context.afriL10n.shopPaymentOpenedPending
            : context.afriL10n.shopDialerResultUnknown,
      );
    } on ShopCheckoutReviewChanged {
      if (mounted && identical(_flow, flow)) {
        setState(
          () => _paymentOutcome = context.afriL10n.shopInstructionsChanged,
        );
      }
    } catch (_) {
      if (mounted && identical(_flow, flow)) {
        setState(
          () => _paymentOutcome = context.afriL10n.shopPaymentLaunchUnsafe,
        );
      }
    } finally {
      _checkoutSheetContext = null;
      if (mounted && identical(_flow, flow)) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _closeOriginal() async {
    final flow = _flow;
    if (flow == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await flow.closeTerminal();
      if (mounted && identical(_flow, flow)) {
        setState(() {
          _missingOrder = false;
          _paymentOutcome = null;
          _checkoutFailure = null;
        });
      }
    } catch (_) {
      if (mounted && identical(_flow, flow)) {
        setState(
          () => _recoveryError = context.afriL10n.shopRecoveryCheckFailed,
        );
      }
    } finally {
      if (mounted && identical(_flow, flow)) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _cancelPrepared() async {
    final flow = _flow;
    if (flow == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await flow.cancelUnpaid((receipt) async {
        await ref.read(clubRepositoryProvider).cancelOrder(receipt.order);
      });
      if (mounted && identical(_flow, flow)) {
        setState(() => _checkoutFailure = null);
      }
    } catch (_) {
      if (mounted && identical(_flow, flow)) {
        setState(
          () => _recoveryError = context.afriL10n.shopCancellationUncertain,
        );
      }
    } finally {
      if (mounted && identical(_flow, flow)) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _originalOrderView() {
    final flow = _flow!;
    final attempt = flow.attempt!;
    final receipt = flow.receipt;
    final online = ConnectivityService.isOnline;
    final currency = receipt == null
        ? null
        : CurrencyFormatter(
            currencyCode: receipt.currency,
            currencySymbol: receipt.currency,
          );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AfriSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt == null
                      ? context.afriL10n.shopOrderUncertainTitle
                      : receipt.pending
                      ? (attempt.handoffStarted
                            ? context.afriL10n.shopPaymentPending
                            : context.afriL10n.shopOrderPrepared)
                      : context.afriL10n.shopOriginalOrderStatus(
                          receipt.serverStatus,
                        ),
                  style: TypographyTokens.headlineSmall(),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: SizeTokens.touchTargetMin,
                  ),
                  child: SelectableText(
                    context.afriL10n.shopRequestReference(attempt.reference),
                    style: TypographyTokens.bodySmall(),
                  ),
                ),
                if (attempt.orderId != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: SizeTokens.touchTargetMin,
                    ),
                    child: SelectableText(
                      context.afriL10n.shopOrderReference(attempt.orderId!),
                      style: TypographyTokens.bodySmall(),
                    ),
                  ),
                if (receipt != null) ...[
                  Text(
                    currency!.format(receipt.total),
                    style: TypographyTokens.titleLarge(),
                  ),
                  Text(
                    context.afriL10n.shopReceiptRecipient(
                      receipt.recipientCode,
                    ),
                    style: TypographyTokens.bodyMedium(),
                  ),
                  Text(
                    context.afriL10n.shopReceiptCurrency(receipt.currency),
                    style: TypographyTokens.bodyMedium(),
                  ),
                ],
                Text(
                  receipt?.pending == false
                      ? context.afriL10n.shopAuthoritativeStatus
                      : context.afriL10n.shopPreparedIsNotPaid,
                  style: TypographyTokens.bodyMedium(),
                ),
                if (_paymentOutcome != null)
                  Text(_paymentOutcome!, style: TypographyTokens.bodyMedium()),
                if (_recoveryError != null)
                  Text(
                    _recoveryError!,
                    style: TypographyTokens.bodyMedium(ColorTokens.error),
                  ),
                if (_checkoutFailure != null) ...[
                  Text(
                    _checkoutFailure!.title,
                    style: TypographyTokens.titleMedium(),
                  ),
                  Text(
                    _checkoutFailure!.message,
                    style: TypographyTokens.bodyMedium(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          AfriButton(
            label: context.afriL10n.shopCheckOrderStatus,
            enabled: online && !_submitting,
            isLoading: _submitting,
            fullWidth: true,
            onTap: () => _checkOriginal(),
          ),
          if (_missingOrder && receipt == null && !attempt.handoffStarted) ...[
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              context.afriL10n.shopOriginalRequestMissing,
              style: TypographyTokens.bodySmall(),
            ),
            AfriButton(
              label: context.afriL10n.shopRetryOriginalRequest,
              enabled:
                  online &&
                  !_submitting &&
                  ref
                      .read(storeReleasePolicyProvider)
                      .allowsUnreconciledExternalPaymentLaunch,
              fullWidth: true,
              onTap: () => _checkOriginal(retry: true),
            ),
          ],
          if (receipt != null &&
              receipt.pending &&
              !attempt.handoffStarted) ...[
            const SizedBox(height: SpacingTokens.spacing3),
            if (!receipt.canPay)
              Text(
                context.afriL10n.shopOriginalRouteUnavailable,
                style: TypographyTokens.bodySmall(),
              ),
            AfriButton(
              label: context.afriL10n.shopReviewPayment,
              enabled:
                  online &&
                  !_submitting &&
                  receipt.canPay &&
                  attempt.orderId == receipt.id &&
                  ref
                      .read(storeReleasePolicyProvider)
                      .allowsUnreconciledExternalPaymentLaunch,
              fullWidth: true,
              onTap: _reviewPreparedPayment,
            ),
          ],
          if (receipt?.pending == true && !attempt.handoffStarted) ...[
            const SizedBox(height: SpacingTokens.spacing3),
            AfriButton(
              label: context.afriL10n.shopCancelUnpaidOrder,
              variant: AfriButtonVariant.outline,
              enabled: online && !_submitting,
              fullWidth: true,
              onTap: _cancelPrepared,
            ),
          ],
          if (receipt?.terminal == true) ...[
            const SizedBox(height: SpacingTokens.spacing3),
            AfriButton(
              label: context.afriL10n.shopReturnToCart,
              fullWidth: true,
              enabled: !_submitting,
              onTap: _closeOriginal,
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            label: context.afriL10n.shopSupportInSettings,
            variant: AfriButtonVariant.outline,
            fullWidth: true,
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
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
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/onboarding');
      return;
    }
    final flow = _flow;
    if (flow == null ||
        _restoringCheckout ||
        _recoveryError != null ||
        flow.attempt != null) {
      return;
    }
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

      await flow.begin(items, _addressController.text.trim());
      if (!mounted || !identical(_flow, flow)) return;
      setState(
        () => _paymentOutcome = context.afriL10n.shopPreparedReviewNeeded,
      );
    } catch (error) {
      final failure = _CartCheckoutFailure.fromError(error, context.afriL10n);
      AfriLogger.warn(
        'CartScreen',
        'Checkout could not be completed (${failure.kind.name}).',
      );
      if (!mounted || !identical(_flow, flow)) return;
      setState(() {
        _checkoutFailure = failure;
      });
    } finally {
      if (mounted && identical(_flow, flow)) {
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
        _checkoutSheetContext = context;
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.afriL10n.shopReviewOrder,
                style: TypographyTokens.headlineMedium(),
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
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (ShopProductImage.isPublished(
                                  item.product.imageUrl,
                                  item.product.imageRightsApproved,
                                  item.product.imageProvenanceId,
                                )) ...[
                                  ShopProductImage(
                                    url: item.product.imageUrl,
                                    name: item.product.name,
                                    rightsApproved:
                                        item.product.imageRightsApproved,
                                    provenanceId:
                                        item.product.imageProvenanceId,
                                    width: 56,
                                    height: 72,
                                  ),
                                  const SizedBox(width: SpacingTokens.spacing3),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.afriL10n
                                            .shopItemQuantitySummary(
                                              item.product.name,
                                              item.quantity,
                                            ),
                                        style: TypographyTokens.titleMedium(),
                                      ),
                                      if (item.selectedVariant?.isNotEmpty ??
                                          false)
                                        Text(
                                          item.selectedVariant!,
                                          style: TypographyTokens.bodyMedium(),
                                        ),
                                      const SizedBox(
                                        height: SpacingTokens.spacing2,
                                      ),
                                      Text(
                                        currency.format(item.lineTotal),
                                        style: TypographyTokens.bodyLarge(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                        ColorTokens.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              Text(
                context.afriL10n.shopPrepareExplanation,
                style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              AfriButton(
                label: context.afriL10n.shopPrepareOrder,
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
    _checkoutSheetContext = null;
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
    _ensurePaymentRouteState(user);

    final items = ref.watch(shopCartProvider);
    final total = ref.watch(shopCartTotalProvider);
    final paymentRouteBlocked =
        !checkoutAllowed ||
        (user != null &&
            (_paymentRouteLoading ||
                _paymentRouteError != null ||
                _paymentRouteMessage != null));
    final checkoutHardBlocked =
        _restoringCheckout ||
        _recoveryError != null ||
        _flow?.attempt != null ||
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
        actions: [
          AfriIconButton(
            icon: AfriIcons.history,
            tooltip: context.afriL10n.shopOrderHistory,
            onTap: () => context.push('/shop/orders'),
          ),
        ],
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.shopBack,
        ),
      ),
      scrollable: false,
      child: _flow?.attempt != null
          ? _originalOrderView()
          : items.isEmpty
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
                            ColorTokens.primaryContainer,
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
                  if (_recoveryError != null)
                    AfriStateView.error(
                      title: context.afriL10n.shopRecoveryUnavailableTitle,
                      message: _recoveryError!,
                      actionLabel: context.afriL10n.shopCheckRecovery,
                      onAction: () =>
                          _restoreCheckout(user, _paymentRouteLookupKey!),
                      compact: true,
                    ),
                  ConnectivityBuilder(
                    builder: (context, isOnline) => AfriButton(
                      label: !isOnline
                          ? context.afriL10n.shopConnectionRequired
                          : _restoringCheckout
                          ? context.afriL10n.shopCheckingRecovery
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
