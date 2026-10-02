import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/club_content_models.dart';
import 'club_content_gateway.dart';

/// Reads the standalone Gikundiro project's anonymous, approved public rows.
/// No member session or write credential crosses the two Supabase projects.
class GikundiroPublicClubGateway
    implements ClubContentGateway, ClubEntityGateway {
  GikundiroPublicClubGateway(this.source, this.otherContent);

  final SupabaseClient source;
  final ClubContentGateway otherContent;
  Future<String>? _clubIdFuture;

  Future<String> _clubId() => _clubIdFuture ??= _resolveClubId();

  Future<String> _resolveClubId() async {
    return gikundiroPublicClubId(source);
  }

  @override
  Future<ClubOverview?> loadOverview() async {
    final row = await source
        .from('clubs')
        .select('slug,name,short_name')
        .eq('slug', 'rayon-sports')
        .single();
    final name = (row['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    return ClubOverview(
      id: 24,
      name: name,
      country: 'Rwanda',
      league: 'Rwanda Premier League',
      slug: (row['slug'] ?? 'rayon-sports').toString(),
      nickname: (row['short_name'] ?? '').toString(),
    );
  }

  @override
  Future<List<ClubStandingItem>> loadStandings() =>
      otherContent.loadStandings();

  @override
  Future<List<ClubHistoryItem>> loadHistory() => otherContent.loadHistory();

  @override
  Future<List<ClubNewsItem>> loadNews() async {
    final now = DateTime.now().toUtc();
    final cutoff = DateTime.utc(
      now.year,
      now.month - 3,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
    final rows = await source
        .from('news_posts')
        .select(
          'id,title,excerpt,category,source_label,source_url,published_at',
        )
        .eq('club_id', await _clubId())
        .eq('approval_status', 'approved')
        .eq('active', true)
        .eq('visibility', 'public')
        .eq('status', 'published')
        .eq('post_type', 'news_feed')
        .gte('published_at', cutoff.toIso8601String())
        .lte('published_at', now.toIso8601String())
        .order('published_at', ascending: false)
        .limit(100);
    return rows.map(mapGikundiroNews).whereType<ClubNewsItem>().toList();
  }

  @override
  Future<ClubNewsItem?> loadArticle(String id) async {
    for (final item in await loadNews()) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<List<ClubSquadMember>> loadSquad() async {
    final clubId = await _clubId();
    final players = await source
        .from('players')
        .select(
          'id,display_name,squad_number,specific_position,position,'
          'nationality,short_bio,team,photo_asset_id',
        )
        .eq('club_id', clubId)
        .eq('approval_status', 'approved')
        .eq('active', true)
        .eq('visibility', 'public')
        .order('sort_order')
        .limit(100);
    final assetIds = players
        .map((row) => row['photo_asset_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final assets = assetIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await source
              .from('media_assets')
              .select('id,asset_url,usage_rights,usage_scopes')
              .eq('club_id', clubId)
              .eq('approval_status', 'approved')
              .eq('active', true)
              .eq('visibility', 'public')
              .inFilter('id', assetIds);
    final assetById = {
      for (final asset in assets) asset['id']?.toString(): asset,
    };
    return players
        .map(
          (row) => mapGikundiroPlayer(
            row,
            assetById[row['photo_asset_id']?.toString()],
          ),
        )
        .whereType<ClubSquadMember>()
        .toList();
  }

  @override
  Future<ClubSquadMember?> loadPlayer(String id) async {
    for (final player in await loadSquad()) {
      if (player.id == id) return player;
    }
    return null;
  }

  @override
  Future<List<ClubFixtureItem>> loadMatches() async {
    final clubId = await _clubId();
    final now = DateTime.now().toUtc();
    final results = await Future.wait([
      source
          .from('prediction_teams')
          .select('id,name,is_rayon_sports')
          .eq('club_id', clubId)
          .limit(500),
      source
          .from('prediction_competitions')
          .select('id,name')
          .eq('club_id', clubId)
          .eq('active', true)
          .limit(100),
      source
          .from('prediction_fixtures')
          .select(
            'id,competition_id,'
            'home_team_id,away_team_id,starts_at,venue,schedule_status,'
            'source_url,source_publication_id',
          )
          .eq('club_id', clubId)
          .eq('approval_status', 'approved')
          .eq('active', true)
          .eq('visibility', 'public')
          .eq('schedule_status', 'confirmed')
          .gt('starts_at', now.toIso8601String())
          .order('starts_at')
          .limit(500),
    ]);
    final teams = {for (final row in results[0]) row['id']?.toString(): row};
    final competitions = {
      for (final row in results[1]) row['id']?.toString(): row,
    };
    return results[2]
        .map((row) => mapGikundiroFixture(row, teams, competitions, now))
        .whereType<ClubFixtureItem>()
        .toList();
  }
}

ClubNewsItem? mapGikundiroNews(Map<String, dynamic> row) {
  final id = (row['id'] ?? '').toString().trim();
  final title = (row['title'] ?? '').toString().trim();
  final excerpt = (row['excerpt'] ?? '').toString().trim();
  final sourceUrl = _httpsUrl(row['source_url']);
  final published = DateTime.tryParse((row['published_at'] ?? '').toString());
  if (id.isEmpty ||
      title.isEmpty ||
      excerpt.isEmpty ||
      sourceUrl == null ||
      published == null ||
      published.isAfter(DateTime.now().toUtc())) {
    return null;
  }
  return ClubNewsItem(
    id: 'gikundiro-$id',
    title: title,
    subtitle: '',
    body: excerpt,
    category: (row['category'] ?? 'Club news').toString().trim(),
    author: (row['source_label'] ?? Uri.parse(sourceUrl).host)
        .toString()
        .trim(),
    publishedAt: published,
    sourceUrl: sourceUrl,
  );
}

ClubSquadMember? mapGikundiroPlayer(
  Map<String, dynamic> row,
  Map<String, dynamic>? asset,
) {
  final id = (row['id'] ?? '').toString().trim();
  final name = (row['display_name'] ?? '').toString().trim();
  if (id.isEmpty || name.isEmpty) return null;
  final scopes = asset?['usage_scopes'];
  final imageUrl =
      scopes is List &&
          scopes.contains('squad') &&
          (asset?['usage_rights'] ?? '').toString().trim().isNotEmpty
      ? _httpsUrl(asset?['asset_url'])
      : null;
  return ClubSquadMember(
    id: 'gikundiro-$id',
    name: name,
    position: (row['specific_position'] ?? row['position'] ?? '').toString(),
    shirtNumber: (row['squad_number'] as num?)?.toInt() ?? 0,
    nationality: (row['nationality'] ?? '').toString(),
    bio: (row['short_bio'] ?? '').toString(),
    imageUrl: imageUrl,
    squadGroup: (row['team'] ?? 'mens_first_team').toString(),
  );
}

ClubFixtureItem? mapGikundiroFixture(
  Map<String, dynamic> row,
  Map<String?, Map<String, dynamic>> teams,
  Map<String?, Map<String, dynamic>> competitions,
  DateTime now,
) {
  final id = (row['id'] ?? '').toString().trim();
  final kickoff = DateTime.tryParse((row['starts_at'] ?? '').toString());
  final home = teams[row['home_team_id']?.toString()];
  final away = teams[row['away_team_id']?.toString()];
  final competition = competitions[row['competition_id']?.toString()];
  if (id.isEmpty ||
      kickoff == null ||
      !kickoff.isAfter(now) ||
      row['schedule_status'] != 'confirmed' ||
      row['source_publication_id'] == null ||
      _httpsUrl(row['source_url']) == null ||
      (home?['is_rayon_sports'] != true && away?['is_rayon_sports'] != true) ||
      (home?['name'] ?? '').toString().trim().isEmpty ||
      (away?['name'] ?? '').toString().trim().isEmpty ||
      (competition?['name'] ?? '').toString().trim().isEmpty) {
    return null;
  }
  final local = kickoff.toLocal();
  return ClubFixtureItem(
    id: 'gikundiro-$id',
    homeTeam: home!['name'].toString(),
    awayTeam: away!['name'].toString(),
    competition: competition!['name'].toString(),
    venue: (row['venue'] ?? '').toString(),
    matchDate: kickoff,
    kickoffTime:
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
    status: 'scheduled',
    homeScore: 0,
    awayScore: 0,
    isOnSale: false,
  );
}

String? _httpsUrl(Object? value) {
  final url = Uri.tryParse((value ?? '').toString().trim());
  return url?.scheme == 'https' && url?.host.isNotEmpty == true
      ? url.toString()
      : null;
}
