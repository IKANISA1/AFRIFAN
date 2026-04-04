import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bottom sheet for searching products in the shop.
void showShopSearchSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> products,
}) {
  var query = '';

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
                top: Radius.circular(28),
              ),
              border: Border.all(color: ColorTokens.ghostBorder, width: 0.5),
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
                TextField(
                  autofocus: true,
                  onChanged: (value) => setModalState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search kits, scarves, and drops',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: SpacingTokens.spacing2),
                    itemBuilder: (context, index) {
                      final product = results[index];
                      final id = product['id']?.toString() ?? '';
                      final name = product['name']?.toString() ?? 'Product';
                      final category =
                          product['category']?.toString() ?? 'Merch';
                      final price = (product['price'] as num?)?.toDouble() ?? 0;

                      return ClayCard(
                        onTap: () {
                          context.pop();
                          context.go('/shop/product/$id');
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toUpperCase(),
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: ColorTokens.onSurface,
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
                              'FRw ${price.toStringAsFixed(0)}',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: ColorTokens.clubAccent,
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
        },
      );
    },
  );
}
