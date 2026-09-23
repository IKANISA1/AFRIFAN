// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/services.dart';

bool _appFontsLoaded = false;

Future<void> loadAppFonts() async {
  if (_appFontsLoaded) {
    return;
  }

  await _preloadMaterialIcons();
  await _preloadGoldenRoboto();
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

Future<void> _preloadGoldenRoboto() async {
  try {
    final loader = FontLoader('GoldenRoboto');
    loader.addFont(_loadFlutterArtifactFont('Roboto-Regular.ttf'));
    await loader.load();
  } on Object {
    // Non-golden tests may run in device environments without host SDK files.
  }
}

Future<ByteData> _loadFlutterArtifactFont(String fileName) async {
  final assetPath = 'packages/flutter/fonts/$fileName';
  try {
    return await rootBundle.load(assetPath);
  } catch (_) {
    final bytes = await _resolveFlutterArtifactFontFile(fileName).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

File _resolveMaterialIconsFontFile() {
  return _resolveFlutterArtifactFontFile('MaterialIcons-Regular.otf');
}

File _resolveFlutterArtifactFontFile(String fileName) {
  final candidates = <File>[
    File(
      '/Volumes/PRO-G40/flutter_3_44/bin/cache/artifacts/material_fonts/$fileName',
    ),
    File(
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/$fileName',
    ),
  ];

  for (final candidate in candidates) {
    if (candidate.existsSync()) {
      return candidate;
    }
  }

  throw FileSystemException(
    'Unable to locate $fileName for widget tests',
    Directory.current.path,
  );
}
