import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feature_management_repository.dart';

/// Admin repository for club-scoped management queries.
///
/// All queries are gated behind RLS + `is_club_admin(club_id)` on the server
/// side. The Flutter layer provides the convenience API.
class AdminRepository {
  AdminRepository({required SupabaseClient client}) : _client = client;

  static const _preferredNewsTable = 'news_articles';
  static const _fallbackNewsTable = 'news_articles';

  final SupabaseClient _client;
  late final ClubScopeResolver _scopeResolver = ClubScopeResolver(
    client: _client,
  );
  late final FeatureManagementRepository _featureManagementRepository =
      FeatureManagementRepository(client: _client);

  // ── RBAC Check ──

  /// Returns true if the current user has admin access for their active club.
  Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    final userId = user?.id;
    if (userId == null) {
      return false;
    }

    try {
      final currentClubId = _scopeResolver.currentClubId;
      final assignments = List<Map<String, dynamic>>.from(
        await _client
            .from('admin_role_assignments')
            .select('role, club_id, is_active')
            .eq('user_id', userId)
            .eq('is_active', true),
      );

      if (assignments.any(
        (row) => _assignmentMatchesClub(row, currentClubId),
      )) {
        return true;
      }
    } catch (e) {
      AfriLogger.warn('AdminRepository', 'Admin role check failed: $e');
    }

