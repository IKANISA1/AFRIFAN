import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Floating checkout bar — sticky at the bottom of the shop.
///
/// Shows "✓ CHECKOUT · {count} ITEMS · ${total}"
/// Appears only when cart has items, slides up with animation.
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
      currencyCode: 'RWF',
      currencySymbol: 'FRw',
    );

    return AnimatedSlide(
      offset: itemCount > 0 ? Offset.zero : const Offset(0, 1.5),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 12),
        child: AfriPressFeedback(
          onTap: onCheckout,
          scaleEnd: 0.97,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: ColorTokens.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ColorTokens.ghostBorder, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: ColorTokens.background.withValues(alpha: 0.8),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: ColorTokens.clubPrimary.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing4,
                vertical: SpacingTokens.spacing2,
              ),
              child: Row(
                children: [
                  // Item count pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ColorTokens.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ColorTokens.ghostBorder,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '$itemCount',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ColorTokens.onSurfaceVariant,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing4),
                  // Total price
                  Text(
                    currency.format(total),
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: ColorTokens.onSurface,
                      height: 1.0,
                    ),
                  ),
                  const Spacer(),
                  // Checkout Action Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: ColorTokens.clubPrimary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_checkout_rounded,
                          color: ColorTokens.onSurface,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CHECKOUT',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ColorTokens.onSurface,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
