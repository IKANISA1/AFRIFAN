import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A realtime message invalidates the public projection; it is not that
/// projection. Requerying also restores events missed during a disconnect.
class LiveMatchController extends ChangeNotifier {
  LiveMatchController({
    required SupabaseClient client,
    ClubScopeResolver? scopeResolver,
    RealtimeService Function(String clubId)? realtimeFactory,
    this.pollInterval = const Duration(seconds: 30),
    this.requestTimeout = const Duration(seconds: 8),
  }) : _client = client,
       _scopeResolver = scopeResolver ?? ClubScopeResolver(client: client),
       _realtimeFactory =
           realtimeFactory ??
           ((clubId) => RealtimeService(clubId: clubId, client: client));

  final SupabaseClient _client;
  final ClubScopeResolver _scopeResolver;
  final RealtimeService Function(String clubId) _realtimeFactory;
  final Duration pollInterval;
  final Duration requestTimeout;
  RealtimeService? _realtime;
  Timer? _timer;
  Future<void>? _refreshing;
  String? _subscriptionKey;
  bool _refreshAgain = false;
  bool _disposed = false;
  bool _active = true;

  Map<String, dynamic>? match;
  Object? error;
  bool loading = true;

  Future<void> start() {
    _timer ??= Timer.periodic(pollInterval, (_) {
      if (_active) unawaited(refresh());
    });
    return refresh();
  }

  void setActive(bool active) {
    final resumed = active && !_active;
    _active = active;
    if (resumed && !_disposed) unawaited(refresh());
  }

  Future<void> refresh() {
    if (_disposed || !_active) return Future<void>.value();
    final running = _refreshing;
    if (running != null) {
      _refreshAgain = true;
      return running;
    }
    final operation = _refreshLoop();
    _refreshing = operation;
    return operation.whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshLoop() async {
    do {
      _refreshAgain = false;
      try {
        final scope = await _scopeResolver.requireResolved().timeout(
          requestTimeout,
        );
        final matches = await PublicMatchWindow(_client)
            .load(clubId: scope.requiredClubId, limitPerSection: 4)
            .timeout(requestTimeout);
        if (_disposed || !_active) return;
        // The window orders live, future and recent results independently.
        // Historic seasons cannot hide today's featured fixture.
        match = matches.isEmpty ? null : matches.first;
        error = null;
        loading = false;
        notifyListeners();
        await _bind(scope.requiredClubId, match);
      } catch (failure) {
        if (_disposed || !_active) return;
        error = failure;
        loading = false;
        // Preserve the last confirmed projection while reporting refresh loss.
        notifyListeners();
      }
    } while (_refreshAgain && !_disposed && _active);
  }

  Future<void> _bind(int clubId, Map<String, dynamic>? selected) async {
    final legacyId = selected?['legacy_match_id']?.toString();
    final fixtureId = selected?['fixture_id']?.toString();
    final key = '$clubId:$legacyId:$fixtureId';
    if (key == _subscriptionKey) return;
    final previous = _realtime;
    _realtime = null;
    await previous?.dispose();
    if (_disposed || !_active) {
      _subscriptionKey = null;
      return;
    }
    _subscriptionKey = key;
    if (selected == null) return;
    final service = _realtimeFactory(clubId.toString());
    _realtime = service;
    void invalidate() {
      if (_realtime == service && !_disposed && _active) {
        unawaited(refresh());
      }
    }

    if (legacyId != null && legacyId.isNotEmpty) {
      service.onTableChanges(
        table: 'matches',
        filterColumn: 'id',
        filterValue: legacyId,
        callback: (_) => invalidate(),
        onSubscribed: invalidate,
      );
    }
    if (fixtureId != null && fixtureId.isNotEmpty) {
      service.onTableChanges(
        schema: 'football',
        table: 'fixtures',
        filterColumn: 'id',
        filterValue: fixtureId,
        callback: (_) => invalidate(),
        onSubscribed: invalidate,
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_realtime?.dispose());
    super.dispose();
  }
}
