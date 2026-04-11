import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/club_models.dart';

/// Universal club repository — white-label, multi-tenant.
///
/// All operations are scoped to the active club tenant.
class ClubRepository {
  ClubRepository({
    required SupabaseClient client,
    required OperationalHealthService healthService,
  })  : _client = client,
        _health = healthService;

  final SupabaseClient _client;
  final OperationalHealthService _health;
  late final ClubScopeResolver _scopeResolver = ClubScopeResolver(
    client: _client,
  );

  String? get _userId => _client.auth.currentUser?.id;

  Future<ClubScope> _requireGroupScope(String groupId) async {
    final activeScope = await _scopeResolver.requireResolved();
    var query = _client
        .from('contribution_groups')
        .select('partner_id, club_id')
        .eq('id', groupId);
    query = _scopeResolver.apply(query, activeScope);
    final row = await query.maybeSingle();
    if (row == null) {
      throw StateError('Contribution group not found for the active club.');
    }

    return ClubScope(
      partnerId: row['partner_id']?.toString() ?? activeScope.partnerId,
      clubId:
          int.tryParse(row['club_id']?.toString() ?? '') ?? activeScope.clubId,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Membership
  // ═══════════════════════════════════════════════════════════

  /// Get the current user's fan membership for a club.
  Future<FanMembership?> getFanMembership(
    String userId,
    String partnerId,
  ) async {
    try {
      final scope = await _scopeResolver.requireResolved(partnerId);
      var query =
          _client.from('fan_memberships').select().eq('user_id', userId);
      query = _scopeResolver.apply(query, scope);
      final row = await query.maybeSingle();
      if (row == null) return null;
      return FanMembership.fromJson(row);
    } catch (e) {
      debugPrint('[ClubRepository] getFanMembership error: $e');
      return null;
    }
  }

  /// Create a new fan membership.
  Future<FanMembership> createFanMembership(
    String userId, {
    required String partnerId,
    String chapter = 'Main',
    FanTier tier = FanTier.fan,
    int? points,
    DateTime? expiresAt,
    DateTime? renewedAt,
  }) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    final membershipNumber = 'FAN-${DateTime.now().millisecondsSinceEpoch}';
    final effectivePoints = points ?? tier.minPoints;

    final row = await _client
        .from('fan_memberships')
        .insert({
          'user_id': userId,
          ..._scopeResolver.payload(scope),
          'tier': tier.value,
          'points': effectivePoints,
          'chapter': chapter,
          'membership_number': membershipNumber,
          if (expiresAt != null)
            'expires_at': expiresAt.toUtc().toIso8601String(),
          if (renewedAt != null)
            'renewed_at': renewedAt.toUtc().toIso8601String(),
        })
        .select()
        .single();

    final membership = FanMembership.fromJson(row);

    await _health.recordEvent(
      service: 'club',
      component: 'membership',
      message: 'Fan membership created',
      status: OperationalHealthStatus.ok,
      userId: userId,
      subjectType: 'fan_membership',
      subjectId: membership.id,
    );

    return membership;
  }

  /// Activate or renew the current user's selected membership package.
  Future<FanMembership> activateMembershipPackage({
    required String userId,
    required String partnerId,
    required String packageTier,
    String chapter = 'Main',
  }) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    final tier = FanTierX.fromValue(packageTier);
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(days: 365));
    final existing = await getFanMembership(userId, scope.partnerId);

    if (existing == null) {
      return createFanMembership(
        userId,
        partnerId: scope.partnerId,
        chapter: chapter,
        tier: tier,
        points: tier.minPoints,
        renewedAt: now,
        expiresAt: expiresAt,
      );
    }

    final upgradedPoints =
        existing.points >= tier.minPoints ? existing.points : tier.minPoints;

    final row = await _client
        .from('fan_memberships')
        .update({
          'tier': tier.value,
          'points': upgradedPoints,
          'chapter': chapter,
          'renewed_at': now.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        })
        .eq('id', existing.id)
        .select()
        .single();

    final membership = FanMembership.fromJson(row);

