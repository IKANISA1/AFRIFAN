import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom sheet for searching products in the shop.
void showShopSearchSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> products,
}) {
  final searchController = TextEditingController();
  var query = '';

  unawaited(
    showAfriBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useUniversalSurface: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final results = products
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
                    onChanged: (value) => setModalState(() => query = value),
                    hint: context.afriL10n.shopSearchHint,
                    prefixIcon: AfriIcons.search,
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
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
                        final price =
                            (product['price'] as num?)?.toDouble() ?? 0;

                        return AfriSurfaceCard(
                          onTap: () {
                            context.pop();
                            unawaited(context.push('/shop/product/$id'));
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TypographyTokens.headlineSmall()
                                          .copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(
                                      height: SpacingTokens.spacing1,
                                    ),
                                    Text(
                                      category,
                                      style: TypographyTokens.bodySmall(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: SpacingTokens.spacing3),
                              Text(
                                currency.format(price),
                                style: TypographyTokens.headlineSmall(
                                  ColorTokens.primaryContainer,
                                ).copyWith(fontWeight: FontWeight.w600),
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
          },
        );
      },
    ).whenComplete(searchController.dispose),
  );
}
