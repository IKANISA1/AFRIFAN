import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('released client cannot invoke arbitrary point grant paths', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'public-anon-test-key',
    );
    final repository = ClubRepository(
      client: client,
      healthService: OperationalHealthService(client: client),
      storeReleasePolicy: const StoreReleasePolicy(isEnforced: true),
    );

    await expectLater(
      repository.addPoints('user-1', 'club-1', 1000000, 'client supplied'),
      throwsA(isA<UnsupportedError>()),
    );
    await expectLater(
      repository.recordFetEvent(
        userId: 'user-1',
        eventType: FetEventType.matchAttendance,
        metadata: const <String, Object?>{'client_supplied': true},
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
