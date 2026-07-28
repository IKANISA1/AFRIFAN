import 'dart:io';

import 'package:core_auth/core_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile conflict requires refresh and review', () {
    const error = ProfileConflictException();
    expect(error.toString(), contains('changed on another device'));
    expect(error.toString(), contains('Refresh the latest profile'));
  });

  test('profile update compares the loaded updated_at token atomically', () {
    final packageSource = File('lib/src/auth_repository.dart');
    final source =
        (packageSource.existsSync()
                ? packageSource
                : File('packages/core/core_auth/lib/src/auth_repository.dart'))
            .readAsStringSync();

    expect(source, contains(".eq('id', profile.id)"));
    expect(source, contains(".eq('updated_at', expectedUpdatedAt)"));
    expect(source, contains('updateProfile.compareAndSetProfile'));
    expect(source, isNot(contains('await _upsertPrivateContact(profile);')));
  });
}
