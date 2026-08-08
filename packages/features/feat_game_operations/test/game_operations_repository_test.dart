import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('repository maps an RPC deadline to a typed timeout failure', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.dispose);
    final repository = GameOperationsRepository(
      client: client,
      expectedClubId: '24',
      operationTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      repository.fetchOwnedDisplays(),
      throwsA(
        isA<GameOperationsFailure>().having(
          (failure) => failure.kind,
          'kind',
          GameOperationsFailureKind.timeout,
        ),
      ),
    );
  });

  test('repository rejects a non-positive operation deadline', () {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
    );
    addTearDown(client.dispose);

    expect(
      () => GameOperationsRepository(
        client: client,
        expectedClubId: '24',
        operationTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });

  test(
    'repository maps a network client failure to typed offline state',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        httpClient: MockClient((request) async {
          throw http.ClientException('Failed host lookup', request.url);
        }),
      );
      addTearDown(client.dispose);
      final repository = GameOperationsRepository(
        client: client,
        expectedClubId: '24',
      );

      await expectLater(
        repository.fetchOwnedDisplays(),
        throwsA(
          isA<GameOperationsFailure>().having(
            (failure) => failure.kind,
            'kind',
            GameOperationsFailureKind.offline,
          ),
        ),
      );
    },
  );
}
