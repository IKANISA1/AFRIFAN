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
                  top: -(SpacingTokens.spacing1 / 2),
                  right: -(SpacingTokens.spacing1 / 2),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth:
                          SpacingTokens.spacing5 - (SpacingTokens.spacing1 / 2),
                    ),
                    height:
                        SpacingTokens.spacing5 - (SpacingTokens.spacing1 / 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing1,
                    ),
                    decoration: BoxDecoration(
                      color: ColorTokens.primaryContainer,
                      borderRadius: BorderRadius.circular(
                        ShapeTokens.radiusFull,
                      ),
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
