// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/services.dart';

bool _designFontsLoaded = false;

Future<void> loadDesignFonts() async {
  if (_designFontsLoaded) {
    return;
  }

  await _preloadBorrowedFonts();
  _designFontsLoaded = true;
}

Future<void> _preloadBorrowedFonts() async {
  final loader = FontLoader('packages/core_theme/RevolutBorrowed');
  for (final font in _borrowedFontAssetPaths) {
    loader.addFont(_loadBorrowedFont(font));
  }
  await loader.load();
}

Future<ByteData> _loadBorrowedFont(String assetPath) async {
  try {
    return await rootBundle.load(assetPath);
  } catch (_) {
    final file = _resolveBorrowedFontFile(assetPath.split('/').last);
    final bytes = await file.readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

const _borrowedFontAssetPaths = <String>[
  'packages/core_theme/assets/fonts/revolut/RevolutBorrowed-Regular.otf',
  'packages/core_theme/assets/fonts/revolut/RevolutBorrowed-Medium.otf',
  'packages/core_theme/assets/fonts/revolut/RevolutBorrowed-SemiBold.otf',
  'packages/core_theme/assets/fonts/revolut/RevolutBorrowed-Bold.otf',
  'packages/core_theme/assets/fonts/revolut/RevolutBorrowed-ExtraBold.otf',
];

File _resolveBorrowedFontFile(String fontFileName) {
  return File('${_resolveBorrowedFontRoot().path}/$fontFileName');
}

Directory _resolveBorrowedFontRoot() {
  var cursor = Directory.current.absolute;

  while (true) {
    final fontRoot = Directory(
      '${cursor.path}/packages/core/core_theme/assets/fonts/revolut',
    );
    if (fontRoot.existsSync()) {
      return fontRoot;
    }

    final parent = cursor.parent;
    if (parent.path == cursor.path) {
      break;
    }
    cursor = parent;
  }

  throw FileSystemException(
    'Unable to locate Revolut borrowed font root from current directory',
    Directory.current.path,
  );
}
