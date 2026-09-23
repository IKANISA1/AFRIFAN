import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime media migration is fail-closed and provenance constrained', () {
    final workspace = _findWorkspaceRoot();
    final migrations = Directory('${workspace.path}/supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_football_only_baseline.sql'))
        .toList();

    expect(
      migrations,
      hasLength(1),
      reason: 'Media rights must be governed by the single clean baseline.',
    );
    final source = migrations.single.readAsStringSync();

    for (final table in const ['news_articles', 'shop_products', 'matches']) {
      expect(source, contains('CREATE TABLE IF NOT EXISTS "public"."$table"'));
    }
    expect(
      RegExp(
        r'"image_rights_approved" boolean DEFAULT false NOT NULL',
      ).allMatches(source),
      hasLength(3),
    );
    expect(source, contains('"image_provenance_id" "text"'));
    expect(
      source,
      contains('"image_rights_approved_at" timestamp with time zone'),
    );
    expect(source, contains('"image_rights_approved_by" "uuid"'));
    expect(source, contains('"home_team_logo_provenance_id" "text"'));
    expect(source, contains('"away_team_logo_provenance_id" "text"'));
    expect(source, contains('approved_media_has_provenance'));
    expect(
      source,
      isNot(contains('"image_rights_approved" boolean DEFAULT true')),
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
