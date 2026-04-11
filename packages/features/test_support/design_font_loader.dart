import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

bool _designFontsLoaded = false;

Future<void> loadDesignFonts() async {
  if (_designFontsLoaded) {
    return;
  }

  final fontRoot = _resolveFontRoot();

  Future<ByteData> bytesFor(String name) async {
    final file = File('${fontRoot.path}/$name');
    if (!file.existsSync()) {
      throw FileSystemException('Design font file not found', file.path);
    }

    final bytes = await file.readAsBytes();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }

  final displayLoader = FontLoader('Space Grotesk')
    ..addFont(bytesFor('BarlowCondensed-SemiBold.ttf'))
    ..addFont(bytesFor('BarlowCondensed-Bold.ttf'))
    ..addFont(bytesFor('BarlowCondensed-ExtraBold.ttf'))
    ..addFont(bytesFor('BarlowCondensed-Black.ttf'));

  final bodyLoader = FontLoader('Manrope')
    ..addFont(bytesFor('Inter-Regular.ttf'))
    ..addFont(bytesFor('Inter-Medium.ttf'))
    ..addFont(bytesFor('Inter-SemiBold.ttf'))
    ..addFont(bytesFor('Inter-Bold.ttf'));

  final utilityLoader = FontLoader('Inter')
    ..addFont(bytesFor('Inter-Regular.ttf'))
    ..addFont(bytesFor('Inter-Medium.ttf'))
    ..addFont(bytesFor('Inter-SemiBold.ttf'))
    ..addFont(bytesFor('Inter-Bold.ttf'));

  await Future.wait<void>([
    displayLoader.load(),
    bodyLoader.load(),
    utilityLoader.load(),
  ]);

  _designFontsLoaded = true;
}

Directory _resolveFontRoot() {
  var cursor = Directory.current.absolute;

  while (true) {
    final candidate = Directory(
      '${cursor.path}/apps/rayon_sports/google_fonts',
    );
    if (candidate.existsSync()) {
      return candidate;
    }

    final parent = cursor.parent;
    if (parent.path == cursor.path) {
      throw FileSystemException(
        'Unable to locate apps/rayon_sports/google_fonts from current directory',
        Directory.current.path,
      );
    }
    cursor = parent;
  }
}
