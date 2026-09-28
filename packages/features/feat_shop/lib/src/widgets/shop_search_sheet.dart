import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'shop_product_image.dart';

/// A bounded product search; selection returns before navigating from the host.
Future<void> showShopSearchSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> products,
}) async {
  final productId = await showAfriBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useUniversalSurface: false,
    builder: (_) => _ShopSearchBody(products: products),
  );
  if (context.mounted && productId != null) {
    unawaited(context.push('/shop/product/$productId'));
  }
}

class _ShopSearchBody extends StatefulWidget {
  const _ShopSearchBody({required this.products});
  final List<Map<String, dynamic>> products;
  @override
  State<_ShopSearchBody> createState() => _ShopSearchBodyState();
}

class _ShopSearchBodyState extends State<_ShopSearchBody> {
  final searchController = TextEditingController();
  var query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.products
        .where((product) {
          final haystack = [
            product['name']?.toString() ?? '',
            product['category']?.toString() ?? '',
            product['description']?.toString() ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(query.toLowerCase());
        })
        .toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ShapeTokens.radiusXl),
        ),
        border: BorderTokens.ghost(),
      ),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.spacing6,
        SpacingTokens.spacing4,
        SpacingTokens.spacing6,
        MediaQuery.of(context).padding.bottom + SpacingTokens.spacing4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AfriInputField(
            controller: searchController,
            autofocus: true,
            onChanged: (value) => setState(() => query = value),
            hint: MediaQuery.textScalerOf(context).scale(1) >= 1.5
                ? context.afriL10n.searchTitle
                : context.afriL10n.shopSearchHint,
            prefixIcon: AfriIcons.search,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.spacing6,
              ),
              child: Text(
                context.afriL10n.searchNoResultsMessage(query),
                style: TypographyTokens.bodyLarge(),
              ),
            ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: SpacingTokens.spacing2),
              itemBuilder: (context, index) {
                final currency = CurrencyFormatter(
                  currencyCode: context.afriCurrencyCode,
                  currencySymbol: context.afriCurrencySymbol,
                );
                final product = results[index];
                final id = product['id']?.toString() ?? '';
                final name =
                    product['name']?.toString() ??
                    context.afriL10n.shopProductFallback;
                final category =
                    product['category']?.toString() ??
                    context.afriL10n.shopMerchFallback;
                final price = (product['price'] as num?)?.toDouble() ?? 0;

                return AfriSurfaceCard(
                  onTap: () {
                    Navigator.of(context).pop(id);
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ShopProductImage.isPublished(
                        product['image_url']?.toString(),
                        product['image_rights_approved'] == true,
                        product['image_provenance_id']?.toString(),
                      )) ...[
                        ShopProductImage(
                          url: product['image_url']?.toString(),
                          rightsApproved:
                              product['image_rights_approved'] == true,
                          provenanceId: product['image_provenance_id']
                              ?.toString(),
                          name: name,
                          width: 64,
                          height: 80,
                        ),
                        const SizedBox(width: SpacingTokens.spacing3),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: TypographyTokens.titleMedium()),
                            const SizedBox(height: SpacingTokens.spacing1),
                            Text(category, style: TypographyTokens.bodySmall()),
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              currency.format(price),
                              style: TypographyTokens.bodyLarge(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
