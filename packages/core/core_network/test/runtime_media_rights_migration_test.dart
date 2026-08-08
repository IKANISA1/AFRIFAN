import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime media migration is fail-closed and provenance constrained', () {
    final workspace = _findWorkspaceRoot();
    final source = File(
      '${workspace.path}/supabase/migrations/'
      '20260724143000_govern_runtime_media_rights.sql',
    ).readAsStringSync();

    for (final table in const ['news_articles', 'shop_products', 'matches']) {
      expect(source, contains('alter table public.$table'));
    }
    expect(
      RegExp(
        r'image_rights_approved boolean not null\s+default false',
      ).allMatches(source),
      hasLength(3),
    );
    expect(source, contains('image_provenance_id text'));
    expect(source, contains('image_rights_approved_at timestamptz'));
    expect(source, contains('image_rights_approved_by uuid'));
    expect(source, contains('home_team_logo_provenance_id text'));
    expect(source, contains('away_team_logo_provenance_id text'));
    expect(source, contains('approved_media_has_provenance'));
    expect(
      source,
      isNot(contains('default true')),
      reason: 'Media rights must never opt in by default.',
    );
  });
}

Directory _findWorkspaceRoot() {
  var candidate = File.fromUri(Platform.script).parent.absolute;
  while (candidate.parent.path != candidate.path) {
    if (File('${candidate.path}/pubspec.yaml').existsSync() &&
        Directory('${candidate.path}/supabase/migrations').existsSync()) {
      return candidate;
    }
    candidate = candidate.parent;
  }
  throw StateError(
    'Could not locate the AFRICLUB workspace root from ${Platform.script}.',
  );
}
