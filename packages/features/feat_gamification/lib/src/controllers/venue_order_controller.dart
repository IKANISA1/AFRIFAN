import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum VenueOrderPhase { ready, syncing, degraded, confirmed }

enum VenueOrderFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  invalidSelection,
  checkinRequired,
  ageGateRequired,
  itemUnavailable,
  unknown,
}

class VenueOrderFailure implements Exception {
  const VenueOrderFailure(this.kind);

  final VenueOrderFailureKind kind;

  static VenueOrderFailure fromError(Object error) {
    if (error is VenueOrderFailure) return error;
    if (error is TimeoutException) {
      return const VenueOrderFailure(VenueOrderFailureKind.securityTimeout);
    }
    final text = error.toString().toLowerCase();
    if (text.contains('permission') ||
        text.contains('forbidden') ||
        text.contains('unauthorized') ||
        text.contains('auth_required') ||
        text.contains('row-level security') ||
        text.contains('rls')) {
      return const VenueOrderFailure(VenueOrderFailureKind.permissionDenied);
    }
    if (text.contains('conflict') ||
        text.contains('stale') ||
        text.contains('already') ||
        text.contains('busy')) {
      return const VenueOrderFailure(VenueOrderFailureKind.conflict);
    }
    if (text.contains('age gate')) {
      return const VenueOrderFailure(VenueOrderFailureKind.ageGateRequired);
    }
    if (text.contains('drink item') || text.contains('item_unavailable')) {
      return const VenueOrderFailure(VenueOrderFailureKind.itemUnavailable);
    }
    return const VenueOrderFailure(VenueOrderFailureKind.unknown);
  }

  @override
  String toString() => 'VenueOrderFailure(${kind.name})';
}

class VenueDrinkItem {
  const VenueDrinkItem({
    required this.id,
    required this.venueId,
    required this.name,
    required this.priceAmount,
    required this.currencyCode,
    this.description = '',
    this.isAlcohol = false,
  });

  factory VenueDrinkItem.fromJson(Map<String, dynamic> json) {
    return VenueDrinkItem(
      id: json['id']?.toString() ?? '',
      venueId: json['venue_id']?.toString() ?? '',
      name: json['item_name']?.toString() ?? 'Drink',
      description: json['description']?.toString() ?? '',
      priceAmount: (json['price_amount'] as num?)?.toInt() ?? 0,
      currencyCode: json['currency_code']?.toString() ?? 'RWF',
      isAlcohol: json['is_alcohol'] == true,
    );
  }

  final String id;
  final String venueId;
  final String name;
  final String description;
  final int priceAmount;
  final String currencyCode;
  final bool isAlcohol;
}

class VenueOrderResult {
  const VenueOrderResult({
    required this.status,
    required this.code,
    this.orderId,
    this.totalAmount = 0,
    this.currencyCode = 'RWF',
    this.paymentStatus = 'external_pending',
  });

  factory VenueOrderResult.fromJson(Map<String, dynamic> json) {
    return VenueOrderResult(
      status: json['status']?.toString() ?? 'error',
      code: json['code']?.toString() ?? 'unknown',
      orderId: json['order_id']?.toString() ?? json['id']?.toString(),
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      currencyCode: json['currency_code']?.toString() ?? 'RWF',
      paymentStatus: json['payment_status']?.toString() ?? 'external_pending',
    );
  }

  final String status;
  final String code;
  final String? orderId;
  final int totalAmount;
  final String currencyCode;
  final String paymentStatus;

  bool get isAccepted =>
      code == 'ok' ||
      code == 'idempotent_replay' ||
      status == 'created' ||
      status == 'accepted' ||
      status == 'preparing' ||
      status == 'ready' ||
      status == 'served';
}

class VenueOrderContext {
  const VenueOrderContext({
    this.checkinId,
    this.venueId,
    this.menu = const <VenueDrinkItem>[],
    this.latestOrder,
  });

  final String? checkinId;
  final String? venueId;
  final List<VenueDrinkItem> menu;
  final VenueOrderResult? latestOrder;

  bool get hasCheckin =>
      checkinId != null &&
      checkinId!.isNotEmpty &&
      venueId != null &&
      venueId!.isNotEmpty;
}

