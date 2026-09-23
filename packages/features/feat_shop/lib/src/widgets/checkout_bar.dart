import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';

/// Sticky checkout bar shown when the cart has items.
class CheckoutBar extends StatelessWidget {
  final int itemCount;
  final double total;
  final VoidCallback? onCheckout;

  const CheckoutBar({
    super.key,
    required this.itemCount,
    required this.total,
    this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );

    return AnimatedSlide(
      offset: itemCount > 0 ? Offset.zero : const Offset(0, 1.5),
      duration: AfriMotion.standard,
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          SpacingTokens.spacing4,
          0,
          SpacingTokens.spacing4,
          bottomPadding + SpacingTokens.spacing3,
        ),
        child: AfriSurfaceCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing4,
            vertical: SpacingTokens.spacing3,
          ),
          child: Row(
            children: [
              AfriStatusChip(label: '$itemCount', icon: AfriIcons.cart),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currency.format(total),
                      style: TypographyTokens.titleLarge(),
                    ),
                    Text(
                      context.afriL10n.shopReadyToCheckout,
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              AfriButton(
                label: context.afriL10n.shopCheckout,
                icon: AfriIcons.forward,
                onTap: onCheckout ?? () {},
                fullWidth: false,
                enabled: onCheckout != null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
