import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

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
  @override
  Widget build(BuildContext context) => AfriTeamCrest(
    name: teamAssetFor(clubSlug) == null ? clubName : clubSlug,
    crestUrl: imageUrl,
    size: size,
  );
}
