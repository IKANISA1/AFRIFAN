import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockRealtimeChannel extends Mock implements RealtimeChannel {}

void main() {
  setUpAll(() {
    registerFallbackValue(PostgresChangeEvent.all);
    registerFallbackValue(
      PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: 'fixture-9',
      ),
    );
  });

  group('RealtimeService', () {
    late _MockSupabaseClient client;
    late _MockRealtimeChannel scopedChannel;
    late _MockRealtimeChannel tableChannel;
    late RealtimeService service;

    setUp(() {
      client = _MockSupabaseClient();
      scopedChannel = _MockRealtimeChannel();
      tableChannel = _MockRealtimeChannel();
      service = RealtimeService(clubId: '24', client: client);

      when(
        () => client.channel(any()),
      ).thenAnswer((invocation) {
        final name = invocation.positionalArguments.first as String;
        if (name == '24:matches:fixture-9') {
          return tableChannel;
        }
        return scopedChannel;
      });

      when(
        () => tableChannel.onPostgresChanges(
          event: any(named: 'event'),
          schema: any(named: 'schema'),
          table: any(named: 'table'),
          filter: any(named: 'filter'),
          callback: any(named: 'callback'),
        ),
      ).thenReturn(tableChannel);

      when(() => tableChannel.subscribe()).thenReturn(tableChannel);
      when(() => scopedChannel.unsubscribe()).thenAnswer((_) async => 'ok');
      when(() => tableChannel.unsubscribe()).thenAnswer((_) async => 'ok');
    });

    test('tracks club-scoped channels it creates', () {
      final channel = service.subscribe(
        feature: 'live',
        resourceId: 'fixture-1',
      );

      expect(channel, same(scopedChannel));
      expect(service.activeChannelCount, 1);
      verify(() => client.channel('24:live:fixture-1')).called(1);
    });

    test('onTableChanges subscribes and tracks the created channel', () {
      final channel = service.onTableChanges(
        table: 'matches',
        filterColumn: 'id',
        filterValue: 'fixture-9',
        callback: (_) {},
      );

      expect(channel, same(tableChannel));
      expect(service.activeChannelCount, 1);
      verify(() => client.channel('24:matches:fixture-9')).called(1);
      verify(
        () => tableChannel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          filter: any(named: 'filter'),
          callback: any(named: 'callback'),
        ),
      ).called(1);
      verify(() => tableChannel.subscribe()).called(1);
    });

    test('unsubscribe removes a channel from the registry', () async {
      final channel = service.subscribe(feature: 'live', resourceId: 'fixture-1');

      await service.unsubscribe(channel);

      expect(service.activeChannelCount, 0);
      verify(() => scopedChannel.unsubscribe()).called(1);
    });

    test('dispose unsubscribes every tracked channel once', () async {
      service.subscribe(feature: 'live', resourceId: 'fixture-1');
      service.onTableChanges(
        table: 'matches',
        filterColumn: 'id',
        filterValue: 'fixture-9',
        callback: (_) {},
      );

      await service.dispose();

      expect(service.activeChannelCount, 0);
      verify(() => scopedChannel.unsubscribe()).called(1);
      verify(() => tableChannel.unsubscribe()).called(1);
    });
  });
}