class VenueOrderRouteState {
  const VenueOrderRouteState({
    this.context = const VenueOrderContext(),
    this.quantities = const <String, int>{},
    this.ageGateConfirmed = false,
    this.phase = VenueOrderPhase.ready,
    this.failure,
    this.result,
    this.uncertainMutation = false,
  });

  final VenueOrderContext context;
  final Map<String, int> quantities;
  final bool ageGateConfirmed;
  final VenueOrderPhase phase;
  final VenueOrderFailure? failure;
  final VenueOrderResult? result;
  final bool uncertainMutation;

  int quantityFor(String itemId) => quantities[itemId] ?? 0;

  int get totalItems =>
      quantities.values.fold<int>(0, (sum, quantity) => sum + quantity);

  int get totalAmount {
    var amount = 0;
    for (final item in context.menu) {
      amount += item.priceAmount * quantityFor(item.id);
    }
    return amount;
  }

  String get currencyCode =>
      context.menu.isEmpty ? 'RWF' : context.menu.first.currencyCode;

  bool get hasAlcoholSelection =>
      context.menu.any((item) => item.isAlcohol && quantityFor(item.id) > 0);

  bool get actionsBlocked =>
      phase == VenueOrderPhase.syncing ||
      phase == VenueOrderPhase.confirmed ||
      failure != null ||
      uncertainMutation;

  VenueOrderResult? get displayedOrder => result ?? context.latestOrder;

  VenueOrderRouteState copyWith({
    VenueOrderContext? context,
    Map<String, int>? quantities,
    bool? ageGateConfirmed,
    VenueOrderPhase? phase,
    VenueOrderFailure? failure,
    VenueOrderResult? result,
    bool? uncertainMutation,
    bool clearFailure = false,
    bool clearResult = false,
  }) {
    return VenueOrderRouteState(
      context: context ?? this.context,
      quantities: quantities ?? this.quantities,
      ageGateConfirmed: ageGateConfirmed ?? this.ageGateConfirmed,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
      result: clearResult ? null : result ?? this.result,
      uncertainMutation: uncertainMutation ?? this.uncertainMutation,
    );
  }
}

abstract interface class VenueOrderGateway {
  Future<VenueOrderContext> load();

  Future<VenueOrderResult> create({
    required VenueOrderContext context,
    required Map<String, int> quantities,
    required bool ageGateConfirmed,
    required String idempotencyKey,
  });
}

class RepositoryVenueOrderGateway implements VenueOrderGateway {
  RepositoryVenueOrderGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<VenueOrderContext> load() async {
    final scope = await ClubScopeResolver(client: _client).requireResolved();
    final clubId = scope.clubId;
    if (clubId == null) {
      throw const VenueOrderFailure(VenueOrderFailureKind.permissionDenied);
    }

    final checkinRows = List<Map<String, dynamic>>.from(
      await _client
          .from('venue_checkins')
          .select('id, venue_id, status, checked_in_at')
          .eq('club_id', clubId)
          .inFilter('status', const <String>['confirmed', 'pending_review'])
          .order('checked_in_at', ascending: false)
          .limit(1),
    );
    if (checkinRows.isEmpty) return const VenueOrderContext();

    final checkinId = checkinRows.first['id']?.toString();
    final venueId = checkinRows.first['venue_id']?.toString();
    if (checkinId == null ||
        checkinId.isEmpty ||
        venueId == null ||
        venueId.isEmpty) {
      throw const VenueOrderFailure(VenueOrderFailureKind.permissionDenied);
    }

    final results = await Future.wait<dynamic>([
      _client
          .from('venue_drink_items')
          .select(
            'id, venue_id, item_name, description, price_amount, '
            'currency_code, is_alcohol, sort_order',
          )
          .eq('club_id', clubId)
          .eq('venue_id', venueId)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .limit(10),
      _client
          .from('venue_drink_orders')
          .select(
            'id, status, total_amount, currency_code, payment_status, created_at',
          )
          .eq('club_id', clubId)
          .eq('checkin_id', checkinId)
          .order('created_at', ascending: false)
          .limit(1),
    ]);
    final menuRows = List<Map<String, dynamic>>.from(results.first as List);
    final orderRows = List<Map<String, dynamic>>.from(results.last as List);

    return VenueOrderContext(
      checkinId: checkinId,
      venueId: venueId,
      menu: menuRows.map(VenueDrinkItem.fromJson).toList(growable: false),
      latestOrder: orderRows.isEmpty
          ? null
          : VenueOrderResult.fromJson(orderRows.first),
    );
  }

