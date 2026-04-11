import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Top navigation bar for the shop screen with back, branding,
/// search, filter, and cart actions.
class ShopTopBar extends StatelessWidget {
  const ShopTopBar({
    super.key,
    required this.cartItemCount,
    required this.categories,
    required this.onSearchPressed,
  });

  final int cartItemCount;
  final List<String> categories;
  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.spacing4,
        SpacingTokens.spacing3,
        SpacingTokens.spacing4,
        0,
      ),
      child: Row(
        children: [
          AfriIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          const Spacer(),
          Text(
            RuntimeBranding.displayAppName.toUpperCase(),
            style: TypographyTokens.monolithFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ColorTokens.onSurface,
              letterSpacing: 3.0,
            ),
          ),
          const Spacer(),
          AfriIconButton(
            icon: Icons.tune_rounded,
            onTap: () => showAfriFilterSortSheet(
              context: context,
              title: 'Shop Filters',
              sortOptions: const [
                AfriFilterOption(value: 'newest', label: 'Newest'),
                AfriFilterOption(value: 'price_high', label: 'Price High'),
                AfriFilterOption(value: 'price_low', label: 'Price Low'),
              ],
              typeOptions: categories
                  .where((category) => category != 'All')
                  .map(
                    (category) => AfriFilterOption(
                      value: category.toLowerCase(),
                      label: category.toUpperCase(),
                    ),
                  )
                  .toList(growable: false),
              showDateRange: false,
              showAmountRange: true,
              maxAmount: 250000,
            ),
          ),
          const SizedBox(width: 8),
          AfriIconButton(icon: Icons.search_rounded, onTap: onSearchPressed),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AfriIconButton(
                icon: Icons.shopping_bag_outlined,
                onTap: () => context.push('/shop/cart'),
              ),
              if (cartItemCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: BorderTokens.all(
                        color: ColorTokens.background,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$cartItemCount',
                        style: TypographyTokens.editorialFont(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: ColorTokens.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
