part of 'prediction_repository.dart';

extension PredictionRepoNotifications on PredictionRepository {
  Future<List<PredictionNotification>> loadNotifications({
    int limit = 50,
  }) async {
    return _cachedListQuery(
      cacheKey: _cacheKey('notifications', <Object?>[
        _client.auth.currentUser?.id ?? 'anonymous',
        limit,
      ]),
      ttl: _userCacheTtl,
      description: 'loadNotifications',
      request: () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('prediction_notifications_feed')
              .select()
              .order('created_at', ascending: false)
              .limit(limit),
        );

        return rows;
      },
      decoder: PredictionNotification.fromJson,
    );
  }
}
