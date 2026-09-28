import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// The same published product photograph follows the item through the shop.
class ShopProductImage extends StatelessWidget {
  const ShopProductImage({
    super.key,
    required this.url,
    required this.provenanceId,
    required this.rightsApproved,
    required this.name,
    this.width,
    this.height,
    this.borderRadius = ShapeTokens.radiusLg,
  });

  final String? url, provenanceId;
  final bool rightsApproved;
  final String name;
  final double? width, height;
  final double borderRadius;

  static bool isPublished(String? url, bool approved, String? provenance) {
    final uri = Uri.tryParse(url?.trim() ?? '');
    return approved &&
        (provenance?.trim().isNotEmpty ?? false) &&
        uri?.scheme == 'https' &&
        uri!.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!isPublished(url, rightsApproved, provenanceId)) {
      return const SizedBox.shrink();
    }
    return AfriGovernedCachedImage(
      imageUrl: url,
      provenanceId: provenanceId!,
      rightsApproved: rightsApproved,
      semanticLabel: context.afriL10n.shopProductImageSemantic(name),
      width: width,
      height: height,
      borderRadius: borderRadius,
      fit: BoxFit.cover,
      placeholder: ColoredBox(color: ColorTokens.surfaceContainerLow),
      errorFallback: ColoredBox(color: ColorTokens.surfaceContainerLow),
    );
  }
}
