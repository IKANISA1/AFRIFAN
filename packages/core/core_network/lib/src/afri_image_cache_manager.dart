import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Centralized configuration for CachedNetworkImage limits.
/// Limits the cache to 200 items, keeping them for up to 7 days,
/// preventing unbound disk growth from banners and avatars.
class AfriImageCacheManager {
  static const key = 'afri_image_cache';

  static final CacheManager _defaultInstance = CacheManager(
    Config(key, stalePeriod: const Duration(days: 7), maxNrOfCacheObjects: 200),
  );

  /// Tests can supply local files through the same image decoding/render path.
  /// This avoids network access and platform cache plugins in widget tests.
  @visibleForTesting
  static BaseCacheManager? testOverride;

  static BaseCacheManager get instance => testOverride ?? _defaultInstance;
}
