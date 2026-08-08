import 'package:feat_gamification/src/repositories/live_game_v2_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockRealtimeChannel extends Mock implements RealtimeChannel {}

const _sessionId = '99000000-0000-4000-8000-000000000031';

void main() {
  setUpAll(() {
    registerFallbackValue(PostgresChangeEvent.insert);
    registerFallbackValue(
      PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'topic',
        value: '24:game_session:$_sessionId',
      ),
    );
  });

  test('GAME-MOB-03 rejects invalid subscription identities', () {
    final client = _MockSupabaseClient();

    expect(
      () => LiveGameV2Repository(client: client, expectedClubId: 'club-24'),
      throwsArgumentError,
    );
    expect(
      () => SupabaseParticipantLiveGameGateway(
        client: client,
        expectedClubId: '24',
        sessionId: 'session-1',
      ),
      throwsArgumentError,
    );
    expect(
      () => SupabaseParticipantAnswerGateway(
        client: client,
        expectedClubId: '0',
        sessionId: _sessionId,
      ),
      throwsArgumentError,
    );
  });

  test(
    'GAME-MOB-03 subscribes to one club session and recovers unexpected close',
    () async {
      final client = _MockSupabaseClient();
      final channel = _MockRealtimeChannel();
      void Function(RealtimeSubscribeStatus, Object?)? statusCallback;

      when(() => client.channel(any())).thenReturn(channel);
      when(
        () => channel.onPostgresChanges(
          event: any(named: 'event'),
          schema: any(named: 'schema'),
          table: any(named: 'table'),
          filter: any(named: 'filter'),
          callback: any(named: 'callback'),
        ),
      ).thenReturn(channel);
      when(() => channel.subscribe(any())).thenAnswer((invocation) {
        statusCallback =
            invocation.positionalArguments.first
                as void Function(RealtimeSubscribeStatus, Object?);
        return channel;
      });
      when(() => client.removeChannel(channel)).thenAnswer((_) async => 'ok');

      final gateway = SupabaseParticipantLiveGameGateway(
        client: client,
        expectedClubId: '24',
        sessionId: _sessionId,
      );
      final errors = <Object>[];
      final subscription = gateway.watchInvalidationHints().listen(
        (_) {},
        onError: errors.add,
      );

      verify(
        () => client.channel('participant-game:24:game_session:$_sessionId'),
      ).called(1);
      final filter =
          verify(
                () => channel.onPostgresChanges(
                  event: PostgresChangeEvent.insert,
                  schema: 'africlub_game',
                  table: 'game_events',
                  filter: captureAny(named: 'filter'),
                  callback: any(named: 'callback'),
                ),
              ).captured.single
              as PostgresChangeFilter;
      expect(filter.type, PostgresChangeFilterType.eq);
      expect(filter.column, 'topic');
      expect(filter.value, '24:game_session:$_sessionId');

      statusCallback!(RealtimeSubscribeStatus.closed, null);
      await Future<void>.delayed(Duration.zero);
      expect(errors, hasLength(1));
      expect(errors.single.toString(), isNot(contains(_sessionId)));

      await subscription.cancel();
      verify(() => client.removeChannel(channel)).called(1);

      statusCallback!(RealtimeSubscribeStatus.closed, null);
      await Future<void>.delayed(Duration.zero);
      expect(errors, hasLength(1));
    },
  );
}
