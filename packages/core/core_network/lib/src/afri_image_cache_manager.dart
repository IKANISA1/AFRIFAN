import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Centralized configuration for CachedNetworkImage limits.
/// Limits the cache to 200 items, keeping them for up to 7 days,
/// preventing unbound disk growth from banners and avatars.
class AfriImageCacheManager {
  static const key = 'afri_image_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
    ),
  );
}