  @override
  Future<VenueOrderResult> create({
    required VenueOrderContext context,
    required Map<String, int> quantities,
    required bool ageGateConfirmed,
    required String idempotencyKey,
  }) async {
    final scope = await ClubScopeResolver(client: _client).requireResolved();
    final clubId = scope.clubId;
    if (clubId == null || !context.hasCheckin) {
      throw const VenueOrderFailure(VenueOrderFailureKind.permissionDenied);
    }
    final items = context.menu
        .where((item) => (quantities[item.id] ?? 0) > 0)
        .map(
          (item) => <String, dynamic>{
            'drink_item_id': item.id,
            'quantity': quantities[item.id],
          },
        )
        .toList(growable: false);
    final response = await SafeRpc.call(
      'venue_order_create',
      params: <String, dynamic>{
        'p_club_id': clubId,
        'p_venue_id': context.venueId,
        'p_checkin_id': context.checkinId,
        'p_items': items,
        'p_age_gate_confirmed': ageGateConfirmed,
        'p_idempotency_key': idempotencyKey,
      },
      tag: 'VenueOrder',
      maxAttempts: 1,
    );
    if (!response.isSuccess || response.data is! Map) {
      throw StateError(response.error ?? 'Venue order returned no result.');
    }
    return VenueOrderResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

class VenueOrderController
    extends StateNotifier<AsyncValue<VenueOrderRouteState>> {
  VenueOrderController(
    this._gateway, {
    Duration loadTimeout = const Duration(seconds: 12),
    Duration mutationTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : _loadTimeout = loadTimeout,
       _mutationTimeout = mutationTimeout,
       super(const AsyncLoading<VenueOrderRouteState>()) {
    if (autoLoad) unawaited(load());
  }

  final VenueOrderGateway _gateway;
  final Duration _loadTimeout;
  final Duration _mutationTimeout;
  bool _loading = false;
  bool _submitting = false;
  int _attempt = 0;

  Future<void> load() => _load(preserveCurrent: false);

  Future<void> refresh() => _load(preserveCurrent: true);

  Future<void> connectionRestored() async {
    final current = state.valueOrNull;
    if (current?.failure?.kind != VenueOrderFailureKind.offline ||
        current?.uncertainMutation == true) {
      return;
    }
    await refresh();
  }

  void setQuantity(String itemId, int quantity) {
    final current = state.valueOrNull;
    if (_submitting ||
        current == null ||
        current.phase == VenueOrderPhase.confirmed ||
        current.uncertainMutation) {
      return;
    }
    final exists = current.context.menu.any((item) => item.id == itemId);
    if (!exists) return;
    final next = Map<String, int>.from(current.quantities);
    final normalized = quantity.clamp(0, 20);
    if (normalized == 0) {
      next.remove(itemId);
    } else {
      next[itemId] = normalized;
    }
    final hasAlcohol = current.context.menu.any(
      (item) => item.isAlcohol && (next[item.id] ?? 0) > 0,
    );
    state = AsyncValue.data(
      current.copyWith(
        quantities: next,
        ageGateConfirmed: hasAlcohol ? current.ageGateConfirmed : false,
        phase: VenueOrderPhase.ready,
        clearFailure: true,
        clearResult: true,
      ),
    );
  }

  void setAgeGateConfirmed(bool value) {
    final current = state.valueOrNull;
    if (_submitting ||
        current == null ||
        current.phase == VenueOrderPhase.confirmed ||
        current.uncertainMutation ||
        !current.hasAlcoholSelection) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(
        ageGateConfirmed: value,
        phase: VenueOrderPhase.ready,
        clearFailure: true,
      ),
    );
  }

  void acknowledgeFailure() {
    final current = state.valueOrNull;
    if (_submitting || current == null || current.failure == null) return;
    state = AsyncValue.data(
      current.copyWith(
        phase: VenueOrderPhase.ready,
        clearFailure: true,
        uncertainMutation: false,
      ),
    );
  }

  Future<bool> submit() async {
    final current = state.valueOrNull;
    if (_submitting || current == null || current.actionsBlocked) return false;
    if (!current.context.hasCheckin) {
      _retainFailure(
        current,
        const VenueOrderFailure(VenueOrderFailureKind.checkinRequired),
      );
      return false;
    }
    if (current.totalItems == 0) {
      _retainFailure(
        current,
        const VenueOrderFailure(VenueOrderFailureKind.invalidSelection),
      );
      return false;
    }
    if (current.hasAlcoholSelection && !current.ageGateConfirmed) {
      _retainFailure(
        current,
        const VenueOrderFailure(VenueOrderFailureKind.ageGateRequired),
      );
      return false;
    }
    if (!ConnectivityService.isOnline) {
      _retainFailure(
        current,
        const VenueOrderFailure(VenueOrderFailureKind.offline),
      );
      return false;
    }

    _submitting = true;
    _attempt += 1;
    final idempotencyKey =
        'venue-order-${DateTime.now().microsecondsSinceEpoch}-$_attempt';
    state = AsyncValue.data(
      current.copyWith(
        phase: VenueOrderPhase.syncing,
        clearFailure: true,
        clearResult: true,
      ),
    );
    try {
      final result = await _gateway
          .create(
            context: current.context,
            quantities: current.quantities,
            ageGateConfirmed: current.ageGateConfirmed,
            idempotencyKey: idempotencyKey,
          )
          .timeout(_mutationTimeout);
      if (!result.isAccepted) {
        _retainFailure(current, _failureForCode(result.code));
        return false;
      }
      state = AsyncValue.data(
        current.copyWith(
          phase: VenueOrderPhase.confirmed,
          result: result,
          clearFailure: true,
          uncertainMutation: false,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'VenueOrderController',
        'Venue order failed.',
        error,
        stackTrace,
      );
      final failure = VenueOrderFailure.fromError(error);
      _retainFailure(
        current,
        failure,
        uncertain: failure.kind == VenueOrderFailureKind.securityTimeout,
      );
      return false;
    } finally {
      _submitting = false;
    }
  }

  Future<void> _load({required bool preserveCurrent}) async {
    if (_loading || _submitting) return;
    _loading = true;
    final previous = state.valueOrNull;
    state = preserveCurrent && previous?.context.hasCheckin == true
        ? const AsyncLoading<VenueOrderRouteState>().copyWithPrevious(state)
        : const AsyncLoading<VenueOrderRouteState>();
    try {
      if (!ConnectivityService.isOnline) {
        throw const VenueOrderFailure(VenueOrderFailureKind.offline);
      }
      final loaded = await _gateway.load().timeout(_loadTimeout);
      final retainedQuantities = <String, int>{};
      if (preserveCurrent && previous != null) {
        for (final item in loaded.menu) {
          final quantity = previous.quantityFor(item.id);
          if (quantity > 0) retainedQuantities[item.id] = quantity;
        }
      }
      state = AsyncValue.data(
        VenueOrderRouteState(
          context: loaded,
          quantities: retainedQuantities,
          ageGateConfirmed:
              previous?.ageGateConfirmed == true &&
              loaded.menu.any(
                (item) =>
                    item.isAlcohol && (retainedQuantities[item.id] ?? 0) > 0,
              ),
        ),
      );
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'VenueOrderController',
        'Venue order context failed to load.',
        error,
        stackTrace,
      );
      final failure = VenueOrderFailure.fromError(error);
      state = previous?.context.hasCheckin == true
          ? AsyncValue.data(
              previous!.copyWith(
                phase: VenueOrderPhase.degraded,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }

  void _retainFailure(
    VenueOrderRouteState current,
    VenueOrderFailure failure, {
    bool uncertain = false,
  }) {
    state = AsyncValue.data(
      current.copyWith(
        phase: VenueOrderPhase.degraded,
        failure: failure,
        uncertainMutation: uncertain,
      ),
    );
  }

  VenueOrderFailure _failureForCode(String code) {
    return VenueOrderFailure(switch (code) {
      'items_required' => VenueOrderFailureKind.invalidSelection,
      'checkin_required' => VenueOrderFailureKind.checkinRequired,
      'auth_required' => VenueOrderFailureKind.permissionDenied,
      'age_gate_required' => VenueOrderFailureKind.ageGateRequired,
      'item_unavailable' => VenueOrderFailureKind.itemUnavailable,
      _ => VenueOrderFailureKind.unknown,
    });
  }
}
