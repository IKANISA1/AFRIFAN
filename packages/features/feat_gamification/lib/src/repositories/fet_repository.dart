import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fet_models.dart';
import '../models/reward_store_content.dart';

class FetRepository {
  FetRepository({
    required SupabaseClient client,
    StoreReleasePolicy? storeReleasePolicy,
  }) : _client = client,
       _storeReleasePolicy =
           storeReleasePolicy ??
           StoreReleasePolicy.forCurrentBuild(const PlatformConfigSnapshot());

  final SupabaseClient _client;
  final StoreReleasePolicy _storeReleasePolicy;
  late final ClubScopeResolver _scopeResolver = ClubScopeResolver(
    client: _client,
  );

  static const _tag = 'FetRepo';

  Future<List<FetCatalogItem>> loadCatalog() async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <FetCatalogItem>[];
    }

    final result = await SafeRpc.call(
      'fet_get_catalog',
      params: <String, dynamic>{
        'p_club_id': scope.clubId,
        'p_include_inactive': false,
      },
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return const <FetCatalogItem>[];
    }

    final rows = (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    return rows
        .map(FetCatalogItem.fromJson)
        .where((item) => item.isActive)
        .toList(growable: false);
  }

  Future<List<FetPartnerOffer>> loadPartnerOffers({
    bool includeInactive = false,
    int limit = 500,
  }) async {
    if (!_storeReleasePolicy.allowsRewardRedemption) {
      return const <FetPartnerOffer>[];
    }
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <FetPartnerOffer>[];
    }

    final result = await SafeRpc.call(
      'fet_get_partner_offers',
      params: <String, dynamic>{
        'p_club_id': scope.clubId,
        'p_include_inactive': includeInactive,
        'p_limit': limit,
      },
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return const <FetPartnerOffer>[];
    }

    final rows = (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    return rows
        .map(FetPartnerOffer.fromJson)
        .where((offer) => includeInactive || offer.isActive)
        .toList(growable: false);
  }

  Future<List<FetLeaderboardRow>> loadLeaderboard({int limit = 25}) async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <FetLeaderboardRow>[];
    }

    final result = await SafeRpc.call(
      'fet_get_leaderboard',
      params: <String, dynamic>{'p_club_id': scope.clubId, 'p_limit': limit},
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return const <FetLeaderboardRow>[];
    }

    final rows = (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    return rows
        .map(_sanitizePublicIdentity)
        .map(FetLeaderboardRow.fromJson)
        .toList(growable: false);
  }

  Future<List<FetFriendProfile>> loadFriends({
    int limit = 20,
    String? search,
  }) async {
    final safeSearch = _storeReleasePolicy.allowsCrossUserText
        ? search
        : _systemAliasQuery(search);
    if (!_storeReleasePolicy.allowsCrossUserText &&
        search?.trim().isNotEmpty == true &&
        safeSearch == null) {
      return const <FetFriendProfile>[];
    }
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <FetFriendProfile>[];
    }

    final result = await SafeRpc.call(
      'fet_get_friends',
      params: <String, dynamic>{
        'p_club_id': scope.clubId,
        'p_limit': limit,
        'p_search': safeSearch,
      },
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return const <FetFriendProfile>[];
    }

    final rows = (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    return rows
        .map(_sanitizePublicIdentity)
        .map(FetFriendProfile.fromJson)
        .toList(growable: false);
  }

  Future<List<FetFriendProfile>> searchSupporters(
    String query, {
    int limit = 8,
  }) async {
    final trimmed = _storeReleasePolicy.allowsCrossUserText
        ? query.trim()
        : _systemAliasQuery(query);
    if (trimmed == null) {
      return const <FetFriendProfile>[];
    }
    if (trimmed.isEmpty) {
      return const <FetFriendProfile>[];
    }

    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <FetFriendProfile>[];
    }

    final result = await SafeRpc.call(
      'fet_search_supporters',
      params: <String, dynamic>{
        'p_query': trimmed,
        'p_club_id': scope.clubId,
        'p_limit': limit,
      },
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return const <FetFriendProfile>[];
    }

    final rows = (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    return rows
        .map(_sanitizePublicIdentity)
        .map(FetFriendProfile.fromJson)
        .toList(growable: false);
  }

  Future<FetFriendActionResult> requestFriend({
    required String targetUserId,
    String? note,
  }) async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const FetFriendActionResult(
        status: 'error',
        message: 'club_context_required',
      );
    }

    final result = await SafeRpc.call(
      'fet_request_friend',
      params: <String, dynamic>{
        'p_target_user_id': targetUserId,
        'p_club_id': scope.clubId,
        'p_note': _storeReleasePolicy.allowsCrossUserText ? note : null,
      },
      tag: _tag,
      maxAttempts: 1,
    );

    if (!result.isSuccess || result.data is! Map) {
      return FetFriendActionResult(
        status: 'error',
        message: result.error ?? 'Could not send the friend request.',
      );
    }

    return FetFriendActionResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<FetFriendActionResult> respondToFriendRequest({
    required String friendshipId,
    required String action,
  }) async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const FetFriendActionResult(
        status: 'error',
        message: 'club_context_required',
      );
    }

    final result = await SafeRpc.call(
      'fet_respond_friend_request',
      params: <String, dynamic>{
        'p_friendship_id': friendshipId,
        'p_action': action,
        'p_club_id': scope.clubId,
      },
      tag: _tag,
      maxAttempts: 1,
    );

    if (!result.isSuccess || result.data is! Map) {
      return FetFriendActionResult(
        status: 'error',
        message: result.error ?? 'Could not update the friend request.',
      );
    }

    return FetFriendActionResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<List<FetRewardOption>> loadRewardStoreItems() async {
    if (!_storeReleasePolicy.allowsRewardRedemption) {
      return const <FetRewardOption>[];
    }
    final scope = await _scopeResolver.requireResolved();

    try {
      var query = _client
          .from('fet_reward_store_items')
          .select()
          .eq('is_active', true);

      if (scope.clubId != null) {
        query = query.or('club_id.is.null,club_id.eq.${scope.clubId}');
      } else {
        query = query.isFilter('club_id', null);
      }

      final rows = List<Map<String, dynamic>>.from(
        await query.order('sort_order', ascending: true),
      );
      if (rows.isEmpty) {
        return const <FetRewardOption>[];
      }
      return rows.map(FetRewardOption.fromJson).toList(growable: false);
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'FetRepository',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      return const <FetRewardOption>[];
    }
  }

  Future<FetRewardRedemptionResult> redeemReward({
    required String rewardItemId,
    String? note,
    String? idempotencyKey,
  }) async {
    _requireRewardAuthorization();
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const FetRewardRedemptionResult(
        status: 'error',
        message: 'club_context_required',
      );
    }

    final result = await SafeRpc.call(
      'fet_redeem_reward',
      params: <String, dynamic>{
        'p_reward_item_id': rewardItemId,
        'p_note': _storeReleasePolicy.allowsCrossUserText ? note : null,
        'p_idempotency_key': idempotencyKey,
        'p_club_id': scope.clubId,
      },
      tag: _tag,
      maxAttempts: 1,
    );

    if (!result.isSuccess || result.data is! Map) {
      return FetRewardRedemptionResult(
        status: 'error',
        message: result.error ?? 'Could not redeem this reward.',
      );
    }

    return FetRewardRedemptionResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<List<FetRewardRedemption>> loadRewardRedemptions({
    int limit = 20,
    int offset = 0,
  }) async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <FetRewardRedemption>[];
    }

    final result = await SafeRpc.call(
      'fet_get_reward_redemptions',
      params: <String, dynamic>{
        'p_limit': limit,
        'p_offset': offset,
        'p_club_id': scope.clubId,
      },
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return const <FetRewardRedemption>[];
    }

    final rows = (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    return rows.map(FetRewardRedemption.fromJson).toList(growable: false);
  }

  Future<FetExperienceContext> loadExperienceContext({
    int leaderboardLimit = 25,
  }) async {
    final scope = await _scopeResolver.requireResolved();
    final userId = _client.auth.currentUser?.id;

    final results = await Future.wait<Object?>([
      loadCatalog(),
      loadLeaderboard(limit: leaderboardLimit),
      if (userId != null)
        _loadMembership(userId, scope)
      else
        Future.value(null),
      if (userId != null)
        _loadEventRows(userId)
      else
        Future.value(<Map<String, dynamic>>[]),
      if (userId != null) _loadProfile(userId) else Future.value(null),
      if (userId != null)
        _safeMaybeSingle(
          _client
              .from('user_private_contacts')
              .select('momo_number')
              .eq('user_id', userId)
              .maybeSingle(),
        )
      else
        Future.value(null),
      if (userId != null)
        _safeList(
          _client
              .from('group_members')
              .select('id')
              .eq('user_id', userId)
              .limit(1),
        )
      else
        Future.value(<Map<String, dynamic>>[]),
      if (userId != null)
        _safeList(
          _client.from('tickets').select('id').eq('user_id', userId).limit(5),
        )
      else
        Future.value(<Map<String, dynamic>>[]),
    ]);

    final catalog = results[0]! as List<FetCatalogItem>;
    final leaderboard = results[1]! as List<FetLeaderboardRow>;
    final membership = results.length > 2
        ? results[2] as Map<String, dynamic>?
        : null;
    final eventRows = results.length > 3
        ? List<Map<String, dynamic>>.from(results[3]! as List)
        : const <Map<String, dynamic>>[];
    final profile = results.length > 4
        ? results[4] as Map<String, dynamic>?
        : null;
    final privateContact = results.length > 5
        ? results[5] as Map<String, dynamic>?
        : null;
    final groups = results.length > 6
        ? List<Map<String, dynamic>>.from(results[6]! as List)
        : const <Map<String, dynamic>>[];
    final tickets = results.length > 7
        ? List<Map<String, dynamic>>.from(results[7]! as List)
        : const <Map<String, dynamic>>[];

    final currentFet = (membership?['points'] as num?)?.toInt() ?? 0;
    final weeklyFet = _sumWeeklyFet(eventRows);
    final tier = _normalizeTier(
      membership?['tier']?.toString(),
      fallbackPoints: currentFet,
    );
    final nextTier = _nextTierFromFet(currentFet);
    final fanRank =
        leaderboard
            .cast<FetLeaderboardRow?>()
            .firstWhere(
              (entry) => entry?.isCurrentUser == true,
              orElse: () => null,
            )
            ?.rank ??
        0;

    return FetExperienceContext(
      catalog: catalog,
      leaderboard: leaderboard,
      earnedCodes: _deriveEarnedCodes(
        userId: userId,
        profile: profile,
        privateContact: privateContact,
        groups: groups,
        tickets: tickets,
        eventRows: eventRows,
      ),
      currentFet: currentFet,
      weeklyFet: weeklyFet,
      fanRank: fanRank,
      tier: tier,
      nextTier: nextTier,
    );
  }

  Future<FetWalletSummary?> loadWallet() async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return null;
    }

    final result = await SafeRpc.call(
      'fet_get_wallet',
      params: <String, dynamic>{'p_club_id': scope.clubId},
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return null;
    }

    final rows = (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    if (rows.isEmpty) {
      return null;
    }

    return FetWalletSummary.fromJson(rows.first);
  }

  /// Loads the route-level wallet projection without collapsing RPC failures
  /// into an empty wallet.
  ///
  /// Compact wallet surfaces intentionally keep their historical empty
  /// fallback through [loadWallet]. The dedicated wallet route uses this
  /// strict variant so permission and transport failures remain explicit.
  Future<FetWalletSummary?> loadWalletStrict() async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return null;
    }

    final result = await SafeRpc.call(
      'fet_get_wallet',
      params: <String, dynamic>{'p_club_id': scope.clubId},
      tag: _tag,
    );

    if (!result.isSuccess) {
      throw StateError(result.error ?? 'Wallet summary unavailable');
    }
    if (result.data is! List) {
      throw StateError('Wallet summary response was invalid');
    }

    final rows = (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    if (rows.isEmpty) {
      return null;
    }

    return FetWalletSummary.fromJson(rows.first);
  }

  Future<List<FetWalletTransaction>> loadWalletTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <FetWalletTransaction>[];
    }

    final result = await SafeRpc.call(
      'fet_get_wallet_transactions',
      params: <String, dynamic>{
        'p_club_id': scope.clubId,
        'p_limit': limit,
        'p_offset': offset,
      },
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return const <FetWalletTransaction>[];
    }

    final rows = (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    return rows
        .map(_sanitizeWalletTransaction)
        .map(FetWalletTransaction.fromJson)
        .toList(growable: false);
  }

  /// Loads the route-level private ledger without misrepresenting an RPC
  /// failure as an empty transaction history.
  Future<List<FetWalletTransaction>> loadWalletTransactionsStrict({
    int limit = 50,
    int offset = 0,
  }) async {
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <FetWalletTransaction>[];
    }

    final result = await SafeRpc.call(
      'fet_get_wallet_transactions',
      params: <String, dynamic>{
        'p_club_id': scope.clubId,
        'p_limit': limit,
        'p_offset': offset,
      },
      tag: _tag,
    );

    if (!result.isSuccess) {
      throw StateError(result.error ?? 'Wallet history unavailable');
    }
    if (result.data is! List) {
      throw StateError('Wallet history response was invalid');
    }

    final rows = (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    return rows
        .map(_sanitizeWalletTransaction)
        .map(FetWalletTransaction.fromJson)
        .toList(growable: false);
  }

  Future<List<FetWalletSupporter>> findSupporters(
    String query, {
    int limit = 8,
  }) async {
    if (!_storeReleasePolicy.allowsPointsTransfer) {
      return const <FetWalletSupporter>[];
    }
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <FetWalletSupporter>[];
    }

    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const <FetWalletSupporter>[];
    }

    final result = await SafeRpc.call(
      'fet_find_supporters',
      params: <String, dynamic>{
        'p_query': trimmed,
        'p_club_id': scope.clubId,
        'p_limit': limit,
      },
      tag: _tag,
    );

    if (!result.isSuccess || result.data is! List) {
      return const <FetWalletSupporter>[];
    }

    final rows = (result.data as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    return rows
        .map(_sanitizePublicIdentity)
        .map(FetWalletSupporter.fromJson)
        .toList(growable: false);
  }

  Future<FetWalletOperationResult> transferFet({
    required String recipientUserId,
    required int amount,
    String? note,
    String? idempotencyKey,
  }) async {
    _requirePointsTransferAuthorization();
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const FetWalletOperationResult(
        status: 'error',
        amount: 0,
        balance: 0,
        referenceId: null,
        alreadyProcessed: false,
        recipientUserId: null,
      );
    }

    final result = await SafeRpc.call(
      'fet_transfer',
      params: <String, dynamic>{
        'p_recipient_user_id': recipientUserId,
        'p_amount': amount,
        'p_note': _storeReleasePolicy.allowsCrossUserText ? note : null,
        'p_idempotency_key': idempotencyKey,
        'p_club_id': scope.clubId,
      },
      tag: _tag,
      maxAttempts: 1, // Don't retry writes to prevent duplicates.
    );

    if (!result.isSuccess || result.data is! Map) {
      return const FetWalletOperationResult(
        status: 'error',
        amount: 0,
        balance: 0,
        referenceId: null,
        alreadyProcessed: false,
        recipientUserId: null,
      );
    }

    return FetWalletOperationResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<FetWalletOperationResult> redeemFet({
    required int amount,
    String? note,
    String? idempotencyKey,
  }) async {
    _requireManualPointsRedemptionAuthorization();
    final scope = await _scopeResolver.requireResolved();
    if (scope.clubId == null) {
      return const FetWalletOperationResult(
        status: 'error',
        amount: 0,
        balance: 0,
        referenceId: null,
        alreadyProcessed: false,
        recipientUserId: null,
      );
    }

    final result = await SafeRpc.call(
      'fet_redeem',
      params: <String, dynamic>{
        'p_amount': amount,
        'p_note': _storeReleasePolicy.allowsCrossUserText ? note : null,
        'p_idempotency_key': idempotencyKey,
        'p_club_id': scope.clubId,
      },
      tag: _tag,
      maxAttempts: 1, // Don't retry writes to prevent duplicates.
    );

    if (!result.isSuccess || result.data is! Map) {
      return const FetWalletOperationResult(
        status: 'error',
        amount: 0,
        balance: 0,
        referenceId: null,
        alreadyProcessed: false,
        recipientUserId: null,
      );
    }

    return FetWalletOperationResult.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<Map<String, dynamic>?> _loadMembership(
    String userId,
    ClubScope scope,
  ) async {
    var query = _client
        .from('fan_memberships')
        .select('points, tier')
        .eq('user_id', userId)
        .limit(1);
    query = _scopeResolver.apply(query, scope);
    return _safeMaybeSingle(query.maybeSingle());
  }

  Map<String, dynamic> _sanitizePublicIdentity(Map<String, dynamic> row) {
    if (_storeReleasePolicy.allowsCrossUserText) {
      return row;
    }
    return <String, dynamic>{
      ...row,
      'display_name': _storeReleasePolicy.publicSupporterLabel(
        displayName: row['display_name']?.toString(),
        publicUserId:
            row['public_user_id']?.toString() ??
            row['supporter_alias']?.toString(),
        userId: row['user_id']?.toString(),
      ),
    };
  }

  Map<String, dynamic> _sanitizeWalletTransaction(Map<String, dynamic> row) {
    if (_storeReleasePolicy.allowsCrossUserText ||
        row['counterparty_user_id'] == null) {
      return row;
    }
    return <String, dynamic>{
      ...row,
      'counterparty_display_name': _storeReleasePolicy.publicSupporterLabel(
        displayName: row['counterparty_display_name']?.toString(),
        publicUserId: row['counterparty_public_user_id']?.toString(),
        userId: row['counterparty_user_id']?.toString(),
      ),
      'note': null,
    };
  }

  void _requireRewardAuthorization() {
    if (!_storeReleasePolicy.allowsRewardRedemption) {
      throw UnsupportedError(
        'Reward redemption is unavailable in this store release.',
      );
    }
  }

  void _requirePointsTransferAuthorization() {
    if (!_storeReleasePolicy.allowsPointsTransfer) {
      throw UnsupportedError(
        'Points transfer is unavailable in this store release.',
      );
    }
  }

  void _requireManualPointsRedemptionAuthorization() {
    if (!_storeReleasePolicy.allowsManualPointsRedemption) {
      throw UnsupportedError(
        'Manual points redemption is unavailable in this store release.',
      );
    }
  }

  String? _systemAliasQuery(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final normalized = trimmed.replaceAll(RegExp(r'[#\s-]'), '');
    return RegExp(r'^\d{6}$').hasMatch(normalized) ? normalized : null;
  }

  Future<Map<String, dynamic>?> _loadProfile(String userId) {
    return _safeMaybeSingle(
      _client
          .from('profiles')
          .select('full_name, public_user_id, display_name')
          .eq('id', userId)
          .maybeSingle(),
    );
  }

  Future<List<Map<String, dynamic>>> _loadEventRows(String userId) async {
    return List<Map<String, dynamic>>.from(
      await _client
          .from('fet_events')
          .select(
            'id,user_id,club_id,event_type,fet_awarded,event_at,created_at',
          )
          .eq('user_id', userId)
          .order('event_at', ascending: false)
          .limit(250),
    );
  }

  int _sumWeeklyFet(List<Map<String, dynamic>> eventRows) {
    final lowerBound = DateTime.now().toUtc().subtract(const Duration(days: 7));
    return eventRows.fold<int>(0, (sum, row) {
      final eventAt = DateTime.tryParse(row['event_at']?.toString() ?? '');
      if (eventAt == null || eventAt.isBefore(lowerBound)) {
        return sum;
      }
      return sum + ((row['fet_awarded'] as num?)?.toInt() ?? 0);
    });
  }

  Set<String> _deriveEarnedCodes({
    required String? userId,
    required Map<String, dynamic>? profile,
    required Map<String, dynamic>? privateContact,
    required List<Map<String, dynamic>> groups,
    required List<Map<String, dynamic>> tickets,
    required List<Map<String, dynamic>> eventRows,
  }) {
    if (userId == null || userId.isEmpty) {
      return const <String>{};
    }

    final eventKeys = eventRows
        .map((row) => row['event_type']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    final hasProfileName =
        (profile?['full_name']?.toString().trim().isNotEmpty ?? false) ||
        (profile?['display_name']?.toString().trim().isNotEmpty ?? false);
    final hasAlias =
        profile?['public_user_id']?.toString().trim().isNotEmpty ?? false;
    final hasPrivateContact =
        privateContact?['momo_number']?.toString().trim().isNotEmpty ?? false;

    final earnedCodes = <String>{};
    if ((hasProfileName && hasAlias) || hasPrivateContact) {
      earnedCodes.add('G001');
    }
    if (eventKeys.contains('match_attendance')) {
      earnedCodes.addAll(const <String>{'G006'});
    }
    if (eventKeys.contains('invite_friends')) {
      earnedCodes.add('G021');
    }
    if (eventKeys.contains('week_streak')) {
      earnedCodes.add('G016');
    }
    if (eventKeys.contains('shop_purchase')) {
      earnedCodes.addAll(const <String>{'G058', 'G071'});
    }
    if (tickets.isNotEmpty) {
      earnedCodes.add('G035');
    }

    return earnedCodes;
  }

  String _normalizeTier(String? tier, {required int fallbackPoints}) {
    final normalized = tier?.trim().toLowerCase() ?? '';
    if (normalized == 'ingenzi-imanzi' ||
        normalized == 'inyamibwa' ||
        normalized == 'imena' ||
        normalized == 'bronze' ||
        normalized == 'silver' ||
        normalized == 'gold' ||
        normalized == 'ingenzi imanzi') {
      return normalized.replaceAll('-', ' ').toUpperCase();
    }
    if (fallbackPoints >= 5000) return 'GOLD';
    if (fallbackPoints >= 2000) return 'SILVER';
    if (fallbackPoints >= 1000) return 'BRONZE';
    if (fallbackPoints >= 500) return 'IMENA';
    if (fallbackPoints >= 250) return 'INYAMIBWA';
    return 'INGENZI IMANZI';
  }

  String _nextTierFromFet(int currentFet) {
    if (currentFet >= 5000) return 'GOLD';
    if (currentFet >= 2000) return 'GOLD';
    if (currentFet >= 1000) return 'SILVER';
    if (currentFet >= 500) return 'BRONZE';
    if (currentFet >= 250) return 'IMENA';
    return 'INYAMIBWA';
  }

  Future<Map<String, dynamic>?> _safeMaybeSingle(
    Future<Map<String, dynamic>?> future,
  ) async {
    try {
      return await future;
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'FetRepository',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _safeList(
    Future<List<dynamic>> future,
  ) async {
    try {
      return List<Map<String, dynamic>>.from(await future);
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'FetRepository',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      return const <Map<String, dynamic>>[];
    }
  }
}