    // app_metadata is server-controlled. Never authorize from user_metadata:
    // authenticated users can update that client-owned field themselves.
    final role = user?.appMetadata['role']?.toString().toLowerCase();
    return _isAdminRole(role);
  }

  /// Returns true if the current user is a platform super admin.
  Future<bool> isCurrentUserSuperAdmin() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }

      final assignments = List<Map<String, dynamic>>.from(
        await _client
            .from('admin_role_assignments')
            .select('role, is_active')
            .eq('user_id', userId)
            .eq('is_active', true),
      );
      if (assignments.any(
        (row) => _normalizeRole(row['role']) == 'super_admin',
      )) {
        return true;
      }

      final result = await _client.rpc('is_super_admin');
      return result == true;
    } catch (e) {
      AfriLogger.warn('AdminRepository', 'Super admin check failed: $e');
      return false;
    }
  }

  // ── Dashboard Metrics ──

  /// Returns key metrics for the admin dashboard.
  Future<AdminDashboardMetrics> getDashboardMetrics({String? clubId}) async {
    try {
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final scope = await _scopeResolver.resolve(clubId);

      var usersQuery = _client.from('profiles').select('id');
      usersQuery = _scopeResolver.apply(usersQuery, scope);
      final usersResult = await usersQuery.count(CountOption.exact);

      var groupsQuery = _client
          .from('contribution_groups')
          .select('id')
          .eq('is_closed', false);
      groupsQuery = _scopeResolver.apply(groupsQuery, scope);
      final groupsResult = await groupsQuery.count(CountOption.exact);

      final txCount = await _countTransactionsToday(
        startOfDay,
        endOfDay,
        scope,
      );
      final ticketsCount = await _countTicketsSold(scope);

      return AdminDashboardMetrics(
        totalUsers: usersResult.count,
        activeGroups: groupsResult.count,
        transactionsToday: txCount,
        ticketsSold: ticketsCount,
      );
    } catch (e) {
      AfriLogger.error('AdminRepository', 'Dashboard metrics failed', e);
      rethrow;
    }
  }

  Future<int> _countTransactionsToday(
    DateTime startOfDay,
    DateTime endOfDay,
    ClubScope scope,
  ) async {
    var groupsQuery = _client.from('contribution_groups').select('id');
    groupsQuery = _scopeResolver.apply(groupsQuery, scope);
    final groupRows = List<Map<String, dynamic>>.from(
      (await groupsQuery as List).map(
        (row) => Map<String, dynamic>.from(row as Map),
      ),
    );
    final groupIds = groupRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (groupIds.isEmpty) {
      return 0;
    }

    final result = await _client
        .from('group_contributions')
        .select('id')
        .inFilter('group_id', groupIds)
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', endOfDay.toIso8601String())
        .count(CountOption.exact);
    return result.count;
  }

  Future<int> _countTicketsSold(ClubScope scope) async {
    try {
      var query = _client.from('tickets').select('id');
      query = _scopeResolver.apply(query, scope);
      final result = await query.count(CountOption.exact);
      return result.count;
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) {
        return 0;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getManagedMatches({
    int limit = 200,
  }) async {
    final boundedLimit = limit.clamp(1, 200);
    final data = await _client
        .from('matches')
        .select(
          'id, partner_id, home_team, away_team, competition, venue, '
          'match_date, kickoff_time, is_on_sale, ticket_general_price, '
          'ticket_vip_price, capacity, sold_count, match_status, home_score, '
          'away_score, live_minute, match_summary',
        )
        .order('match_date', ascending: true)
        .limit(boundedLimit);
    return List<Map<String, dynamic>>.from(
      (data as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );
  }

  Future<void> createManagedMatch(Map<String, dynamic> values) async {
    await _client.from('matches').insert(values);
  }

  Future<void> updateManagedMatch(
    String matchId,
    Map<String, dynamic> values,
  ) async {
    await _client.from('matches').update(values).eq('id', matchId);
  }

  Future<Map<String, List<Map<String, dynamic>>>>
  getAdminNotificationContext() async {
    final scope = await _scopeResolver.requireResolved();
    var groupsQuery = _client
        .from('contribution_groups')
        .select('id, name')
        .eq('is_closed', false);
    groupsQuery = _scopeResolver.apply(groupsQuery, scope);
    var historyQuery = _client
        .from('notifications')
        .select(
          'id, title, body, audience_type, audience_tier, audience_group_name, '
          'delivery_mode, status, scheduled_at, sent_at, '
          'requested_recipient_count, sent_count, failed_count, created_at',
        );
    historyQuery = _scopeResolver.apply(historyQuery, scope);
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      groupsQuery.order('name', ascending: true).limit(50),
      historyQuery.order('created_at', ascending: false).limit(100),
    ]);
    return <String, List<Map<String, dynamic>>>{
      'groups': List<Map<String, dynamic>>.from(
        (results[0] as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
      ),
      'history': List<Map<String, dynamic>>.from(
        (results[1] as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
      ),
    };
  }

  Future<List<Map<String, dynamic>>> getPredictionSettlementFixtures({
    int limit = 100,
  }) async {
    final boundedLimit = limit.clamp(1, 100);
    final data = await _client
        .schema('football')
        .from('fixtures')
        .select(
          'id, status, stage_name, group_name, kickoff_at, venue_city, '
          'home_score, away_score, '
          'home_team:teams!fixtures_home_team_id_fkey(id, name, short_name), '
          'away_team:teams!fixtures_away_team_id_fkey(id, name, short_name), '
          'competition:competitions!fixtures_competition_id_fkey('
          'id, name, short_name)',
        )
        .order('kickoff_at', ascending: true)
        .limit(boundedLimit);
    return List<Map<String, dynamic>>.from(
      (data as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>>
  getAdminSmsMonitorWorkspace() async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _client.rpc('get_momo_sms_operational_summary'),
      _client
          .from('momo_sms_sync_runs')
          .select(
            'id, status, trigger, scanned_messages, uploaded_messages, '
            'duplicate_messages, scan_started_at, scan_completed_at',
          )
          .order('scan_started_at', ascending: false)
          .limit(50),
    ]);
    return <String, List<Map<String, dynamic>>>{
      'metrics': List<Map<String, dynamic>>.from(
        (results[0] as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
      ),
      'runs': List<Map<String, dynamic>>.from(
        (results[1] as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
      ),
    };
  }

  bool _assignmentMatchesClub(Map<String, dynamic> row, int? currentClubId) {
    final role = _normalizeRole(row['role']);
    final assignmentClubId = _asInt(row['club_id']);
    if (role == 'super_admin' || role == 'admin') {
      return true;
    }
    if (role != 'club_admin' && role != 'club_moderator') {
      return false;
    }
    return currentClubId == null || assignmentClubId == currentClubId;
  }

  bool _isAdminRole(String? role) {
    return switch (_normalizeRole(role)) {
      'admin' || 'super_admin' || 'club_admin' || 'club_moderator' => true,
      _ => false,
    };
  }

  /// Uses only server-controlled JWT app metadata for high-risk admin
  /// workspaces. Client-writable user metadata is intentionally ignored.
  Future<bool> isCurrentUserAppMetadataAdmin() async {
    final role = _client.auth.currentUser?.appMetadata['role']
        ?.toString()
        .trim()
        .toLowerCase();
    return _isAdminRole(role);
  }

  /// Platform-wide operational monitoring must not be exposed to a
  /// club-scoped moderator or administrator.
  Future<bool> isCurrentUserAppMetadataPlatformAdmin() async {
    final role = _client.auth.currentUser?.appMetadata['role']
        ?.toString()
        .trim()
        .toLowerCase();
    return role == 'admin' || role == 'super_admin';
  }

  String? _normalizeRole(dynamic value) {
    final role = value?.toString().trim().toLowerCase();
    return role == null || role.isEmpty ? null : role;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }

  Map<String, dynamic> _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry('$key', val));
    }
    return const <String, dynamic>{};
  }

  // ── Contribution Groups ──

  /// Returns all contribution groups for the club (admin view — all groups).
  Future<List<Map<String, dynamic>>> getContributionGroups({
    int limit = 50,
    int offset = 0,
  }) async {
    final scope = await _scopeResolver.resolve(null);
    var query = _client
        .from('contribution_groups')
        .select(
          'id, name, description, group_type, '
          'target_amount, current_total, member_count, '
          'is_closed, creator_id, created_at',
        );
    query = _scopeResolver.apply(query, scope);
    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Returns contributions for a specific group.
  Future<List<Map<String, dynamic>>> getGroupContributions(
    String groupId, {
    int limit = 100,
  }) async {
    final data = await _client
        .from('group_contributions')
        .select('id, user_id, amount, status, momo_reference, created_at')
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(
      (data as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );
  }

  /// Returns the bounded, privacy-minimized records used by the contribution
  /// monitor. Supporter identifiers and payment references are not selected.
  Future<List<Map<String, dynamic>>> getContributionMonitorRecords(
    List<String> groupIds, {
    int limit = 500,
  }) async {
    if (groupIds.isEmpty || groupIds.length > 200) {
      throw const FormatException('Invalid contribution group scope.');
    }
    if (limit < 1 || limit > 500) {
      throw const FormatException('Invalid contribution monitor limit.');
    }
    final data = await _client
        .from('group_contributions')
        .select('id, group_id, amount, status, created_at')
        .inFilter('group_id', groupIds)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(
      (data as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );
  }

  // ── News / CMS ──

  /// Returns all news articles (including unpublished — admin view).
  Future<List<Map<String, dynamic>>> getNewsArticles({
    int limit = 50,
    int offset = 0,
  }) async {
    final newsTable = await _resolveNewsTable();
    final scope = await _scopeResolver.resolve(null);
    var query = _client.from(newsTable).select('*');
    query = _scopeResolver.apply(query, scope);
    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Creates a new news article.
  Future<Map<String, dynamic>> createNewsArticle({
    required String title,
    int? clubId,
    String? subtitle,
    String? body,
    String category = 'News',
    bool isPublished = false,
    bool isFeatured = false,
    String? imageUrl,
    DateTime? publishedAt,
    int sortOrder = 0,
  }) async {
    final newsTable = await _resolveNewsTable();
    final effectiveClubId = clubId ?? _scopeResolver.currentClubId;
    final data = await _client
        .from(newsTable)
        .insert({
          if (effectiveClubId != null) 'club_id': effectiveClubId,
          'title': title,
          'subtitle': subtitle,
          'body': body,
          'category': category,
          'image_url': imageUrl,
          'is_published': isPublished,
          'is_featured': isFeatured,
          'sort_order': sortOrder,
          if (publishedAt != null)
            'published_at': publishedAt.toUtc().toIso8601String()
          else if (isPublished)
            'published_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  /// Updates a news article.
  Future<void> updateNewsArticle(
    String articleId,
    Map<String, dynamic> updates,
  ) async {
    final newsTable = await _resolveNewsTable();
    final scope = await _scopeResolver.resolve(null);
    var query = _client.from(newsTable).update(updates).eq('id', articleId);
    query = _scopeResolver.apply(query, scope);
    await query;
  }

  // ── Dynamic Home / Partner Catalogs ──

  Future<List<Map<String, dynamic>>> getQuickActions({int limit = 50}) async {
    final data = await _client
        .from('quick_actions')
        .select('*')
        .order('sort_order', ascending: true)
        .order('title', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> createQuickAction({
    required String actionKey,
    required String title,
    required String route,
    required String iconKey,
    String? subtitle,
    String? emoji,
    String? countryCode,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final data = await _client
        .from('quick_actions')
        .insert({
          'action_key': actionKey,
          'title': title,
          'subtitle': subtitle,
          'route': route,
          'icon_key': iconKey,
          'emoji': emoji,
          'country': countryCode,
          'sort_order': sortOrder,
          'is_active': isActive,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updateQuickAction(
    String quickActionId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('quick_actions').update(updates).eq('id', quickActionId);
  }

  Future<List<Map<String, dynamic>>> getPartners({int limit = 100}) async {
    final data = await _client
        .from('partners')
        .select('*')
        .order('sort_order', ascending: true)
        .order('name', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> createPartner({
    required String name,
    required String slug,
    required String category,
    required String countryCode,
    String? emoji,
    String? subtitle,
    String? description,
    bool isActive = true,
    bool gamificationEnabled = false,
    int sortOrder = 0,
  }) async {
    final data = await _client
        .from('partners')
        .insert({
          'name': name,
          'slug': slug,
          'category': category,
          'country': countryCode,
          'emoji': emoji,
          'subtitle': subtitle,
          'description': description,
          'is_active': isActive,
          'sort_order': sortOrder,
          'gamification_enabled': gamificationEnabled,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updatePartner(
    String partnerId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('partners').update(updates).eq('id', partnerId);
  }

  Future<List<Map<String, dynamic>>> getPartnerServices({
    int limit = 200,
  }) async {
    final data = await _client
        .from('partner_services')
        .select('*, partner:partners(id, name, slug)')
        .order('sort_order', ascending: true)
        .order('title', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> createPartnerService({
    required String partnerId,
    required String title,
    required String serviceSlug,
    String category = 'general',
    String? subtitle,
    String? emoji,
    String? ctaLabel,
    String? ctaAction,
    String? countryCode,
    int sortOrder = 0,
    bool isActive = true,
    bool gamificationEnabled = false,
  }) async {
    final data = await _client
        .from('partner_services')
        .insert({
          'partner_id': partnerId,
          'title': title,
          'service_slug': serviceSlug,
          'subtitle': subtitle,
          'emoji': emoji,
          'category': category,
          'cta_label': ctaLabel,
          'cta_action': ctaAction,
          'country': countryCode,
          'sort_order': sortOrder,
          'is_active': isActive,
          'gamification_enabled': gamificationEnabled,
        })
        .select('*, partner:partners(id, name, slug)')
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updatePartnerService(
    String serviceId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('partner_services').update(updates).eq('id', serviceId);
  }

  Future<List<Map<String, dynamic>>> getFootballCompetitions({
    int limit = 200,
  }) async {
    final data = await _client
        .from('football_competitions_catalog')
        .select('*')
        .eq('is_active', true)
        .order('name', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> getManagedFootballCompetitions({
    int limit = 200,
  }) async {
    final boundedLimit = limit.clamp(1, 200);
    final data = await _client
        .schema('football')
        .from('competitions')
        .select(
          'id, slug, name, short_name, competition_kind, region, '
          'country_code, country_name, organizer, gender, format_notes, '
          'is_active',
        )
        .order('name', ascending: true)
        .limit(boundedLimit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> getManagedFootballSeasons({
    int limit = 300,
  }) async {
    final boundedLimit = limit.clamp(1, 300);
    final data = await _client
        .schema('football')
        .from('seasons')
        .select(
          'id, competition_id, slug, label, year_start, year_end, '
          'status, is_active',
        )
        .order('year_start', ascending: false)
        .limit(boundedLimit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> createManagedFootballCompetition(
    Map<String, dynamic> values,
  ) async {
    await _client.schema('football').from('competitions').insert(values);
  }

  Future<void> updateManagedFootballCompetition(
    String competitionId,
    Map<String, dynamic> values,
  ) async {
    await _client
        .schema('football')
        .from('competitions')
        .update(values)
        .eq('id', competitionId);
  }

  Future<void> createManagedFootballSeason(Map<String, dynamic> values) async {
    await _client.schema('football').from('seasons').insert(values);
  }

  Future<void> updateManagedFootballSeason(
    String seasonId,
    Map<String, dynamic> values,
  ) async {
    await _client
        .schema('football')
        .from('seasons')
        .update(values)
        .eq('id', seasonId);
  }

  Future<List<Map<String, dynamic>>> getPredictionSupportedCompetitions({
    int limit = 200,
  }) async {
    final data = await _client
        .from('prediction_supported_competitions_catalog')
        .select('*')
        .order('support_sort_order', ascending: true)
        .order('name', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> createPredictionSupportedCompetition({
    required String competitionId,
    String? highlightLabel,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final data = await _client
        .from('prediction_supported_competitions')
        .insert({
          'competition_id': competitionId,
          'highlight_label': highlightLabel,
          'sort_order': sortOrder,
          'is_active': isActive,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updatePredictionSupportedCompetition(
    String supportId,
    Map<String, dynamic> updates,
  ) async {
    await _client
        .from('prediction_supported_competitions')
        .update(updates)
        .eq('id', supportId);
  }

  // ── Platform Features ──

  /// Returns all platform features for registry management.
  Future<List<Map<String, dynamic>>> getPlatformFeatures({
    int limit = 100,
  }) async {
    final features = await _featureManagementRepository.loadAllFeatures();
    return features
        .take(limit)
        .map(_serializeManagedFeature)
        .toList(growable: false);
  }

  // ── Platform Content Blocks ──

  /// Returns all platform content blocks (homepage sections, banners, etc.).
  Future<List<Map<String, dynamic>>> getPlatformContentBlocks({
    int limit = 100,
  }) async {
    final scopedClubId = _scopeResolver.currentClubId;
    var query = _client
        .from('platform_content_blocks')
        .select(
          'id, club_id, block_key, block_type, title, subtitle, content, '
          'target_channel, placement_key, feature_id, is_active, sort_order, '
          'metadata, created_at, updated_at, '
          'feature:platform_features(id, feature_key, display_name)',
        );
    if (scopedClubId != null) {
      query = query.or('club_id.eq.$scopedClubId,club_id.is.null');
    } else {
      query = query.isFilter('club_id', null);
    }
    final data = await query
        .order('placement_key', ascending: true)
        .order('sort_order', ascending: true, nullsFirst: false);
    final rows = List<Map<String, dynamic>>.from(
      (data as List).map((row) => Map<String, dynamic>.from(row as Map)),
    );
    return _resolveScopedPlatformContentBlocks(
      rows,
      scopedClubId,
    ).take(limit).toList(growable: false);
  }

  /// Creates a new platform content block.
  Future<Map<String, dynamic>> createPlatformContentBlock({
    required String blockKey,
    required String blockType,
    required String targetChannel,
    required String placementKey,
    String? title,
    String? subtitle,
    Map<String, dynamic> content = const <String, dynamic>{},
    String? featureId,
    int? sortOrder,
    bool isActive = true,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final scopedClubId = _scopeResolver.currentClubId;
    final data = await _client
        .from('platform_content_blocks')
        .insert({
          if (scopedClubId != null) 'club_id': scopedClubId,
          'block_key': blockKey,
          'block_type': blockType,
          'title': title,
          'subtitle': subtitle,
          'content': content,
          'target_channel': targetChannel,
          'placement_key': placementKey,
          'feature_id': featureId,
          'is_active': isActive,
          'sort_order': sortOrder,
          'metadata': metadata,
        })
        .select('*, feature:platform_features(id, feature_key, display_name)')
        .single();
    return Map<String, dynamic>.from(data);
  }

  /// Updates a platform content block.
  Future<void> updatePlatformContentBlock(
    String blockId,
    Map<String, dynamic> updates,
  ) async {
    final scopedClubId = _scopeResolver.currentClubId;
    final source = await _getPlatformContentBlockRowById(blockId);
    final targetId = await _ensureScopedPlatformContentBlockTarget(
      source,
      clubId: scopedClubId,
    );
    final payload = Map<String, dynamic>.from(updates)
      ..remove('id')
      ..remove('feature')
      ..remove('club_id');
    if (payload.containsKey('content')) {
      payload['content'] = _asJsonMap(payload['content']);
    }
    if (payload.containsKey('metadata')) {
      payload['metadata'] = _asJsonMap(payload['metadata']);
    }
    await _client
        .from('platform_content_blocks')
        .update(payload)
        .eq('id', targetId);
  }

  // ── Platform Feature Audit Logs ──

  /// Returns recent feature management audit logs.
  Future<List<Map<String, dynamic>>> getPlatformFeatureAuditLogs({
    int limit = 50,
  }) async {
    final data = await _client
        .from('platform_feature_audit_logs')
        .select('*, feature:platform_features(id, feature_key, display_name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Map<String, dynamic> _serializeManagedFeature(
    ManagedPlatformFeature feature,
  ) {
    return <String, dynamic>{
      'id': feature.id,
      'club_id': feature.clubId,
      'feature_key': feature.featureKey,
      'display_name': feature.displayName,
      'description': feature.description,
      'category': feature.category,
      'is_enabled': feature.isEnabled,
      'visibility_state': feature.visibilityState,
      'channels': feature.channels
          .map(
            (channel) => <String, dynamic>{
              'id': channel.id,
              'channel': channel.channel,
              'is_enabled': channel.isEnabled,
              'is_visible': channel.isVisible,
              'show_in_navigation': channel.showInNavigation,
              'show_on_home': channel.showOnHome,
              'sort_order': channel.sortOrder,
              'route_key': channel.routeKey,
              'placement_key': channel.placementKey,
            },
          )
          .toList(growable: false),
      'rules': feature.rules == null
          ? const <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[
              <String, dynamic>{
                'id': feature.rules!.id,
                'auth_required': feature.rules!.authRequired,
                'role_restrictions': feature.rules!.roleRestrictions,
                'dependency_rules': feature.rules!.dependencyRules,
                'rollout_rules': feature.rules!.rolloutRules,
                'metadata': feature.rules!.metadata,
                'schedule_start_at': feature.rules!.scheduleStartAt
                    ?.toIso8601String(),
                'schedule_end_at': feature.rules!.scheduleEndAt
                    ?.toIso8601String(),
              },
            ],
    };
  }

  Future<Map<String, dynamic>> _getPlatformContentBlockRowById(
    String blockId,
  ) async {
    final data = await _client
        .from('platform_content_blocks')
        .select(
          'id, club_id, block_key, block_type, title, subtitle, content, '
          'target_channel, placement_key, feature_id, is_active, sort_order, '
          'metadata, created_at, updated_at',
        )
        .eq('id', blockId)
        .single();
    return Map<String, dynamic>.from(data as Map);
  }

  Future<String> _ensureScopedPlatformContentBlockTarget(
    Map<String, dynamic> source, {
    required int? clubId,
  }) async {
    final sourceClubId = _asInt(source['club_id']);
    if (clubId == null || sourceClubId == clubId) {
      return source['id']?.toString() ?? '';
    }

    final blockKey = source['block_key']?.toString() ?? '';
    final existing = await _client
        .from('platform_content_blocks')
        .select('id')
        .eq('block_key', blockKey)
        .eq('club_id', clubId)
        .maybeSingle();
    final existingId = existing?['id']?.toString();
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    final inserted = await _client
        .from('platform_content_blocks')
        .insert(<String, dynamic>{
          'club_id': clubId,
          'block_key': blockKey,
          'block_type': source['block_type'],
          'title': source['title'],
          'subtitle': source['subtitle'],
          'content': _asJsonMap(source['content']),
          'target_channel': source['target_channel'],
          'placement_key': source['placement_key'],
          'feature_id': source['feature_id'],
          'is_active': source['is_active'] as bool? ?? true,
          'sort_order': (source['sort_order'] as num?)?.toInt(),
          'metadata': _asJsonMap(source['metadata']),
        })
        .select('id')
        .single();
    final targetId = inserted['id']?.toString() ?? '';
    if (targetId.isEmpty) {
      throw StateError('Could not create scoped content-block override.');
    }
    return targetId;
  }

  List<Map<String, dynamic>> _resolveScopedPlatformContentBlocks(
    List<Map<String, dynamic>> rows,
    int? clubId,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = row['block_key']?.toString() ?? '';
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(row);
    }

    final resolved = grouped.values
        .map((variants) {
          if (clubId == null) {
            return variants.firstWhere(
              (row) => row['club_id'] == null,
              orElse: () => variants.first,
            );
          }

          for (final row in variants) {
            if (_asInt(row['club_id']) == clubId) {
              return row;
            }
          }

          for (final row in variants) {
            if (row['club_id'] == null) {
              return row;
            }
          }

          return variants.first;
        })
        .toList(growable: false);

    resolved.sort((left, right) {
      final placementCompare = (left['placement_key']?.toString() ?? '')
          .compareTo(right['placement_key']?.toString() ?? '');
      if (placementCompare != 0) {
        return placementCompare;
      }
      return ((left['sort_order'] as num?)?.toInt() ?? 999).compareTo(
        (right['sort_order'] as num?)?.toInt() ?? 999,
      );
    });

    return resolved;
  }

  // ── Shop Products ──

  /// Returns all shop products (admin view — includes inactive).
  Future<List<Map<String, dynamic>>> getShopProducts({int limit = 50}) async {
    final scope = await _scopeResolver.resolve(null);
    var query = _client.from('shop_products').select('*');
    query = _scopeResolver.apply(query, scope);
    final data = await query.order('sort_order').limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ── Recent Activity ──

  /// Returns recent admin audit log entries.
  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 10}) async {
    try {
      final scope = await _scopeResolver.resolve(null);
      var query = _client
          .from('admin_audit_log')
          .select('id, action, entity_type, entity_id, metadata, created_at');
      query = _scopeResolver.apply(query, scope);
      final data = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      AfriLogger.warn('AdminRepository', 'Audit log query failed: $e');
      return [];
    }
  }

  /// Returns recent news titles for dashboard feed.
  Future<List<String>> getRecentNewsTitles({int limit = 3}) async {
    final newsTable = await _resolveNewsTable();
    final scope = await _scopeResolver.resolve(null);
    var query = _client.from(newsTable).select('title');
    query = _scopeResolver.apply(query, scope);
    final data = await query
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 10));
    return (data as List)
        .map((item) => item['title']?.toString().trim() ?? '')
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getPredictionChallenges({
    List<String>? statuses,
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    if (offset < 0) {
      throw RangeError.range(offset, 0, null, 'offset');
    }
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      throw StateError('Admin access required.');
    }

    final result = await SafeRpc.call(
      'prediction_admin_get_challenges',
      params: <String, dynamic>{
        'p_club_id': scope.clubId,
        'p_statuses': statuses,
        'p_limit': limit,
        'p_offset': offset,
      },
      tag: 'AdminChallenges',
    );

    if (!result.isSuccess) {
      throw StateError(result.error ?? 'Challenge operations unavailable.');
    }
    if (result.data is! List) {
      throw const FormatException('Invalid challenge operations response.');
    }

    return (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> retryPredictionChallengeSettlement(
    String challengeId,
  ) async {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(challengeId)) {
      throw const FormatException('Invalid challenge identifier.');
    }
    final result = await SafeRpc.call(
      'prediction_challenge_admin_retry_settlement',
      params: <String, dynamic>{'p_challenge_id': challengeId},
      tag: 'AdminChallenges',
      maxAttempts: 1,
    );

    if (!result.isSuccess) {
      throw StateError(result.error ?? 'Settlement retry unavailable.');
    }
    if (result.data is! Map) {
      throw const FormatException('Invalid settlement retry response.');
    }

    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<String> _resolveNewsTable() async {
    for (final table in const [_preferredNewsTable, _fallbackNewsTable]) {
      try {
        await _client.from(table).select('id').limit(1);
        return table;
      } on PostgrestException catch (error) {
        if (!_isMissingTable(error) || table == _fallbackNewsTable) {
          rethrow;
        }
      }
    }

    return _fallbackNewsTable;
  }

  bool _isMissingTable(PostgrestException error) {
    return error.code == 'PGRST205';
  }

  Future<Map<String, dynamic>> submitAdminNotification(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.functions.invoke(
      'admin-send-notification',
      body: payload,
    );

    final raw = response.data;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map['success'] == true) {
        return Map<String, dynamic>.from(
          map['data'] as Map? ?? const <String, dynamic>{},
        );
      }

      final message = map['message']?.toString();
      throw StateError(message ?? 'Admin notification delivery failed.');
    }

    throw const FormatException('Unexpected admin notification response.');
  }

  Future<Map<String, dynamic>> settlePredictionFixture(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.functions.invoke(
      'admin-settle-fixture',
      body: payload,
    );
    final raw = response.data;
    if (raw is! Map) {
      throw const FormatException('Unexpected fixture settlement response.');
    }
    final map = Map<String, dynamic>.from(raw);
    if (map['success'] != true || map['data'] is! Map) {
      throw StateError(
        map['error']?.toString() ?? 'Fixture settlement was not confirmed.',
      );
    }
    final data = Map<String, dynamic>.from(map['data'] as Map);
    if (data['receipt'] is! Map) {
      throw const FormatException('Unexpected fixture settlement receipt.');
    }
    return Map<String, dynamic>.from(data['receipt'] as Map);
  }
}

// ── Models ──

class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    this.totalUsers = 0,
    this.activeGroups = 0,
    this.transactionsToday = 0,
    this.ticketsSold = 0,
  });

  final int totalUsers;
  final int activeGroups;
  final int transactionsToday;
  final int ticketsSold;
}