    await _health.recordEvent(
      service: 'club',
      component: 'membership',
      message: 'Fan membership activated',
      status: OperationalHealthStatus.ok,
      userId: userId,
      subjectType: 'fan_membership',
      subjectId: membership.id,
    );

    return membership;
  }

  /// Add XP points and potentially tier-up.
  Future<FanMembership> addPoints(
    String userId,
    String partnerId,
    int points,
    String reason,
  ) async {
    final row = await _client.rpc('add_fan_points', params: {
      'p_user_id': userId,
      'p_partner_id': partnerId,
      'p_points': points,
      'p_reason': reason,
    });
    return FanMembership.fromJson(row as Map<String, dynamic>);
  }

  /// Search/list members of a partner club.
  Future<List<FanMembership>> getMembers(
    String partnerId, {
    String? searchQuery,
    FanTier? filterTier,
    int limit = 20,
    int offset = 0,
  }) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query = _client.from('fan_memberships').select();
    query = _scopeResolver.apply(query, scope);

    if (filterTier != null) {
      query = query.eq('tier', filterTier.value);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('display_name', '%$searchQuery%');
    }

    final rows = await query
        .order('points', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map((r) => FanMembership.fromJson(r)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // Fan Clubs (Chapters)
  // ═══════════════════════════════════════════════════════════

  Future<List<FanClub>> getFanClubs(String partnerId, String? region) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query = _client.from('fan_clubs').select();
    query = _scopeResolver.apply(query, scope);
    if (region != null) query = query.eq('region', region);
    final rows = await query.order('member_count', ascending: false);
    return rows.map((r) => FanClub.fromJson(r)).toList();
  }

  Future<void> joinClub({
    required String clubId,
    required String userId,
  }) async {
    await _client.from('fan_club_members').insert({
      'club_id': clubId,
      'user_id': userId,
    });
  }

  Future<void> leaveClub({
    required String clubId,
    required String userId,
  }) async {
    await _client
        .from('fan_club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', userId);
  }

  // ═══════════════════════════════════════════════════════════
  // Matches & Tickets
  // ═══════════════════════════════════════════════════════════

  Future<List<ClubMatch>> getMatches(
    String partnerId, {
    bool onSaleOnly = false,
  }) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query = _client.from('matches').select();
    query = _scopeResolver.apply(query, scope);

    if (onSaleOnly) query = query.eq('is_on_sale', true);

    final rows = await query.order('match_date', ascending: true);
    return rows.map((r) => ClubMatch.fromJson(r)).toList();
  }

  Future<List<ClubTicket>> purchaseTickets({
    required String matchId,
    required String userId,
    required String seatType,
    required int quantity,
    required String paymentReference,
  }) async {
    try {
      final result = await _client.rpc('purchase_club_tickets', params: {
        'p_match_id': matchId,
        'p_user_id': userId,
        'p_seat_type': seatType,
        'p_quantity': quantity,
        'p_payment_reference': paymentReference,
      });
      final ticketIds = _extractTicketIds(result);
      if (ticketIds.isNotEmpty) {
        return _fetchTicketsByIds(ticketIds);
      }
      throw StateError('Ticket purchase returned no issued tickets.');
    } on PostgrestException catch (error) {
      if (!_isMissingPurchaseRpc(error)) {
        rethrow;
      }
      debugPrint(
        '[ClubRepository] purchase_club_tickets RPC missing, using direct ticket issuance fallback.',
      );
      return _createTicketsDirect(
        matchId: matchId,
        userId: userId,
        seatType: seatType,
        quantity: quantity,
        paymentReference: paymentReference,
      );
    }
  }

  Future<List<ClubTicket>> getMyTickets(String userId, String partnerId) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query = _client
        .from('tickets')
        .select('*, match:matches(*)')
        .eq('user_id', userId);
    query = _scopeResolver.apply(query, scope);
    final rows = await query.order('purchased_at', ascending: false);
    return rows.map((r) => ClubTicket.fromJson(r)).toList();
  }

  Future<void> cancelTicket(String ticketId) async {
    await _client
        .from('tickets')
        .update({'status': 'cancelled'})
        .eq('id', ticketId)
        .eq('user_id', _userId!);
  }

  // ═══════════════════════════════════════════════════════════
  // Shop
  // ═══════════════════════════════════════════════════════════

  Future<List<ClubProduct>> getProducts(
    String partnerId,
    String? category,
  ) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query = _client.from('shop_products').select().eq('is_active', true);
    query = _scopeResolver.apply(query, scope);

    if (category != null) query = query.eq('category', category);
    final rows = await query.order('sort_order', ascending: true);
    return rows.map((r) => ClubProduct.fromJson(r)).toList();
  }

  Future<String> placeOrder({
    required String userId,
    required String partnerId,
    required List<CartItem> items,
    required String deliveryAddress,
    required String paymentReference,
    int discountAmount = 0,
  }) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    final subtotal = items.fold(0, (sum, item) => sum + item.lineTotal);
    final total = subtotal - discountAmount;

    final row = await _client
        .from('shop_orders')
        .insert({
          'user_id': userId,
          ..._scopeResolver.payload(scope),
          'items': items
              .map((i) => {
                    'product': i.product.toJson(),
                    'quantity': i.quantity,
                    'selected_variant': i.selectedVariant,
                  })
              .toList(),
          'subtotal': subtotal,
          'discount_amount': discountAmount,
          'delivery_fee': 0,
          'total': total,
          'delivery_address': deliveryAddress,
          'momo_reference': paymentReference,
          'status': OrderStatus.pending.value,
        })
        .select()
        .single();

    return row['id'] as String;
  }

  Future<List<ClubShopOrder>> getMyOrders(String userId) async {
    final scope = await _scopeResolver.requireResolved();
    var query = _client.from('shop_orders').select().eq('user_id', userId);
    query = _scopeResolver.apply(query, scope);
    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => ClubShopOrder.fromJson(r)).toList();
  }

  Future<void> cancelOrder(String orderId) async {
    await _client
        .from('shop_orders')
        .update({'status': 'cancelled'})
        .eq('id', orderId)
        .eq('user_id', _userId!);
  }

  // ═══════════════════════════════════════════════════════════
  // Contributions (multi-tenant, club_id-scoped)
  // ═══════════════════════════════════════════════════════════

  /// Fetch contribution groups — RLS enforces club_id from JWT.
  Future<List<ContributionGroup>> getContributionGroups({
    String? partnerId,
    bool includeClosedGroups = false,
  }) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query = _client.from('contribution_groups').select();
    query = _scopeResolver.apply(query, scope);
    if (!includeClosedGroups) query = query.eq('is_closed', false);
    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => ContributionGroup.fromJson(r)).toList();
  }

  /// Atomically create a group and add creator as admin member via RPC.
  Future<ContributionGroup> createContributionGroup(
    ContributionGroup group,
  ) async {
    final scope = await _scopeResolver.requireResolved();
    final countryCode = RuntimeBranding.displayCountryCode;
    if (countryCode.isEmpty) {
      throw StateError(
        'Country code must be configured before creating contribution groups.',
      );
    }
    // Prefer the atomic RPC that also adds creator as admin member
    try {
      final rpcResult = await _client.rpc('create_group_atomic', params: {
        'p_name': group.name,
        'p_description': group.description,
        'p_privacy': group.privacy.value,
        'p_group_type': group.groupType.value,
        'p_target_amount': group.targetAmount,
        'p_currency': RuntimeBranding.displayCurrencyCode,
        'p_cycle_days': 30,
        'p_country_code': countryCode,
      });

      final result = rpcResult is Map<String, dynamic>
          ? rpcResult
          : (rpcResult as List).first as Map<String, dynamic>;

      // Fetch the full group record
      final row = await _client
          .from('contribution_groups')
          .select()
          .eq('id', result['id'] as String)
          .single();
      return ContributionGroup.fromJson(row);
    } catch (e) {
      debugPrint('[ClubRepository] create_group_atomic RPC failed: $e');
      // Fallback to direct insert
      final row = await _client
          .from('contribution_groups')
          .insert({
            ...group.toInsertJson(),
            ..._scopeResolver.payload(scope),
            'creator_id': _userId,
          })
          .select()
          .single();
      return ContributionGroup.fromJson(row);
    }
  }

  /// Record a contribution against the ledger-backed group contributions table.
  Future<String> contribute({
    required String groupId,
    required String userId,
    required int amount,
    required String paymentReference,
    String paymentMethod = 'momo',
  }) async {
    await _requireGroupScope(groupId);
    final createdAt = DateTime.now().toIso8601String();

    final row = await _client
        .from('group_contributions')
        .insert({
          'group_id': groupId,
          'user_id': userId,
          'amount': amount,
          'status': 'pending',
          'momo_reference': paymentReference,
          'created_at': createdAt,
        })
        .select()
        .single();
    return row['id'] as String;
  }

  /// Preview an invite code (no auth required for the RPC).
  Future<Map<String, dynamic>?> previewInvite(String inviteCode) async {
    try {
      final result = await _client.rpc('preview_invite', params: {
        'p_invite_code': inviteCode,
      });
      final data = result is Map<String, dynamic>
          ? result
          : (result as List).first as Map<String, dynamic>;
      if (data['found'] == true) return data;
      return null;
    } catch (e) {
      debugPrint('[ClubRepository] previewInvite error: $e');
      return null;
    }
  }

  /// Join a group via invite code.
  Future<Map<String, dynamic>> joinGroupViaInvite(String inviteCode) async {
    final result = await _client.rpc('join_group_via_invite', params: {
      'p_invite_code': inviteCode,
    });
    return result is Map<String, dynamic>
        ? result
        : (result as List).first as Map<String, dynamic>;
  }

  /// Get contributions for a specific group.
  Future<List<Map<String, dynamic>>> getGroupContributions(
    String groupId, {
    int limit = 50,
  }) async {
    await _requireGroupScope(groupId);
    final query = _client
        .from('group_contributions')
        .select(
            'id, group_id, user_id, amount, status, momo_reference, created_at')
        .eq('group_id', groupId);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(
      rows.map((row) => Map<String, dynamic>.from(row)),
    );
  }

  Future<List<ClubTicket>> _fetchTicketsByIds(List<String> ticketIds) async {
    final rows = await _client
        .from('tickets')
        .select('*, match:matches(*)')
        .inFilter('id', ticketIds)
        .order('purchased_at', ascending: false);
    final tickets = List<Map<String, dynamic>>.from(rows as List)
        .map(ClubTicket.fromJson)
        .toList(growable: false);
    if (tickets.isEmpty) {
      throw StateError('Ticket purchase was not confirmed by the backend.');
    }
    return tickets;
  }

  List<String> _extractTicketIds(dynamic result) {
    if (result is List) {
      return result
          .map((entry) {
            if (entry is String) {
              return entry;
            }
            if (entry is Map<String, dynamic>) {
              return entry['id']?.toString();
            }
            if (entry is Map) {
              return entry['id']?.toString();
            }
            return null;
          })
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
    }

    if (result is Map<String, dynamic>) {
      final directId = result['id']?.toString();
      if (directId != null && directId.isNotEmpty) {
        return <String>[directId];
      }
      final ids = result['ticket_ids'];
      if (ids is List) {
        return ids.map((id) => id.toString()).toList(growable: false);
      }
    }

    return const <String>[];
  }

  bool _isMissingPurchaseRpc(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('purchase_club_tickets') &&
        (message.contains('not found') ||
            message.contains('schema cache') ||
            message.contains('could not find'));
  }

  Future<List<ClubTicket>> _createTicketsDirect({
    required String matchId,
    required String userId,
    required String seatType,
    required int quantity,
    required String paymentReference,
  }) async {
    final scope = await _scopeResolver.requireResolved();
    var matchQuery = _client
        .from('matches')
        .select(
            'id, club_id, is_on_sale, ticket_general_price, ticket_vip_price')
        .eq('id', matchId);
    matchQuery = _scopeResolver.apply(matchQuery, scope);
    final match = await matchQuery.maybeSingle();

    if (match == null) {
      throw StateError('Match not found for the active club.');
    }
    if (match['is_on_sale'] != true) {
      throw StateError('Tickets are not on sale for this fixture.');
    }

    final normalizedSeatType =
        seatType.trim().toLowerCase() == 'vip' ? 'vip' : 'general';
    final amountPaid = normalizedSeatType == 'vip'
        ? (match['ticket_vip_price'] as num?)?.toInt() ?? 0
        : (match['ticket_general_price'] as num?)?.toInt() ?? 0;
    final purchasedAt = DateTime.now().toUtc().toIso8601String();
    final rows = List.generate(
      quantity,
      (_) => <String, dynamic>{
        'match_id': matchId,
        'user_id': userId,
        'club_id': match['club_id'],
        'seat_type': normalizedSeatType,
        'amount_paid': amountPaid,
        'momo_reference': paymentReference,
        'status': 'valid',
        'confirmed_at': purchasedAt,
        'purchased_at': purchasedAt,
      },
    );

    final inserted = await _client.from('tickets').insert(rows).select('id');
    final ticketIds = List<Map<String, dynamic>>.from(inserted as List)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    return _fetchTicketsByIds(ticketIds);
  }

  /// Get group members for a specific group.
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    await _requireGroupScope(groupId);
    final rows = await _client
        .from('group_members')
        .select('*, profile:profiles(public_user_id, display_name)')
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  // ═══════════════════════════════════════════════════════════
  // Gamification / XP
  // ═══════════════════════════════════════════════════════════

  Future<void> recordXpEvent({
    required String userId,
    required XpEventType eventType,
    Map<String, Object?>? metadata,
  }) async {
    final payload = {
      'user_id': userId,
      'event_type': eventType.eventKey,
      'xp_awarded': eventType.xpReward,
      'metadata': metadata,
    };

    try {
      await _client.from('cool_events').insert(payload);
    } catch (_) {
      await _client.from('xp_events').insert(payload);
    }
  }

  Future<List<XpEvent>> getXpHistory(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final rows = await _client
          .from('cool_events')
          .select()
          .eq('user_id', userId)
          .order('event_at', ascending: false)
          .limit(limit);
      return rows.map((r) => XpEvent.fromJson(r)).toList();
    } catch (_) {
      final rows = await _client
          .from('xp_events')
          .select()
          .eq('user_id', userId)
          .order('event_at', ascending: false)
          .limit(limit);
      return rows.map((r) => XpEvent.fromJson(r)).toList();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Payment Route
  // ═══════════════════════════════════════════════════════════

  Future<PartnerPaymentRoute?> findActivePaymentRoute(
    String partnerId,
  ) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query =
        _client.from('partner_payment_routes').select().eq('status', 'active');
    query = _scopeResolver.apply(query, scope);
    final rows = await query.limit(1);

    if (rows.isEmpty) {
      return null;
    }
    return PartnerPaymentRoute.fromJson(rows.first);
  }

  Future<PartnerPaymentRoute> getActivePaymentRoute(
    String partnerId,
  ) async {
    final route = await findActivePaymentRoute(partnerId);
    if (route != null) {
      return route;
    }

    throw StateError(
      'No active payment route for partner '
      '${partnerId.trim().isEmpty ? 'current club' : partnerId}',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Group Messages
  // ═══════════════════════════════════════════════════════════

  Future<List<GroupMessage>> getGroupMessages(
    String groupId, {
    int limit = 50,
  }) async {
    await _requireGroupScope(groupId);
    final rows = await _client
        .from('group_messages')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((r) => GroupMessage.fromJson(r)).toList();
  }

  Future<GroupMessage> sendGroupMessage(GroupMessage message) async {
    final row = await _client
        .from('group_messages')
        .insert(message.toInsertJson())
        .select()
        .single();
    return GroupMessage.fromJson(row);
  }
}
