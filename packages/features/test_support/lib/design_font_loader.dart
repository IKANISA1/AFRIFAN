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
  for (final file in _resolveBorrowedFontFiles()) {
    final bytes = await file.readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

List<File> _resolveBorrowedFontFiles() {
  var cursor = Directory.current.absolute;

  while (true) {
    final fontRoot = Directory(
      '${cursor.path}/packages/core/core_theme/assets/fonts/revolut',
    );
    if (fontRoot.existsSync()) {
      return const <String>[
        'RevolutBorrowed-Regular.otf',
        'RevolutBorrowed-Medium.otf',
        'RevolutBorrowed-SemiBold.otf',
        'RevolutBorrowed-Bold.otf',
        'RevolutBorrowed-ExtraBold.otf',
      ].map((name) => File('${fontRoot.path}/$name')).toList();
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
