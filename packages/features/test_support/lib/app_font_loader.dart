// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/services.dart';

bool _appFontsLoaded = false;

Future<void> loadAppFonts() async {
  if (_appFontsLoaded) {
    return;
  }

  await _preloadMaterialIcons();
  _appFontsLoaded = true;
}

Future<void> _preloadMaterialIcons() async {
  try {
    final loader = FontLoader('MaterialIcons');
    loader.addFont(_loadMaterialIconsFont());
    await loader.load();
  } on Object {
    // Device integration tests cannot read host Flutter SDK font paths.
    // MaterialIcons are visual polish for these tests, not the assertion target.
  }
}

Future<ByteData> _loadMaterialIconsFont() async {
  const assetPath = 'packages/flutter/fonts/MaterialIcons-Regular.otf';
  try {
    return await rootBundle.load(assetPath);
  } catch (_) {
    final bytes = await _resolveMaterialIconsFontFile().readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

File _resolveMaterialIconsFontFile() {
  final candidates = <File>[
    File(
      '/Volumes/PRO-G40/flutter_3_44/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ),
    File(
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ),
  ];

  for (final candidate in candidates) {
    if (candidate.existsSync()) {
      return candidate;
    }
  }

  throw FileSystemException(
    'Unable to locate MaterialIcons-Regular.otf for widget tests',
    Directory.current.path,
  );
}
