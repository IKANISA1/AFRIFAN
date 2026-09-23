import 'dart:io';

import 'package:feat_settings/src/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conflict error instructs a refresh instead of silent overwrite', () {
    const error = SettingsConflictException('Privacy settings');
    expect(error.toString(), contains('changed on another device'));
    expect(error.toString(), contains('reviewed before saving again'));
  });

  test('repository writes use atomic updated_at comparison', () {
    final packageSource = File('lib/src/settings_repository.dart');
    final source =
        (packageSource.existsSync()
                ? packageSource
                : File(
                    'packages/features/feat_settings/lib/src/settings_repository.dart',
                  ))
            .readAsStringSync();

    expect(source, contains(".eq('updated_at', expectedUpdatedAt)"));
    expect(source, contains(".eq('user_id', settings.userId)"));
    expect(source, contains('.insert(settings.toJson())'));
    expect(source, isNot(contains('.upsert(settings.toJson()')));
  });
}
