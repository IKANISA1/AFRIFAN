import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client_factory.dart';

/// Realtime service for club-scoped channel subscriptions.
///
/// Channel name format: {club_id}:{feature}:{resource_id}
/// RLS on Realtime: channel topic validated server-side.
class RealtimeService {
  final String clubId;

  RealtimeService({required this.clubId});

  SupabaseClient get _client => SupabaseClientFactory.client;

  /// Subscribe to a club-scoped channel.
  RealtimeChannel subscribe({
    required String feature,
    required String resourceId,
  }) {
    final channelName = '$clubId:$feature:$resourceId';
    return _client.channel(channelName);
  }

  /// Subscribe to postgres changes on a table, filtered by club_id.
  RealtimeChannel onTableChanges({
    required String table,
    required String filterColumn,
    required String filterValue,
    required void Function(PostgresChangePayload payload) callback,
  }) {
    final channelName = '$clubId:$table:$filterValue';

    final channel = _client.channel(channelName);
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: filterColumn,
        value: filterValue,
      ),
      callback: callback,
    );

    channel.subscribe();
    return channel;
  }
}
