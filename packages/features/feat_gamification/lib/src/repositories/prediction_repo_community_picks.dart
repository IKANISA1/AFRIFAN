part of 'prediction_repository.dart';

extension PredictionRepoCommunityPicks on PredictionRepository {


  Future<List<CommunityPick>> loadCommunityPicks(String fixtureMarketId) async {
    return _cachedListQuery(
      cacheKey: _cacheKey('community_market', <Object?>[fixtureMarketId]),
      ttl: _communityCacheTtl,
      description: 'loadCommunityPicks($fixtureMarketId)',
      request: () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('prediction_fixture_community')
              .select()
              .eq('fixture_market_id', fixtureMarketId)
              .order('pick_percentage', ascending: false),
        );

        return rows;
      },
      decoder: CommunityPick.fromJson,
    );
  }

  Future<List<CommunityPick>> loadFixtureCommunityPicks(
    String fixtureId,
  ) async {
    return _cachedListQuery(
      cacheKey: _cacheKey('community_fixture', <Object?>[fixtureId]),
      ttl: _communityCacheTtl,
      description: 'loadFixtureCommunityPicks($fixtureId)',
      request: () async {
        final rows = List<Map<String, dynamic>>.from(
          await _client
              .from('prediction_fixture_community')
              .select()
              .eq('fixture_id', fixtureId)
              .order('pick_percentage', ascending: false),
        );

        return rows;
      },
      decoder: CommunityPick.fromJson,
    );
  }


}
