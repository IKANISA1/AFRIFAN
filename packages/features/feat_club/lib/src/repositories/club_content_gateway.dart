import 'package:club_data/club_data.dart';
import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/club_content_models.dart';

abstract interface class ClubContentGateway {
  Future<ClubOverview?> loadOverview();

  Future<List<ClubNewsItem>> loadNews();

  Future<List<ClubSquadMember>> loadSquad();

  Future<List<ClubFixtureItem>> loadMatches();

  Future<List<ClubStandingItem>> loadStandings();

  Future<List<ClubHistoryItem>> loadHistory();

  Future<List<ClubProjectItem>> loadProjects();
}

abstract interface class ClubEntityGateway {
  Future<ClubSquadMember?> loadPlayer(String id);
  Future<ClubNewsItem?> loadArticle(String id);
}

/// Read-only club projection for the consumer Club route family.
///
/// Each query resolves the active tenant and applies the numeric club scope
/// before returning data. Publishing and mutation remain owned by governed
/// admin and contribution workflows.
class SupabaseClubContentGateway
    implements ClubContentGateway, ClubEntityGateway {
  SupabaseClubContentGateway(this._client)
    : _scopeResolver = ClubScopeResolver(client: _client);

  final SupabaseClient _client;
  final ClubScopeResolver _scopeResolver;

  @override
  Future<ClubSquadMember?> loadPlayer(String id) async {
    final clubId = await _requireClubId();
    final row = await _client
        .from('squad_players')
        .select(
          'id, name, position, shirt_number, nationality, bio, image_url, photo_url, squad_group',
        )
        .eq('club_id', clubId)
        .eq('is_active', true)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ClubSquadMember.fromJson(row);
  }

  @override
  Future<ClubNewsItem?> loadArticle(String id) async {
    final clubId = await _requireClubId();
    final row = await _client
        .from('news_articles')
        .select(
          'id,title,subtitle,body,category,author_name,published_at,image_url,image_provenance_id,image_rights_approved,source_url',
        )
        .eq('club_id', clubId)
        .eq('is_published', true)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ClubNewsItem.fromJson(row);
  }

  Future<int> _requireClubId() async {
    final scope = await _scopeResolver.requireResolved();
    final clubId = scope.clubId;
    if (clubId == null || clubId <= 0) {
      throw StateError('The active club could not be resolved.');
    }
    return clubId;
  }

  @override
  Future<ClubOverview?> loadOverview() async {
    final clubId = await _requireClubId();
    final row = await _client.rpc(
      'club_public_overview',
      params: {'p_club_id': clubId},
    );
    return row == null
        ? null
        : ClubOverview.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<List<ClubNewsItem>> loadNews() async {
    final clubId = await _requireClubId();
    final rows = await _client
        .from('news_articles')
        .select(
          'id, title, subtitle, body, category, author_name, '
          'published_at, image_url, image_provenance_id, image_rights_approved, source_url',
        )
        .eq('club_id', clubId)
        .eq('is_published', true)
        .order('published_at', ascending: false)
        .limit(50);
    final seen = <String>{};
    return rows
        .map(ClubNewsItem.fromJson)
        .where((article) => seen.add(article.sourceUrl ?? article.id))
        .toList(growable: false);
  }

  @override
  Future<List<ClubSquadMember>> loadSquad() async {
    final clubId = await _requireClubId();
    final rows = await _client
        .from('squad_players')
        .select(
          'id, name, position, shirt_number, nationality, bio, image_url, photo_url, squad_group',
        )
        .eq('club_id', clubId)
        .eq('is_active', true)
        .order('shirt_number', ascending: true)
        .limit(80);
    return rows.map(ClubSquadMember.fromJson).toList(growable: false);
  }

  @override
  Future<List<ClubFixtureItem>> loadMatches() async {
    final clubId = await _requireClubId();
    final rows = await PublicMatchWindow(_client).load(clubId: clubId);
    return rows.map(ClubFixtureItem.fromJson).toList(growable: false);
  }

  @override
  Future<List<ClubStandingItem>> loadStandings() async {
    final clubId = await _requireClubId();
    final rows = await _client
        .from('standings')
        .select(
          'id, position, club_name, club_slug, played, goal_difference, points',
        )
        .eq('club_id', clubId)
        .eq('is_active', true)
        .order('position', ascending: true)
        .limit(40);
    return rows.map(ClubStandingItem.fromJson).toList(growable: false);
  }

  @override
  Future<List<ClubHistoryItem>> loadHistory() async {
    final clubId = await _requireClubId();
    final rows =
        await _client.rpc('club_public_history', params: {'p_club_id': clubId})
            as List;
    return rows
        .map(
          (row) =>
              ClubHistoryItem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<ClubProjectItem>> loadProjects() async {
    final clubId = await _requireClubId();
    final rows = await _client
        .from('contribution_groups')
        .select(
          'id, name, description, current_total, target_amount, member_count',
        )
        .eq('club_id', clubId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(30);
    return rows.map(ClubProjectItem.fromJson).toList(growable: false);
  }
}
