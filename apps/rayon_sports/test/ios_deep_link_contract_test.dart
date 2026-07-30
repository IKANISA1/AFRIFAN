import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS delegates custom links to the app_links route parser', () {
    final infoPlist = File(
      '${_workspacePrefix()}apps/rayon_sports/ios/Runner/Info.plist',
    ).readAsStringSync();

    expect(infoPlist, contains('<string>gikundiro</string>'));
    expect(
      infoPlist,
      contains(
        '<key>FlutterDeepLinkingEnabled</key>\n'
        '\t<false/>',
      ),
      reason:
          'Flutter framework deep linking must stay disabled when app_links '
          'owns normalization and safe route validation.',
    );
  });
}

String _workspacePrefix() {
  final current = Directory.current.path.replaceAll(r'\', '/');
  return current.endsWith('/apps/rayon_sports') ? '../../' : '';
}
