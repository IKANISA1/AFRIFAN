import 'dart:io' as io;

import 'package:core_network/core_network.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Published kit photographs used only in local, synthetic catalogue reviews.
/// See assets/shop/sources.json for provenance and the review-only restriction.
/// These are not bundled with any application and do not approve production use.
const shopHomePhoto = 'https://media.example.invalid/shop/home.jpg';
const shopAwayPhoto = 'https://media.example.invalid/shop/away.jpg';
const shopPhotoProvenance = 'local-review-kit-photographs-20260924';

void useShopFixtureImages() {
  BaseCacheManager? previous;
  setUp(() {
    previous = AfriImageCacheManager.testOverride;
    AfriImageCacheManager.testOverride = _ShopFixtureCache();
  });
  tearDown(() {
    AfriImageCacheManager.testOverride = previous;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
}

/// Dismiss transient feedback using the same swipe available to a supporter.
Future<void> dismissShopFixtureFeedback(WidgetTester tester) async {
  if (find.byType(SnackBar).evaluate().isNotEmpty) {
    await tester.drag(find.byType(SnackBar), const Offset(0, 160));
    await tester.pumpAndSettle();
  }
}

/// Wait for actual image decoding, rather than capturing a loading placeholder.
Future<void> settleShopFixtureImages(
  WidgetTester tester, {
  bool settleAnimations = true,
}) async {
  final subscriptions = <(ImageStream, ImageStreamListener)>[];
  var pending = 0;
  for (final element in find.byType(Image).evaluate()) {
    final provider = (element.widget as Image).image;
    final stream = provider.resolve(createLocalImageConfiguration(element));
    pending += 1;
    var completed = false;
    void finish() {
      if (!completed) pending -= 1;
      completed = true;
    }

    final listener = ImageStreamListener(
      (_, _) => finish(),
      onError: (Object error, StackTrace? stack) {
        finish();
        throw TestFailure('Review photograph failed to decode: $error');
      },
    );
    stream.addListener(listener);
    subscriptions.add((stream, listener));
  }
  try {
    // Filesystem/decode work runs in real time; stream notifications run on
    // the widget-test clock. Drain both until every displayed image is ready.
    for (var attempt = 0; pending > 0 && attempt < 200; attempt += 1) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(
      pending,
      0,
      reason: 'Capture must contain decoded product photographs.',
    );
    if (settleAnimations) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  } finally {
    for (final (stream, listener) in subscriptions) {
      stream.removeListener(listener);
    }
  }
}

class _ShopFixtureCache extends Fake
    implements BaseCacheManager, ImageCacheManager {
  _ShopFixtureCache() {
    var root = io.Directory.current;
    while (!io.Directory(
      '${root.path}/packages/testing/test_support/assets/shop',
    ).existsSync()) {
      if (root.parent.path == root.path) {
        throw StateError('Cannot locate the local shop review photographs.');
      }
      root = root.parent;
    }
    _root = '${root.path}/packages/testing/test_support/assets/shop';
  }

  late final String _root;
  static const _files = {
    shopHomePhoto: 'kit-a.jpg',
    shopAwayPhoto: 'kit-b.jpg',
  };

  FileInfo _info(String url) {
    final filename = _files[url];
    if (filename == null) {
      throw StateError('Unexpected fixture image URL: $url');
    }
    return FileInfo(
      const LocalFileSystem().file('$_root/$filename'),
      FileSource.Cache,
      DateTime(2100),
      url,
    );
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => Stream.value(_info(url));

  @override
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) => getFileStream(url);

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async => _info(url).file;

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async => _info(key);

  @override
  Future<FileInfo?> getFileFromMemory(String key) async => _info(key);

  @override
  Future<void> removeFile(String key) async {}
}
