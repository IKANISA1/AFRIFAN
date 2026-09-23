import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('released client reconciliation remains fail closed', () {
    var root = Directory.current;
    while (!Directory('${root.path}/supabase/migrations').existsSync()) {
      if (root.parent.path == root.path) {
        throw StateError('Cannot locate the AFRICLUB workspace.');
      }
      root = root.parent;
    }
    final sourceRoots = [
      Directory('${root.path}/packages/core'),
      Directory('${root.path}/packages/data'),
      Directory('${root.path}/packages/features'),
      ...Directory('${root.path}/apps').listSync().whereType<Directory>().map(
        (app) => Directory('${app.path}/lib'),
      ),
    ];
    final financialWrites = RegExp(
      r'''\.from\(\s*['"](?:group_contributions|momo_ledger_entries|momo_reconciliations)['"]\s*\)[^;]*\.(?:insert|update|upsert|delete)\(''',
      dotAll: true,
    );
    final reconciliationRpc = RegExp(
      r'''\.rpc\(\s*['"]reconcile_group_contribution_from_sms['"]''',
    );
    var checked = 0;
    for (final directory in sourceRoots.where((dir) => dir.existsSync())) {
      for (final file
          in directory
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()) {
        if (!file.path.endsWith('.dart') ||
            !file.path.contains('/lib/') ||
            file.path.contains('/build/') ||
            file.path.contains('/.dart_tool/')) {
          continue;
        }
        final source = file.readAsStringSync();
        expect(
          financialWrites.hasMatch(source),
          isFalse,
          reason: '${file.path} must not mutate confirmed financial records',
        );
        expect(
          reconciliationRpc.hasMatch(source),
          isFalse,
          reason: '${file.path} must not call the trusted reconciliation RPC',
        );
        checked++;
      }
    }
    expect(checked, greaterThan(0));
  });
}
