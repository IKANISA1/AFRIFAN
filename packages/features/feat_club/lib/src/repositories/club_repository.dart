import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/club_models.dart';

/// Universal club repository — white-label, multi-tenant.
///
/// All operations are scoped to a partnerId (club tenant).
class ClubRepository {
  ClubRepository({
    required SupabaseClient client,
    required OperationalHealthService healthService,
  })  : _client = client,
        _health = healthService;

  final SupabaseClient _client;
  final OperationalHealthService _health;

  String? get _userId => _client.auth.currentUser?.id;

  /// Tables used for partner ID resolution.
  static const _partnerTables = [
    'matches',
    'fan_clubs',
    'shop_products',
    'fan_memberships',
  ];

  /// Resolve a partner/club ID — checks known tables for the identifier.
  Future<String?> _resolvePartnerId(String? partnerId) async {
    final normalized = partnerId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    // Try exact match first
    for (final table in _partnerTables) {
      try {
        final row = await _client
            .from(table)
            .select('partner_id')
            .eq('partner_id', normalized)
            .limit(1)
            .maybeSingle();
        final found = row?['partner_id']?.toString();
        if (found != null && found.isNotEmpty) return found;
      } catch (_) {
        // Table may not exist yet — continue.
      }
    }

    // Fallback: any row with a partner_id
    for (final table in _partnerTables) {
      try {
        final row = await _client
            .from(table)
            .select('partner_id')
            .limit(1)
            .maybeSingle();
        final found = row?['partner_id']?.toString();
        if (found != null && found.isNotEmpty) return found;
      } catch (_) {
        // Table may not exist yet — continue.
      }
    }

    return normalized;
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
      var rows = await _client
          .from('fan_memberships')
          .select()
          .eq('user_id', userId)
          .eq('partner_id', partnerId)
          .limit(1);

      if (rows.isEmpty) {
        rows = await _client
            .from('fan_memberships')
            .select()
            .eq('user_id', userId)
            .limit(1);
      }

      if (rows.isEmpty) return null;
      return FanMembership.fromJson(rows.first);
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
  }) async {
    final resolvedPartnerId = await _resolvePartnerId(partnerId) ?? partnerId;
    final membershipNumber = 'FAN-${DateTime.now().millisecondsSinceEpoch}';

    final row = await _client
        .from('fan_memberships')
        .insert({
          'user_id': userId,
          'partner_id': resolvedPartnerId,
          'tier': FanTier.fan.value,
          'points': 0,
          'chapter': chapter,
          'membership_number': membershipNumber,
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
    final resolvedPartnerId = await _resolvePartnerId(partnerId) ?? partnerId;
    var query = _client.from('fan_memberships').select();

    if (resolvedPartnerId.isNotEmpty) {
      query = query.eq('partner_id', resolvedPartnerId);
    }

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
    final resolvedPartnerId = await _resolvePartnerId(partnerId) ?? partnerId;
    var query = _client.from('fan_clubs').select();
    if (resolvedPartnerId.isNotEmpty) {
      query = query.eq('partner_id', resolvedPartnerId);
    }
    if (region != null) query = query.eq('region', region);
    var rows = await query.order('member_count', ascending: false);
    if (rows.isEmpty && resolvedPartnerId.isNotEmpty) {
      var fallbackQuery = _client.from('fan_clubs').select();
      if (region != null) {
        fallbackQuery = fallbackQuery.eq('region', region);
      }
      rows = await fallbackQuery.order('member_count', ascending: false);
    }
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
    final resolvedPartnerId = await _resolvePartnerId(partnerId) ?? partnerId;
    var query = _client.from('matches').select();
    if (resolvedPartnerId.isNotEmpty) {
      query = query.eq('partner_id', resolvedPartnerId);
    }

    if (onSaleOnly) query = query.eq('is_on_sale', true);

    var rows = await query.order('match_date', ascending: true);
    if (rows.isEmpty && resolvedPartnerId.isNotEmpty) {
      var fallbackQuery = _client.from('matches').select();
      if (onSaleOnly) {
        fallbackQuery = fallbackQuery.eq('is_on_sale', true);
      }
      rows = await fallbackQuery.order('match_date', ascending: true);
    }
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
      final rows = await _client.rpc('purchase_club_tickets', params: {
        'p_match_id': matchId,
        'p_user_id': userId,
        'p_seat_type': seatType,
        'p_quantity': quantity,
        'p_payment_reference': paymentReference,
      });

      final list = rows as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((r) => ClubTicket.fromJson(r))
          .toList();
    } catch (_) {
      final matchRow =
          await _client.from('matches').select().eq('id', matchId).single();
      final match = ClubMatch.fromJson(Map<String, dynamic>.from(matchRow));
      final seat = SeatTypeX.fromValue(seatType);
      final amount = seat == SeatType.vip
          ? match.ticketVipPrice
          : match.ticketGeneralPrice;

      final payload = List.generate(quantity, (index) {
        return <String, Object?>{
          'match_id': matchId,
          'user_id': userId,
          'seat_type': seat.value,
          'amount_paid': amount,
          'qr_code': 'RS-${DateTime.now().millisecondsSinceEpoch}-$index',
          'momo_reference': paymentReference,
          'status': TicketStatus.active.value,
          'purchased_at': DateTime.now().toIso8601String(),
        };
      });

      final inserted = await _client
          .from('tickets')
          .insert(payload)
          .select('*, match:matches(*)');

      return inserted
          .whereType<Map<String, dynamic>>()
          .map((row) => ClubTicket.fromJson(row))
          .toList(growable: false);
    }
  }

  Future<List<ClubTicket>> getMyTickets(String userId) async {
    final rows = await _client
        .from('tickets')
        .select('*, match:matches(*)')
        .eq('user_id', userId)
        .order('purchased_at', ascending: false);
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
    final resolvedPartnerId = await _resolvePartnerId(partnerId) ?? partnerId;
    var query = _client.from('shop_products').select().eq('is_active', true);

    if (resolvedPartnerId.isNotEmpty) {
      query = query.eq('partner_id', resolvedPartnerId);
    }

    if (category != null) query = query.eq('category', category);
    var rows = await query.order('sort_order', ascending: true);
    if (rows.isEmpty && resolvedPartnerId.isNotEmpty) {
      var fallbackQuery =
          _client.from('shop_products').select().eq('is_active', true);
      if (category != null) {
        fallbackQuery = fallbackQuery.eq('category', category);
      }
      rows = await fallbackQuery.order('sort_order', ascending: true);
    }
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
    final resolvedPartnerId = await _resolvePartnerId(partnerId);
    final subtotal = items.fold(0, (sum, item) => sum + item.lineTotal);
    final total = subtotal - discountAmount;

    final row = await _client
        .from('shop_orders')
        .insert({
          'user_id': userId,
          'partner_id': resolvedPartnerId,
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
    final rows = await _client
        .from('shop_orders')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
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
    var query = _client.from('contribution_groups').select();
    if (!includeClosedGroups) query = query.eq('is_closed', false);
    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => ContributionGroup.fromJson(r)).toList();
  }

  /// Atomically create a group and add creator as admin member via RPC.
  Future<ContributionGroup> createContributionGroup(
    ContributionGroup group,
  ) async {
    // Prefer the atomic RPC that also adds creator as admin member
    try {
      final rpcResult = await _client.rpc('create_group_atomic', params: {
        'p_name': group.name,
        'p_description': group.description,
        'p_privacy': group.privacy.value,
        'p_group_type': group.groupType.value,
        'p_target_amount': group.targetAmount,
        'p_currency': 'RWF',
        'p_cycle_days': 30,
        'p_country_code': 'RW',
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
    final createdAt = DateTime.now().toIso8601String();

    final group = await _client
        .from('contribution_groups')
        .select('club_id')
        .eq('id', groupId)
        .maybeSingle();
    final clubId = group?['club_id'];
    if (clubId == null) {
      throw StateError(
        'Could not resolve legacy club_id for contribution group $groupId',
      );
    }

    final row = await _client
        .from('contributions')
        .insert({
          'group_id': groupId,
          'user_id': userId,
          'club_id': clubId,
          'amount': amount,
          'status': 'pending',
          'payment_method': paymentMethod,
          'external_ref': paymentReference,
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
    final rows = await _client
        .from('contributions')
        .select(
            'id, group_id, user_id, amount, status, external_ref, created_at')
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(
      rows.map(
        (row) => <String, dynamic>{
          ...Map<String, dynamic>.from(row),
          'momo_reference': row['external_ref'],
        },
      ),
    );
  }

  /// Get group members for a specific group.
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
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
    final resolvedPartnerId = await _resolvePartnerId(partnerId) ?? partnerId;
    var rows = await _client
        .from('partner_payment_routes')
        .select()
        .eq('partner_id', resolvedPartnerId)
        .eq('status', 'active')
        .limit(1);

    if (rows.isEmpty) {
      rows = await _client
          .from('partner_payment_routes')
          .select()
          .eq('status', 'active')
          .limit(1);
    }

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

    final resolvedPartnerId = await _resolvePartnerId(partnerId) ?? partnerId;
    throw StateError(
      'No active payment route for partner '
      '${resolvedPartnerId.isEmpty ? partnerId : resolvedPartnerId}',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Group Messages
  // ═══════════════════════════════════════════════════════════

  Future<List<GroupMessage>> getGroupMessages(
    String groupId, {
    int limit = 50,
  }) async {
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
