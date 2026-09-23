import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';

/// Full-width discovery card. Product media, category and copy share one
/// continuous surface; the add action remains independently accessible.
class ArmouryProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final int index;

  const ArmouryProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.autofocus = false,
    required this.index,
  });

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );
    final l10n = context.afriL10n;
    final enquiry = product['commerce_mode'] == 'enquiry';
    final name = product['name']?.toString() ?? l10n.shopProductFallback;
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final subtitle = product['subtitle']?.toString() ?? '';
    final badge = product['badge_label']?.toString();
    final stock =
        (product['stock'] as num?)?.toInt() ??
        (product['inventory_count'] as num?)?.toInt();
    final isAvailable =
        product['is_active'] != false &&
        product['in_stock'] != false &&
        (stock == null || stock > 0);
    final visibleBadge = isAvailable ? badge : l10n.shopOutOfStockUpper;
    final imageUrl = product['image_url']?.toString();
    final imageProvenanceId =
        product['image_provenance_id']?.toString().trim() ?? '';
    final imageRightsApproved =
        product['image_rights_approved'] == true &&
        imageProvenanceId.isNotEmpty;
    final category = product['category']?.toString() ?? '';
    final usesLargeTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final image = Uri.tryParse(imageUrl ?? '');
    final hasApprovedImage =
        imageRightsApproved &&
        image?.scheme == 'https' &&
        image!.host.isNotEmpty &&
        image.userInfo.isEmpty;
    final foreground = hasApprovedImage
        ? ColorTokens.shopEditorialText
        : ColorTokens.onSurface;
    final secondary = hasApprovedImage
        ? ColorTokens.shopEditorialSecondaryText
        : ColorTokens.onSurfaceVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            AfriSurfaceCard(
              onTap: onTap,
              autofocus: autofocus,
              semanticsLabel:
                  '${isAvailable ? name : l10n.shopProductUnavailableSemantic(name)}, ${currency.format(price)}',
              semanticsHint: l10n.shopOpenProduct,
              backgroundColor: hasApprovedImage
                  ? ColorTokens.shopEditorialSurface
                  : ColorTokens.surfaceContainerLow,
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: ShapeTokens.cardRadius,
                child: Stack(
                  children: [
                    if (hasApprovedImage)
                      Positioned.fill(
                        child: _ProductImage(
                          imageUrl: imageUrl,
                          semanticLabel: l10n.shopProductImageSemantic(name),
                          provenanceId: imageProvenanceId.isEmpty
                              ? 'shop:${product['id'] ?? 'unknown'}:unapproved'
                              : imageProvenanceId,
                          rightsApproved: imageRightsApproved,
                        ),
                      ),
                    if (hasApprovedImage)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: ColorTokens.imageScrimGradient(
                              color: ColorTokens.inkBase,
                              alphas: const [0.38, 0.0, 0.15, 0.88, 0.98],
                              stops: const [0.0, 0.24, 0.45, 0.78, 1.0],
                            ),
                          ),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(SpacingTokens.spacing4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                AfriIcons.shop,
                                color: foreground,
                                size: SizeTokens.iconMd,
                              ),
                              const SizedBox(width: SpacingTokens.spacing2),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.isEmpty
                                          ? l10n.shopClubStore
                                          : category,
                                      style: TypographyTokens.bodyLarge(
                                        foreground,
                                      ),
                                    ),
                                    if (usesLargeTextLayout &&
                                        visibleBadge != null &&
                                        visibleBadge.isNotEmpty)
                                      Text(
                                        visibleBadge,
                                        style: TypographyTokens.labelSmall(
                                          secondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (!usesLargeTextLayout &&
                                  visibleBadge != null &&
                                  visibleBadge.isNotEmpty)
                                Flexible(
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Text(
                                      visibleBadge,
                                      textAlign: TextAlign.end,
                                      style: TypographyTokens.labelSmall(
                                        secondary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (hasApprovedImage)
                          SizedBox(
                            height: usesLargeTextLayout
                                ? width * 0.42
                                : width * 0.72,
                          ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            SpacingTokens.spacing4,
                            SpacingTokens.spacing2,
                            usesLargeTextLayout
                                ? SpacingTokens.spacing4
                                : SpacingTokens.spacing4 +
                                      SizeTokens.touchTargetMin,
                            usesLargeTextLayout
                                ? SpacingTokens.spacing4 +
                                      SizeTokens.touchTargetMin
                                : SpacingTokens.spacing4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style:
                                    TypographyTokens.headlineSmall(
                                      foreground,
                                    ).copyWith(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: SpacingTokens.spacing1),
                                Text(
                                  subtitle,
                                  style: TypographyTokens.bodyMedium(secondary),
                                ),
                              ],
                              const SizedBox(height: SpacingTokens.spacing1),
                              Text(
                                currency.format(price),
                                style: TypographyTokens.bodyLarge(foreground),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: SpacingTokens.spacing3,
              bottom: SpacingTokens.spacing3,
              child: AfriIconButton(
                key: ValueKey<String>('shop-add-${product['id'] ?? index}'),
                icon: enquiry ? AfriIcons.chevronRight : AfriIcons.add,
                filled: true,
                tooltip: enquiry
                    ? l10n.shopEnquiryOptions
                    : isAvailable
                    ? l10n.shopAddToCart
                    : l10n.shopOutOfStock,
                onTap: enquiry
                    ? onTap
                    : isAvailable
                    ? onAddToCart
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.semanticLabel,
    required this.provenanceId,
    required this.rightsApproved,
  });

  final String? imageUrl;
  final String semanticLabel;
  final String provenanceId;
  final bool rightsApproved;

  @override
  Widget build(BuildContext context) {
    final gradient = ColorTokens.universalGradient(
      colors: [
        ColorTokens.referencePaymentsPurpleMid,
        ColorTokens.shopEditorialSurface,
      ],
    );

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return AfriGovernedCachedImage(
        imageUrl: imageUrl!,
        semanticLabel: semanticLabel,
        provenanceId: provenanceId,
        rightsApproved: rightsApproved,
        fit: BoxFit.cover,
        borderRadius: ShapeTokens.radiusNone,
        placeholder: _fallback(gradient),
        errorFallback: _fallback(gradient),
      );
    }
    return _fallback(gradient);
  }

  Widget _fallback(Gradient gradient) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Align(
        alignment: const Alignment(0, -0.3),
        child: Icon(
          AfriIcons.shop,
          size: SizeTokens.iconHero,
          color: ColorTokens.shopEditorialSecondaryText.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
