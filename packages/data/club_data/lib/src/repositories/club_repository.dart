import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/club_models.dart';

class OrderConflictException implements Exception {
  const OrderConflictException();

  @override
  String toString() =>
      'Order changed after it was loaded. Refresh order history, review the latest status, and try again.';
}

class TicketConflictException implements Exception {
  const TicketConflictException();

  @override
  String toString() =>
      'Ticket changed after it was loaded. Refresh ticket history, review the latest status, and try again.';
}

/// Universal club repository — white-label, multi-tenant.
///
/// All operations are scoped to the active club tenant.
class ClubRepository {
  ClubRepository({
    required SupabaseClient client,
    required OperationalHealthService healthService,
    StoreReleasePolicy? storeReleasePolicy,
  }) : _client = client,
       _health = healthService,
       _storeReleasePolicy =
           storeReleasePolicy ??
           StoreReleasePolicy.forCurrentBuild(const PlatformConfigSnapshot());

  final SupabaseClient _client;
  final OperationalHealthService _health;
  final StoreReleasePolicy _storeReleasePolicy;
  late final ClubScopeResolver _scopeResolver = ClubScopeResolver(
    client: _client,
  );
  static const String _contributionGroupProjection =
      'id, name, description, group_type, target_amount, '
      'current_total, momo_recipient_code, momo_route_type, deadline, '
      'is_recurring, is_closed, member_count, created_at, club_id, partner_id';
  static const String _fanMembershipProjection =
      'id,user_id,partner_id,club_id,tier,points,joined_at,chapter,'
      'membership_number,display_name,expires_at,renewed_at,payment_status,'
      'status,created_at,updated_at';

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
      var query = _client
          .from('fan_memberships')
          .select(_fanMembershipProjection)
          .eq('user_id', userId);
      query = _scopeResolver.apply(query, scope);
      final row = await query.maybeSingle();
      if (row == null) return null;
      return FanMembership.fromJson(row);
    } catch (e) {
      AfriLogger.warn('ClubRepository', 'getFanMembership error: $e');
      return null;
    }
  }

  /// Create a new fan membership.
  Future<FanMembership> createFanMembership(
    String userId, {
    required String partnerId,
    String chapter = 'Main',
    FanTier tier = FanTier.imena,
    int? points,
    DateTime? expiresAt,
    DateTime? renewedAt,
  }) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    final membershipNumber = 'MEM-${DateTime.now().millisecondsSinceEpoch}';
    final effectivePoints = _storeReleasePolicy.allowsPaidDigitalMembership
        ? points ?? tier.minPoints
        : 0;

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

    final upgradedPoints = _storeReleasePolicy.allowsPaidDigitalMembership
        ? (existing.points >= tier.minPoints ? existing.points : tier.minPoints)
        : existing.points;

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

  /// Add FET points and potentially tier-up.
  Future<FanMembership> addPoints(
    String userId,
    String partnerId,
    int points,
    String reason,
  ) async {
    throw UnsupportedError(
      'The released client cannot grant FET points. Awards must come from a reviewed server event.',
    );
  }

  /// Search/list members of a partner club.
  Future<List<FanMembership>> getMembers(
    String partnerId, {
    String? searchQuery,
    FanTier? filterTier,
    int limit = 20,
    int offset = 0,
  }) async {
    if (!_storeReleasePolicy.allowsCrossUserText) {
      return const <FanMembership>[];
    }
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query = _client
        .from('fan_memberships')
        .select(_fanMembershipProjection);
    query = _scopeResolver.apply(query, scope);

    if (filterTier != null) {
      query = query.eq('tier', filterTier.value);
    }
    if (!_storeReleasePolicy.allowsCrossUserText &&
        searchQuery != null &&
        searchQuery.trim().isNotEmpty) {
      return const <FanMembership>[];
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('display_name', '%$searchQuery%');
    }

    final rows = await query
        .order('points', ascending: false)
        .range(offset, offset + limit - 1);
    return rows
        .map((row) {
          final membership = FanMembership.fromJson(row);
          if (_storeReleasePolicy.allowsCrossUserText) {
            return membership;
          }
          return membership.copyWith(
            displayName: _storeReleasePolicy.publicSupporterLabel(
              displayName: membership.displayName,
              publicUserId: row['public_user_id']?.toString(),
              userId: membership.userId,
            ),
          );
        })
        .toList(growable: false);
  }

  // ═══════════════════════════════════════════════════════════
  // Fan Clubs (Chapters)
  // ═══════════════════════════════════════════════════════════

  Future<List<FanClub>> getFanClubs(String partnerId, String? region) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    if (scope.clubId == null) {
      return const <FanClub>[];
    }
    var query = _client
        .from('fan_clubs')
        .select(
          'id,partner_id,club_id,name,region,description,member_count,event_count,'
          'rating,banner_emoji,is_active,created_at,updated_at',
        );
    query = query.eq('club_id', scope.clubId!);
    if (region != null) query = query.eq('region', region);
    final rows = await query
        .eq('is_active', true)
        .order('member_count', ascending: false);
    return rows.map((r) => FanClub.fromJson(r)).toList();
  }

  Future<void> joinClub({
    required String clubId,
    required String userId,
  }) async {
    throw UnsupportedError(
      'Fanclub membership changes must go through the reviewed request flow.',
    );
  }

  Future<void> leaveClub({
    required String clubId,
    required String userId,
  }) async {
    throw UnsupportedError(
      'Fanclub membership changes must go through the reviewed request flow.',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Matches & Tickets
  // ═══════════════════════════════════════════════════════════

  Future<List<ClubMatch>> getMatches(
    String partnerId, {
    bool onSaleOnly = false,
  }) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query = _client.from('unified_matches').select();
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
      final result = await _client.rpc(
        'purchase_club_tickets',
        params: {
          'p_match_id': matchId,
          'p_user_id': userId,
          'p_seat_type': seatType,
          'p_quantity': quantity,
          'p_payment_reference': paymentReference,
        },
      );
      final ticketIds = _extractTicketIds(result);
      if (ticketIds.isNotEmpty) {
        return _fetchTicketsByIds(ticketIds);
      }
      throw StateError(
        'Ticket purchase request was not accepted by the backend.',
      );
    } on PostgrestException catch (error) {
      if (!_isMissingPurchaseRpc(error)) {
        rethrow;
      }
      AfriLogger.error(
        'ClubRepository',
        'purchase_club_tickets RPC missing. Refusing to issue tickets client-side.',
      );
      throw StateError(
        'Ticketing verification is temporarily unavailable. Please try again later.',
      );
    }
  }

  Future<List<ClubTicket>> getMyTickets(String userId, String partnerId) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query = _client
        .from('tickets')
        .select(ClubTicket.dataApiProjection)
        .eq('user_id', userId);
    query = _scopeResolver.apply(query, scope);
    final rows = await query.order('purchased_at', ascending: false);
    return rows.map((r) => ClubTicket.fromJson(r)).toList();
  }

  Future<ClubTicket> cancelTicket(ClubTicket ticket) async {
    try {
      await _client.rpc(
        'cancel_ticket_if_unchanged',
        params: {
          'p_ticket_id': ticket.id,
          'p_expected_updated_at': ticket.updatedAt.toUtc().toIso8601String(),
        },
      );
      final refreshed = await _fetchTicketsByIds(<String>[ticket.id]);
      return refreshed.single;
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('ticket changed after it was loaded') ||
          message.contains('can no longer be cancelled')) {
        throw const TicketConflictException();
      }
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Shop
  // ═══════════════════════════════════════════════════════════

  Future<List<ClubProduct>> getProducts(
    String partnerId,
    String? category,
  ) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query = _client
        .from('shop_products')
        .select(ClubProduct.dataApiProjection)
        .eq('is_active', true);
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
    await _scopeResolver.requireResolved(partnerId);

    final authenticatedUserId = _client.auth.currentUser?.id;
    if (authenticatedUserId == null || authenticatedUserId != userId) {
      throw StateError(
        'An authenticated supporter may only place an order for their own account.',
      );
    }
    if (items.isEmpty || items.length > 20) {
      throw ArgumentError.value(
        items.length,
        'items',
        'An order must contain between 1 and 20 products.',
      );
    }
    if (discountAmount != 0) {
      throw ArgumentError.value(
        discountAmount,
        'discountAmount',
        'Discounts must be calculated by an approved server-side promotion.',
      );
    }

    final result = await _client.rpc(
      'create_shop_order',
      params: <String, dynamic>{
        'p_items': items
            .map(
              (item) => <String, dynamic>{
                'product_id': item.product.id,
                'quantity': item.quantity,
                'selected_variant': item.selectedVariant,
              },
            )
            .toList(growable: false),
        'p_delivery_address': deliveryAddress,
        'p_payment_reference': paymentReference,
      },
    );

    final row = switch (result) {
      final Map<dynamic, dynamic> value => Map<String, dynamic>.from(value),
      final List<dynamic> value
          when value.length == 1 && value.single is Map<dynamic, dynamic> =>
        Map<String, dynamic>.from(value.single as Map<dynamic, dynamic>),
      _ => throw StateError(
        'Shop order request was not accepted by the backend.',
      ),
    };
    final orderId = row['id']?.toString();
    if (orderId == null || orderId.isEmpty) {
      throw StateError('Shop order response did not include an order id.');
    }
    return orderId;
  }

  Future<List<ClubShopOrder>> getMyOrders(String userId) async {
    final scope = await _scopeResolver.requireResolved();
    var query = _client.from('shop_orders').select().eq('user_id', userId);
    query = _scopeResolver.apply(query, scope);
    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => ClubShopOrder.fromJson(r)).toList();
  }

  Future<ClubShopOrder> cancelOrder(ClubShopOrder order) async {
    final expectedUpdatedAt = order.updatedAt;
    if (expectedUpdatedAt == null) {
      throw const OrderConflictException();
    }

    final dynamic result;
    try {
      result = await _client.rpc(
        'cancel_shop_order_if_unchanged',
        params: <String, dynamic>{
          'p_order_id': order.id,
          'p_expected_updated_at': expectedUpdatedAt.toUtc().toIso8601String(),
        },
      );
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('changed after it was loaded') ||
          message.contains('can no longer be cancelled')) {
        throw const OrderConflictException();
      }
      rethrow;
    }
    if (result is! Map) {
      throw const OrderConflictException();
    }
    return ClubShopOrder.fromJson(Map<String, dynamic>.from(result));
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
    var query = _client
        .from('contribution_groups')
        .select(_contributionGroupProjection);
    query = _scopeResolver.apply(query, scope);
    if (!includeClosedGroups) query = query.eq('is_closed', false);
    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => ContributionGroup.fromJson(r)).toList();
  }

  /// Record a contribution against the ledger-backed group contributions table.
  Future<String> contribute({
    required String groupId,
    required String userId,
    required int amount,
    required String clientRequestReference,
    String paymentMethod = 'momo',
    String? idempotencyKey,
  }) async {
    final authenticatedUserId = _client.auth.currentUser?.id;
    if (authenticatedUserId == null || authenticatedUserId != userId) {
      throw StateError(
        'An authenticated supporter may only contribute from their own account.',
      );
    }
    if (amount < 1 || amount > 100000000) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Contribution amount must be between 1 and 100000000 RWF.',
      );
    }
    if (paymentMethod.trim().toLowerCase() != 'momo') {
      throw ArgumentError.value(
        paymentMethod,
        'paymentMethod',
        'Only the reviewed mobile money contribution route is supported.',
      );
    }

    final normalizedClientRequestReference = clientRequestReference
        .trim()
        .replaceAll(RegExp('[^A-Za-z0-9]'), '')
        .toUpperCase();
    if (normalizedClientRequestReference.length < 6 ||
        normalizedClientRequestReference.length > 64) {
      throw ArgumentError.value(
        clientRequestReference,
        'clientRequestReference',
        'A valid client request reference between 6 and 64 characters is required.',
      );
    }
    final normalizedIdempotencyKey =
        (idempotencyKey ?? 'momo:$normalizedClientRequestReference')
            .trim()
            .replaceAll(RegExp('[^A-Za-z0-9:_-]'), '')
            .toLowerCase();
    if (normalizedIdempotencyKey.length < 8 ||
        normalizedIdempotencyKey.length > 128) {
      throw ArgumentError.value(
        idempotencyKey,
        'idempotencyKey',
        'A valid idempotency key between 8 and 128 characters is required.',
      );
    }

    await _requireGroupScope(groupId);
    final result = await _client.rpc(
      'create_pending_group_contribution',
      params: <String, dynamic>{
        'p_group_id': groupId,
        'p_amount': amount,
        'p_client_request_reference': normalizedClientRequestReference,
        'p_idempotency_key': normalizedIdempotencyKey,
      },
    );

    final row = switch (result) {
      final Map<dynamic, dynamic> value => Map<String, dynamic>.from(value),
      final List<dynamic> value
          when value.length == 1 && value.single is Map<dynamic, dynamic> =>
        Map<String, dynamic>.from(value.single as Map<dynamic, dynamic>),
      _ => throw StateError(
        'Contribution request was not accepted by the backend.',
      ),
    };
    final contributionId = row['id']?.toString();
    if (contributionId == null || contributionId.isEmpty) {
      throw StateError(
        'Contribution response did not include a contribution id.',
      );
    }
    return contributionId;
  }

  /// Cancels an own-account contribution when the external payment channel
  /// could not be launched and no provider reference was bound.
  Future<void> cancelPendingContributionPaymentLaunch(
    String contributionId,
  ) async {
    final normalizedContributionId = contributionId.trim();
    if (normalizedContributionId.isEmpty) {
      throw ArgumentError.value(
        contributionId,
        'contributionId',
        'A contribution id is required.',
      );
    }

    final result = await _client.rpc(
      'cancel_pending_group_contribution_payment_launch',
      params: <String, dynamic>{'p_contribution_id': normalizedContributionId},
    );
    if (result != true) {
      throw StateError(
        'The pending contribution cancellation was not confirmed.',
      );
    }
  }

  /// Check the payment verification status of a recorded contribution.
  ///
  /// Returns `'pending'`, `'verified'`, or `'failed'`.
  Future<String> getContributionPaymentStatus(String contributionId) async {
    final row = await _client
        .from('group_contributions')
        .select('status, payment_status')
        .eq('id', contributionId)
        .maybeSingle();
    if (row == null) return 'pending';
    // Prefer the explicit payment_status column if populated.
    final paymentStatus = row['payment_status']?.toString().trim();
    if (paymentStatus != null &&
        paymentStatus.isNotEmpty &&
        paymentStatus != 'pending_verification') {
      return paymentStatus; // 'verified' or 'failed'
    }
    final status = row['status']?.toString().trim().toLowerCase();
    if (status == 'confirmed' || status == 'verified') return 'verified';
    if (status == 'failed' || status == 'rejected') return 'failed';
    return 'pending';
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
          'id, group_id, user_id, amount, status, payment_status, '
          'client_request_reference, momo_reference, confirmed_at, '
          'created_at, updated_at',
        )
        .eq('group_id', groupId);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(
      rows.map((row) => Map<String, dynamic>.from(row)),
    );
  }

  Future<List<ClubTicket>> _fetchTicketsByIds(List<String> ticketIds) async {
    final rows = await _client
        .from('tickets')
        .select(ClubTicket.dataApiProjection)
        .inFilter('id', ticketIds)
        .order('purchased_at', ascending: false);
    final tickets = List<Map<String, dynamic>>.from(
      rows as List,
    ).map(ClubTicket.fromJson).toList(growable: false);
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

  /// Get group members for a specific group.
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    await _requireGroupScope(groupId);
    final rows = await _client
        .from('group_members')
        .select(
          'id, group_id, user_id, display_name, is_admin, is_anonymous, '
          'contribution_amount, joined_at, '
          'profile:profiles(public_user_id, display_name)',
        )
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);
    final members = List<Map<String, dynamic>>.from(rows);
    if (_storeReleasePolicy.allowsCrossUserText) {
      return members;
    }
    return members
        .map((member) {
          final rawProfile = member['profile'];
          if (rawProfile is! Map) {
            return member;
          }
          final profile = Map<String, dynamic>.from(rawProfile);
          final label = _storeReleasePolicy.publicSupporterLabel(
            displayName: profile['display_name']?.toString(),
            publicUserId: profile['public_user_id']?.toString(),
            userId:
                member['user_id']?.toString() ??
                member['member_id']?.toString(),
          );
          return <String, dynamic>{
            ...member,
            'profile': <String, dynamic>{...profile, 'display_name': label},
          };
        })
        .toList(growable: false);
  }

  // ═══════════════════════════════════════════════════════════
  // Gamification / FET
  // ═══════════════════════════════════════════════════════════

  Future<void> recordFetEvent({
    required String userId,
    required FetEventType eventType,
    Map<String, Object?>? metadata,
  }) async {
    throw UnsupportedError(
      'The released client cannot record events that award FET. Awards must come from a reviewed server event.',
    );
  }

  Future<List<FetEvent>> getFetHistory(String userId, {int limit = 50}) async {
    final rows = await _client
        .from('fet_events')
        .select('id,user_id,club_id,event_type,fet_awarded,event_at,created_at')
        .eq('user_id', userId)
        .order('event_at', ascending: false)
        .limit(limit);
    return rows.map((r) => FetEvent.fromJson(r)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // Payment Route
  // ═══════════════════════════════════════════════════════════

  Future<PartnerPaymentRoute?> findActivePaymentRoute(String partnerId) async {
    final scope = await _scopeResolver.requireResolved(partnerId);
    var query = _client
        .from('partner_payment_routes')
        .select(
          'id,partner_id,club_id,partner_name,partner_slug,country,provider,'
          'recipient_code,reconciliation_label,status',
        )
        .eq('status', 'active');
    query = _scopeResolver.apply(query, scope);
    final rows = await query.limit(1);

    if (rows.isEmpty) {
      return null;
    }
    return PartnerPaymentRoute.fromJson(rows.first);
  }

  Future<PartnerPaymentRoute> getActivePaymentRoute(String partnerId) async {
    final route = await findActivePaymentRoute(partnerId);
    if (route != null) {
      return route;
    }

    throw StateError(
      'Payment route setup pending for partner '
      '${partnerId.trim().isEmpty ? 'current club' : partnerId}',
    );
  }
}
