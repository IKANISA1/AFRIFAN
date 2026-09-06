import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Published club artwork, with the registered Rayon crest available offline.
/// Other club shells retain their own identity; no Rayon fallback crosses tenants.
class ClubCrest extends StatelessWidget {
  const ClubCrest({
    super.key,
    required this.clubSlug,
    required this.clubName,
    this.imageUrl,
    this.size = 88,
  });
  final String clubSlug, clubName;
  final String? imageUrl;
  final double size;
  static const rayonAsset = 'packages/feat_club/assets/crests/rayon_sports.png';

  @override
  Widget build(BuildContext context) {
    final url = Uri.tryParse(imageUrl ?? '');
    final fallback = clubSlug == 'rayon_sports_rw'
        ? Image.asset(
            rayonAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          )
        : AfriBrandMark(label: clubName, size: size);
    return Semantics(
      image: true,
      label: clubName,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: url?.scheme == 'https' && url!.host.isNotEmpty
            ? Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}
