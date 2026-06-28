import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Minimal top bar for the shop screen.
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
            icon: AfriIcons.back,
            tooltip: 'Back',
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Text('Shop', style: TypographyTokens.headlineSmall()),
          ),
          AfriIconButton(
            icon: AfriIcons.search,
            tooltip: 'Search',
            onTap: onSearchPressed,
          ),
          const SizedBox(width: SpacingTokens.spacing2),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AfriIconButton(
                icon: AfriIcons.cart,
                tooltip: 'Cart',
                onTap: () => context.push('/shop/cart'),
              ),
              if (cartItemCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: ColorTokens.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                      border: BorderTokens.all(
                        color: ColorTokens.background,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$cartItemCount',
                      style: TypographyTokens.labelSmall(ColorTokens.onSurface),
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
