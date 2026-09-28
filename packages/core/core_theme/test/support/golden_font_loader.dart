// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/services.dart';

bool _loaded = false;

Future<void> loadCoreThemeGoldenFonts() async {
  if (_loaded) return;
  await _load('MaterialIcons', 'MaterialIcons-Regular.otf');
  final textLoader = FontLoader('GoldenRoboto');
  for (final face in ['Regular', 'Medium', 'Bold', 'Black']) {
    textLoader.addFont(_fontBytes('Roboto-$face.ttf'));
  }
  await textLoader.load();
  _loaded = true;
}

Future<void> _load(String family, String fileName) async {
  final loader = FontLoader(family);
  loader.addFont(_fontBytes(fileName));
  await loader.load();
}

Future<ByteData> _fontBytes(String fileName) async {
  try {
    return await rootBundle.load('packages/flutter/fonts/$fileName');
  } catch (_) {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    final candidates = <File>[
      File(
        '/Volumes/PRO-G40/flutter_3_44/bin/cache/artifacts/material_fonts/$fileName',
      ),
      if (flutterRoot?.isNotEmpty == true)
        File('$flutterRoot/bin/cache/artifacts/material_fonts/$fileName'),
    ];
    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        return ByteData.sublistView(await candidate.readAsBytes());
      }
    }
    throw FileSystemException('Unable to locate $fileName');
  }
}
