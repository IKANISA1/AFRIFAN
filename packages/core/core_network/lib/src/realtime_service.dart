import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client_factory.dart';

/// Realtime service for club-scoped channel subscriptions.
///
/// Channel name format: {club_id}:{feature}:{resource_id}
/// Topic names organize subscriptions; they do not authorize access. Postgres
/// changes are authorized by the table's grants and row-level policies.
class RealtimeService {
  RealtimeService({required this.clubId, SupabaseClient? client})
    : _client = client;

  final String clubId;
  final SupabaseClient? _client;
  final Set<RealtimeChannel> _activeChannels = <RealtimeChannel>{};

  SupabaseClient get client => _client ?? SupabaseClientFactory.client;

  @visibleForTesting
  int get activeChannelCount => _activeChannels.length;

  /// Subscribe to a club-scoped channel.
  ///
  /// The returned channel is already subscribed — callers do not need to
  /// call `.subscribe()` again.
  RealtimeChannel subscribe({
    required String feature,
    required String resourceId,
  }) {
    final channelName = '$clubId:$feature:$resourceId';
    final channel = client.channel(channelName);
    _activeChannels.add(channel);
    channel.subscribe();
    return channel;
  }

  /// Subscribe to postgres changes on a table, filtered by club_id.
  RealtimeChannel onTableChanges({
    String schema = 'public',
    required String table,
    required String filterColumn,
    required String filterValue,
    required void Function(PostgresChangePayload payload) callback,
    VoidCallback? onSubscribed,
  }) {
    final resource = schema == 'public' ? table : '$schema.$table';
    final channelName = '$clubId:$resource:$filterValue';

    final channel = client.channel(channelName);
    _activeChannels.add(channel);
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: schema,
      table: table,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: filterColumn,
        value: filterValue,
      ),
      callback: callback,
    );

    if (onSubscribed == null) {
      channel.subscribe();
    } else {
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed &&
            _activeChannels.contains(channel)) {
          onSubscribed();
        }
      });
    }
    return channel;
  }

  /// Unsubscribe a single tracked channel and remove it from the local registry.
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel == null) {
      return;
    }
    _activeChannels.remove(channel);
    await channel.unsubscribe();
  }

  /// Unsubscribe every tracked channel owned by this service instance.
  Future<void> dispose() async {
    if (_activeChannels.isEmpty) {
      return;
    }

    final channels = List<RealtimeChannel>.from(_activeChannels);
    _activeChannels.clear();
    await Future.wait(channels.map((channel) => channel.unsubscribe()));
  }
}
