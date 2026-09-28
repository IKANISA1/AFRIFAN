import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gikundiro_public_shop.dart';
import '../shop_cart_provider.dart';
import '../widgets/shop_product_image.dart';

typedef ProductDetailLoader =
    Future<Map<String, dynamic>?> Function(String productId);

enum ProductDetailFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class ProductDetailFailure implements Exception {
  const ProductDetailFailure(this.kind);

  final ProductDetailFailureKind kind;

  static ProductDetailFailure fromError(Object error) {
    if (error is ProductDetailFailure) return error;
    if (error is TimeoutException) {
      return const ProductDetailFailure(
        ProductDetailFailureKind.securityTimeout,
      );
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const ProductDetailFailure(
        ProductDetailFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const ProductDetailFailure(ProductDetailFailureKind.conflict);
    }
    return const ProductDetailFailure(ProductDetailFailureKind.unknown);
  }

  @override
  String toString() => 'ProductDetailFailure(${kind.name})';
}

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.productLoader,
    this.loadTimeout = const Duration(seconds: 12),
    this.autofocusSize,
  });

  final String productId;
  final ProductDetailLoader? productLoader;
  final Duration loadTimeout;
  final String? autofocusSize;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  static const _productsTable = 'shop_products';
  static const _productProjection =
      'id, partner_id, club_id, name, subtitle, description, category, '
      'price, stock, is_active, is_new, image_url, sizes, available_sizes, '
      'badge_label, collection, sort_order, product_id, product_type, '
      'currency, image_rights_approved, image_provenance_id, commerce_mode, enquiry_phone';

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isStale = false;
  Map<String, dynamic>? _product;
  ProductDetailFailure? _failure;
  bool _isOffline = false;
  bool _isNotFound = false;
  late bool _wasOnline;

  String? _selectedSize;
  int _quantity = 1;

  CurrencyFormatter _currencyFormatter(BuildContext context) =>
      CurrencyFormatter(
        currencyCode: context.afriCurrencyCode,
        currencySymbol: context.afriCurrencySymbol,
      );

  List<String> _availableSizes(Map<String, dynamic>? product) {
    return switch (product?['available_sizes'] ?? product?['sizes']) {
      final List<dynamic> values =>
        values
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
      final String value when value.trim().isNotEmpty =>
        value
            .split(',')
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false),
      _ => const <String>[],
    };
  }

  int? _stockCount(Map<String, dynamic>? product) {
    final rawValue = product?['stock'] ?? product?['inventory_count'];
    return switch (rawValue) {
      final num value => value.toInt(),
      final String value => int.tryParse(value.trim()),
      _ => null,
    };
  }

  bool _isInStock(Map<String, dynamic>? product) {
    final stockCount = _stockCount(product);
    final flaggedInStock = product?['in_stock'] as bool? ?? true;
    if (stockCount != null) {
      return flaggedInStock && stockCount > 0;
    }
    return flaggedInStock;
  }

  int _maxQuantityFor(Map<String, dynamic>? product) {
    final stockCount = _stockCount(product);
    if (stockCount != null) {
      return stockCount.clamp(0, 99);
    }
    return _isInStock(product) ? 10 : 0;
  }

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
    unawaited(_loadProduct());
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    super.dispose();
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;
    if (!mounted) return;
    if (!isOnline && _product != null) {
      setState(() => _isStale = true);
    } else if (restored && (_isOffline || _isStale)) {
      unawaited(_loadProduct());
    }
  }

  Future<void> _loadProduct() async {
    if (!ConnectivityService.isOnline) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isStale = _product != null;
        _isOffline = true;
        _isNotFound = false;
        _failure = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isRefreshing = _product != null;
        if (_product == null) {
          _isLoading = true;
        }
        _isOffline = false;
        _isNotFound = false;
        _failure = null;
      });
    }

    try {
      final request = widget.productLoader == null
          ? _fetchProduct()
          : widget.productLoader!(widget.productId);
      final response = await request.timeout(widget.loadTimeout);

      if (!mounted) return;

      if (response == null) {
        setState(() {
          if (_product != null) {
            _isLoading = false;
            _isRefreshing = false;
            _isStale = true;
            _isOffline = !ConnectivityService.isOnline;
            _isNotFound = false;
            _failure = null;
          } else {
            _product = null;
            _isNotFound = true;
            _isOffline = false;
            _isRefreshing = false;
            _isStale = false;
            _failure = null;
            _isLoading = false;
          }
        });
        return;
      }

      setState(() {
        final product = Map<String, dynamic>.from(response);
        final sizes = _availableSizes(product);
        _product = product;
        _selectedSize = sizes.isEmpty
            ? null
            : (sizes.contains(_selectedSize) ? _selectedSize : sizes.first);
        final maxQuantity = _maxQuantityFor(product);
        _quantity = maxQuantity > 0 ? _quantity.clamp(1, maxQuantity) : 1;
        _isLoading = false;
        _isRefreshing = false;
        _isStale = false;
        _isOffline = false;
        _isNotFound = false;
        _failure = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ProductDetailScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (mounted) {
        setState(() {
          if (_product != null) {
            _isLoading = false;
            _isRefreshing = false;
            _isStale = true;
            _isOffline = !ConnectivityService.isOnline;
            _isNotFound = false;
            _failure = null;
          } else {
            _product = null;
            _isOffline = !ConnectivityService.isOnline;
            _isNotFound = false;
            _isRefreshing = false;
            _isStale = false;
            _failure = _isOffline
                ? null
                : ProductDetailFailure.fromError(error);
            _isLoading = false;
          }
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchProduct() async {
    final publicSource = ref.read(gikundiroPublicClientProvider);
    if (publicSource != null && widget.productId.startsWith('gikundiro-')) {
      final products = await loadGikundiroPublicShop(publicSource);
      for (final product in products) {
        if (product['id'] == widget.productId) return product;
      }
      return null;
    }
    final client = ref.read(supabaseClientProvider);
    final user = ref.read(currentUserProvider);
    final resolver = ClubScopeResolver(client: client);
    final scope = await resolver.requireResolved(user?.clubId);
    var query = client
        .from(_productsTable)
        .select(_productProjection)
        .eq('id', widget.productId);
    query = resolver.apply(query, scope);
    final response = await query.maybeSingle();
    return response == null ? null : Map<String, dynamic>.from(response);
  }

  void _increment() {
    final maxQuantity = _maxQuantityFor(_product);
    if (_quantity < maxQuantity) {
      setState(() => _quantity++);
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() => _quantity--);
      unawaited(HapticFeedback.lightImpact());
    }
  }

  bool _addToCart() {
    final product = _product;
    final user = ref.read(currentUserProvider);

    if (product == null ||
        product['commerce_mode'] == 'enquiry' ||
        _isStale ||
        _isRefreshing ||
        _isOffline) {
      return false;
    }

    if (user == null) {
      context.go(
        Uri(
          path: '/auth/phone',
          queryParameters: {'from': '/shop/product/${widget.productId}'},
        ).toString(),
      );
      return false;
    }

    if (!_isInStock(product)) {
      AfriToast.error(context, context.afriL10n.shopItemOutOfStockToast);
      return false;
    }

    final sizes = _availableSizes(product);
    if (sizes.isNotEmpty &&
        (_selectedSize == null || !sizes.contains(_selectedSize))) {
      AfriToast.info(context, context.afriL10n.shopSelectSizeToast);
      return false;
    }

    final quantity = _quantity
        .clamp(1, math.max(1, _maxQuantityFor(product)))
        .toInt();

    ref
        .read(shopCartProvider.notifier)
        .addRawProduct(
          product,
          partnerId: user.clubId,
          fallbackName: context.afriL10n.shopProductFallback,
          selectedVariant: sizes.isEmpty ? null : _selectedSize,
          quantity: quantity,
        );

    AfriToast.success(
      context,
      context.afriL10n.shopProductAdded(
        product['name']?.toString() ?? context.afriL10n.shopProductFallback,
      ),
      actionLabel: context.afriL10n.shopViewCartAction,
      onAction: () => context.push('/shop/cart'),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    if (_isNotFound && !_isLoading) {
      return _buildStateScreen(
        AfriStateView.empty(
          title: l10n.shopProductNotFoundTitle,
          message: l10n.shopProductNotFoundMessage,
          actionLabel: l10n.shopBackToStore,
          onAction: _returnToShop,
        ),
      );
    }

    if (_isOffline && !_isLoading) {
      return _buildStateScreen(
        AfriStateView.offline(
          title: l10n.shopProductOfflineTitle,
          message: l10n.shopProductOfflineMessage,
          actionLabel: l10n.shopBackToStore,
          onAction: _returnToShop,
        ),
      );
    }

    if (_failure != null && !_isLoading) {
      final failure = _failure!;
      final title = switch (failure.kind) {
        ProductDetailFailureKind.permissionDenied =>
          l10n.shopProductAccessTitle,
        ProductDetailFailureKind.conflict => l10n.shopProductChangedTitle,
        ProductDetailFailureKind.securityTimeout =>
          l10n.shopProductSecurityTitle,
        ProductDetailFailureKind.unknown => l10n.shopProductUnavailableTitle,
      };
      final message = switch (failure.kind) {
        ProductDetailFailureKind.permissionDenied =>
          l10n.shopProductAccessMessage,
        ProductDetailFailureKind.conflict => l10n.shopProductChangedMessage,
        ProductDetailFailureKind.securityTimeout =>
          l10n.shopProductSecurityMessage,
        ProductDetailFailureKind.unknown => l10n.shopProductUnavailableMessage,
      };
      final canRetry =
          failure.kind != ProductDetailFailureKind.permissionDenied;
      return _buildStateScreen(
        AfriStateView.error(
          title: title,
          message: message,
          actionLabel: canRetry ? l10n.shopRefresh : null,
          onAction: canRetry ? () => unawaited(_loadProduct()) : null,
        ),
      );
    }

    final isSkeleton = _isLoading && _product == null;
    final product =
        _product ??
        {
          'name': l10n.shopLoadingProductName,
          'price': 25000,
          'description': l10n.shopLoadingProductDescription,
          'image_url': '',
          'badge_label': l10n.shopLoadingBadge,
          'sizes': ['S', 'M', 'L', 'XL'],
          'in_stock': true,
        };

    final name = product['name']?.toString() ?? l10n.shopProductFallback;
    final price = (product['price'] as num?)?.toInt() ?? 0;
    final currency = _currencyFormatter(context);
    final total = price * _quantity;
    final description =
        product['description']?.toString() ?? l10n.shopOfficialMerchandise;
    final imageUrl = product['image_url']?.toString();
    final imageProvenanceId =
        product['image_provenance_id']?.toString().trim() ?? '';
    final imageRightsApproved =
        product['image_rights_approved'] == true &&
        imageProvenanceId.isNotEmpty;
    final hasApprovedImage = ShopProductImage.isPublished(
      imageUrl,
      imageRightsApproved,
      imageProvenanceId,
    );
    final badge = product['badge_label']?.toString();
    final primary = ColorTokens.primaryContainer;
    final sizes = _availableSizes(product);
    final inStock = _isInStock(product);
    final stockCount = _stockCount(product);
    final maxQuantity = _maxQuantityFor(product);
    final usesLargeTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    if (isSkeleton) {
      return AfriScreenScaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          backgroundColor: ColorTokens.transparent,
          elevation: 0,
          leading: AfriIconButton(
            icon: AfriIcons.close,
            onTap: _returnToShop,
            tooltip: l10n.shopCloseProductDetails,
          ),
        ),
        scrollable: false,
        child: const AfriSkeletonList(),
      );
    }

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                AfriSliverAppBar(
                  expandedHeight: hasApprovedImage
                      ? (MediaQuery.sizeOf(context).width *
                            (usesLargeTextLayout ? 0.8 : 1.1))
                      : SizeTokens.buttonMinHeight,
                  pinned: true,
                  backgroundColor: ColorTokens.background,
                  leading: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.spacing1),
                    child: AfriIconButton(
                      icon: AfriIcons.back,
                      filled: true,
                      tooltip: l10n.shopBack,
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/shop');
                        }
                      },
                    ),
                  ),
                  flexibleSpace: hasApprovedImage
                      ? FlexibleSpaceBar(
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (hasApprovedImage && imageUrl != null)
                                AfriGovernedCachedImage(
                                  imageUrl: imageUrl,
                                  semanticLabel: l10n.shopProductImageSemantic(
                                    name,
                                  ),
                                  provenanceId: imageProvenanceId.isEmpty
                                      ? 'shop:${widget.productId}:unapproved'
                                      : imageProvenanceId,
                                  rightsApproved: imageRightsApproved,
                                  fit: BoxFit.cover,
                                  borderRadius: ShapeTokens.radiusNone,
                                  placeholder: Container(
                                    color: ColorTokens.surfaceContainerLow,
                                  ),
                                  errorFallback: const _ImageFallback(),
                                )
                              else
                                const _ImageFallback(),
                              if (hasApprovedImage)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: 120,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: ColorTokens.imageScrimGradient(
                                        color: ColorTokens.background,
                                      ),
                                    ),
                                  ),
                                ),
                              if (badge != null && badge.isNotEmpty)
                                Positioned(
                                  left: SpacingTokens.spacing6,
                                  bottom: SpacingTokens.spacing4,
                                  child: AfriStatusChip(
                                    label: badge,
                                    tone: AfriStatusTone.live,
                                  ),
                                ).afriAnimate(context).fadeIn(duration: 400.ms),
                            ],
                          ),
                        )
                      : null,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isRefreshing || _isStale) ...[
                          AfriStateBanner(
                            icon: _isRefreshing
                                ? AfriIcons.refresh
                                : AfriIcons.statusWarning,
                            title: _isRefreshing
                                ? l10n.shopRefreshingProductTitle
                                : l10n.shopSavedProductTitle,
                            subtitle: _isRefreshing
                                ? l10n.shopRefreshingProductMessage
                                : l10n.shopSavedProductMessage,
                            tone: _isRefreshing
                                ? AfriStateBannerTone.info
                                : AfriStateBannerTone.warning,
                          ),
                          const SizedBox(height: SpacingTokens.spacing5),
                        ],
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TypographyTokens.headlineMedium(),
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              currency.format(price),
                              style: TypographyTokens.headlineSmall(),
                            ),
                          ],
                        ).afriAnimate(context).fadeIn(duration: 400.ms),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Text(
                              description,
                              style: TypographyTokens.bodyLarge().copyWith(
                                color: ColorTokens.onSurfaceVariant,
                                height: 1.5,
                              ),
                            )
                            .afriAnimate(context)
                            .fadeIn(delay: 100.ms, duration: 400.ms),
                        const SizedBox(height: SpacingTokens.spacing6),
                        AfriStatusChip(
                          label: inStock
                              ? (stockCount != null
                                    ? l10n.shopStockAvailable(stockCount)
                                    : l10n.shopInStock)
                              : l10n.shopOutOfStock,
                          tone: inStock
                              ? AfriStatusTone.success
                              : AfriStatusTone.error,
                        ),
                        const SizedBox(height: SpacingTokens.spacing8),
                        if (sizes.isNotEmpty) ...[
                          AfriSectionHeader(
                            title: l10n.shopSelectSize,
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          Wrap(
                            spacing: SpacingTokens.spacing3,
                            runSpacing: SpacingTokens.spacing3,
                            children: sizes.map((size) {
                              final selected = size == _selectedSize;
                              return AfriPressFeedback(
                                key: ValueKey<String>(
                                  'product-detail-size-$size',
                                ),
                                onTap: () {
                                  setState(() => _selectedSize = size);
                                },
                                autofocus: widget.autofocusSize == size,
                                selected: selected,
                                tooltip: l10n.shopSizeTooltip(size),
                                semanticsLabel: l10n.shopSizeTooltip(size),
                                semanticsHint: selected
                                    ? l10n.shopSizeSelectedHint
                                    : l10n.shopSizeAvailableHint,
                                excludeChildSemantics: true,
                                builder: (context, state) {
                                  return AnimatedContainer(
                                    duration: AfriMotion.resolve(
                                      context,
                                      AfriMotion.standard,
                                    ),
                                    constraints: const BoxConstraints(
                                      minHeight: SpacingTokens.spacing12,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: SpacingTokens.spacing5,
                                      vertical: SpacingTokens.spacing3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? primary
                                          : ColorTokens.surfaceContainerLow,
                                      borderRadius: ShapeTokens.buttonRadius,
                                      border: state.isFocused
                                          ? BorderTokens.focusAll(width: 3)
                                          : BorderTokens.ghost(),
                                    ),
                                    child: Text(
                                      size,
                                      style: TypographyTokens.labelMedium(
                                        selected
                                            ? ColorTokens.onDark
                                            : ColorTokens.onSurface,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing6),
                        ],
                        _buildQuantitySelector(
                          usesLargeTextLayout: usesLargeTextLayout,
                          maxQuantity: maxQuantity,
                        ),
                        const SizedBox(height: SpacingTokens.spacing6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing6,
                      vertical: SpacingTokens.spacing6,
                    ),
                    decoration: BoxDecoration(
                      color: ColorTokens.glassFill,
                      border: BorderTokens.top(),
                    ),
                    child: SafeArea(
                      top: false,
                      child: _buildPurchaseActions(
                        currency: currency,
                        total: total,
                        inStock: inStock,
                        usesLargeTextLayout: usesLargeTextLayout,
                      ),
                    ),
                  ),
                ),
              )
              .afriAnimate(context)
              .slideY(
                begin: 1,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOut,
              ),
        ],
      ),
    );
  }

  Widget _buildStateScreen(Widget state) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.close,
          onTap: _returnToShop,
          tooltip: context.afriL10n.shopCloseProductDetails,
        ),
      ),
      scrollable: false,
      child: Center(child: state),
    );
  }

  void _returnToShop() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/shop');
    }
  }

  Widget _buildQuantitySelector({
    required bool usesLargeTextLayout,
    required int maxQuantity,
  }) {
    final controls = Container(
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: ShapeTokens.buttonRadius,
        border: BorderTokens.ghost(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AfriIconButton(
            icon: AfriIcons.remove,
            onTap: _quantity > 1 ? _decrement : null,
            tooltip: context.afriL10n.shopDecreaseQuantity,
          ),
          SizedBox(
            width: SpacingTokens.spacing10,
            child: Center(
              child: Text('$_quantity', style: TypographyTokens.titleMedium()),
            ),
          ),
          AfriIconButton(
            icon: AfriIcons.add,
            onTap: _quantity < maxQuantity ? _increment : null,
            tooltip: context.afriL10n.shopIncreaseQuantity,
          ),
        ],
      ),
    );

    if (usesLargeTextLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AfriSectionHeader(
            title: context.afriL10n.shopQuantity,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          controls,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: AfriSectionHeader(
            title: context.afriL10n.shopQuantity,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing4),
        controls,
      ],
    );
  }

  Widget _buildPurchaseActions({
    required CurrencyFormatter currency,
    required int total,
    required bool inStock,
    required bool usesLargeTextLayout,
  }) {
    if (_product?['commerce_mode'] == 'enquiry') {
      final phone = _product?['enquiry_phone']?.toString() ?? '';
      final available = RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(phone);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.afriL10n.shopEnquiryExplanation,
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            label: context.afriL10n.shopEnquire,
            enabled: available && !_isStale && !_isOffline && !_isRefreshing,
            onTap: () async {
              final message = context.afriL10n.shopEnquiryMessage(
                _product?['name']?.toString() ??
                    context.afriL10n.shopProductFallback,
                widget.productId,
                _selectedSize ?? context.afriL10n.shopSizeNotSelected,
                _quantity,
              );
              final opened = await launchUrl(
                Uri.https('wa.me', '/$phone', {'text': message}),
                mode: LaunchMode.externalApplication,
              );
              if (!opened && mounted) {
                AfriToast.error(context, context.afriL10n.genericError);
              }
            },
          ),
        ],
      );
    }
    final totalSummary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.afriL10n.shopTotal,
          style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
        ),
        Text(
          currency.format(total),
          style: TypographyTokens.titleLarge(ColorTokens.primaryContainer),
        ),
      ],
    );
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AfriButton(
          key: const ValueKey<String>('product-detail-add'),
          label: context.afriL10n.shopAddToCart,
          icon: AfriIcons.cart,
          onTap: _addToCart,
          enabled: inStock && !_isStale && !_isOffline && !_isRefreshing,
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        AfriButton(
          key: const ValueKey<String>('product-detail-buy'),
          label: context.afriL10n.shopBuyNow,
          variant: AfriButtonVariant.outline,
          onTap: () {
            if (_addToCart()) unawaited(context.push('/shop/cart'));
          },
          enabled: inStock && !_isStale && !_isOffline && !_isRefreshing,
        ),
      ],
    );

    if (usesLargeTextLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          totalSummary,
          const SizedBox(height: SpacingTokens.spacing3),
          actions,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: totalSummary),
        const SizedBox(width: SpacingTokens.spacing4),
        Expanded(flex: 2, child: actions),
      ],
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ColorTokens.surfaceContainerLow,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.afriL10n.shopProductImageUnavailable,
                textAlign: TextAlign.center,
                style: TypographyTokens.bodyLarge(ColorTokens.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
