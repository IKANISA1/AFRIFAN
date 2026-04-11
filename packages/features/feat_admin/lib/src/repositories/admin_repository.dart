import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      debugPrint('[Admin] Admin role check failed: $e');
    }

    final role =
        user?.userMetadata?['role']?.toString().toLowerCase() ??
        user?.appMetadata['role']?.toString().toLowerCase();
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
      debugPrint('[Admin] Super admin check failed: $e');
      return false;
    }
  }

  // ── Dashboard Metrics ──

  /// Returns key metrics for the admin dashboard.
  Future<AdminDashboardMetrics> getDashboardMetrics() async {
    try {
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final scope = await _scopeResolver.resolve(null);

      var usersQuery = _client.from('profiles').select('id');
      usersQuery = _scopeResolver.apply(usersQuery, scope);
      final usersResult = await usersQuery.count(CountOption.exact);

      var groupsQuery = _client
          .from('contribution_groups')
          .select('id')
          .eq('is_closed', false);
      groupsQuery = _scopeResolver.apply(groupsQuery, scope);
      final groupsResult = await groupsQuery.count(CountOption.exact);

      final txCount = await _countTransactionsToday(startOfDay, endOfDay, scope);
      final ticketsCount = await _countTicketsSold(scope);

      return AdminDashboardMetrics(
        totalUsers: usersResult.count,
        activeGroups: groupsResult.count,
        transactionsToday: txCount,
        ticketsSold: ticketsCount,
      );
    } catch (e) {
      debugPrint('[Admin] Dashboard metrics failed: $e');
      return const AdminDashboardMetrics();
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

  // ── Contribution Groups ──

  /// Returns all contribution groups for the club (admin view — all groups).
  Future<List<Map<String, dynamic>>> getContributionGroups({
    int limit = 50,
    int offset = 0,
  }) async {
    final scope = await _scopeResolver.resolve(null);
    var query = _client.from('contribution_groups').select(
      'id, name, description, group_type, privacy, '
      'target_amount, current_total, member_count, '
      'is_closed, creator_id, created_at, invite_code',
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
      debugPrint('[Admin] Audit log query failed: $e');
      return [];
    }
  }

  /// Returns recent news titles for dashboard feed.
  Future<List<String>> getRecentNewsTitles({int limit = 3}) async {
    try {
      final newsTable = await _resolveNewsTable();
      final scope = await _scopeResolver.resolve(null);
      var query = _client.from(newsTable).select('title');
      query = _scopeResolver.apply(query, scope);
      final data = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List)
          .map((item) => item['title']?.toString() ?? 'News update')
          .toList();
    } catch (_) {
      return [];
    }
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

// ── Providers ──

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(client: ref.watch(supabaseClientProvider));
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  return ref.read(adminRepositoryProvider).isCurrentUserAdmin();
});
