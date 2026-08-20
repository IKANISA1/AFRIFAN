import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum GoogleWalletSaveResult { saved, cancelled }

enum GoogleWalletAddPhase { idle, adding, added, cancelled, failed }

enum GoogleWalletFailureKind {
  offline,
  unavailable,
  paymentPending,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class GoogleWalletFailure implements Exception {
  const GoogleWalletFailure(this.kind);

  final GoogleWalletFailureKind kind;

  static GoogleWalletFailure fromError(Object error) {
    if (error is GoogleWalletFailure) return error;
    if (error is TimeoutException) {
      return const GoogleWalletFailure(GoogleWalletFailureKind.securityTimeout);
    }
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map) {
        final payload = Map<Object?, Object?>.from(details);
        final safeCode = payload['code'] ?? payload['error'];
        if (safeCode != null) return fromError(safeCode);
      }
      if (error.status == 401 || error.status == 403) {
        return const GoogleWalletFailure(
          GoogleWalletFailureKind.permissionDenied,
        );
      }
      if (error.status == 409) {
        return const GoogleWalletFailure(GoogleWalletFailureKind.conflict);
      }
      return const GoogleWalletFailure(GoogleWalletFailureKind.unknown);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('cancelled') || normalized.contains('canceled')) {
      return const GoogleWalletFailure(GoogleWalletFailureKind.conflict);
    }
    if (normalized.contains('payment_pending')) {
      return const GoogleWalletFailure(GoogleWalletFailureKind.paymentPending);
    }
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized')) {
      return const GoogleWalletFailure(
        GoogleWalletFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('not_active') ||
        normalized.contains('expired')) {
      return const GoogleWalletFailure(GoogleWalletFailureKind.conflict);
    }
    if (normalized.contains('unavailable') ||
        normalized.contains('not configured')) {
      return const GoogleWalletFailure(GoogleWalletFailureKind.unavailable);
    }
    return const GoogleWalletFailure(GoogleWalletFailureKind.unknown);
  }

  @override
  String toString() => 'GoogleWalletFailure(${kind.name})';
}

class GoogleWalletAddState {
  const GoogleWalletAddState({
    this.phase = GoogleWalletAddPhase.idle,
    this.failure,
  });

  final GoogleWalletAddPhase phase;
  final GoogleWalletFailure? failure;
}

abstract interface class GoogleWalletPassGateway {
  Future<String> issueSaveJwt(String ticketId);
}

abstract interface class GoogleWalletPlatformGateway {
  Future<bool> isAvailable();

  Future<GoogleWalletSaveResult> savePassJwt(String jwt);
}

class SupabaseGoogleWalletPassGateway implements GoogleWalletPassGateway {
  const SupabaseGoogleWalletPassGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<String> issueSaveJwt(String ticketId) async {
    final response = await _client.functions.invoke(
      'google-wallet-ticket-pass',
      body: <String, dynamic>{'ticket_id': ticketId},
    );
    final body = response.data;
    if (body is! Map) {
      throw const GoogleWalletFailure(GoogleWalletFailureKind.unknown);
    }
    final payload = Map<String, dynamic>.from(body);
    if (payload['success'] != true || payload['data'] is! Map) {
      throw GoogleWalletFailure.fromError(payload['code'] ?? payload['error']);
    }
    final data = Map<String, dynamic>.from(payload['data'] as Map);
    final jwt = data['save_jwt'];
    if (jwt is! String || jwt.trim().isEmpty || jwt.length > 16 * 1024) {
      throw const GoogleWalletFailure(GoogleWalletFailureKind.unknown);
    }
    return jwt.trim();
  }
}

class MethodChannelGoogleWalletPlatformGateway
    implements GoogleWalletPlatformGateway {
  const MethodChannelGoogleWalletPlatformGateway({
    MethodChannel channel = const MethodChannel('africlub/google_wallet'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<GoogleWalletSaveResult> savePassJwt(String jwt) async {
    try {
      final saved = await _channel.invokeMethod<bool>(
        'savePassJwt',
        <String, dynamic>{'jwt': jwt},
      );
      return saved == true
          ? GoogleWalletSaveResult.saved
          : GoogleWalletSaveResult.cancelled;
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') return GoogleWalletSaveResult.cancelled;
      if (error.code == 'unavailable') {
        throw const GoogleWalletFailure(GoogleWalletFailureKind.unavailable);
      }
      throw const GoogleWalletFailure(GoogleWalletFailureKind.unknown);
    } on MissingPluginException {
      throw const GoogleWalletFailure(GoogleWalletFailureKind.unavailable);
    }
  }
}

final googleWalletPassGatewayProvider = Provider<GoogleWalletPassGateway>(
  (ref) => SupabaseGoogleWalletPassGateway(ref.watch(supabaseClientProvider)),
);

final googleWalletPlatformGatewayProvider =
    Provider<GoogleWalletPlatformGateway>(
      (ref) => const MethodChannelGoogleWalletPlatformGateway(),
    );

final googleWalletAvailabilityProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(googleWalletPlatformGatewayProvider).isAvailable(),
);

final googleWalletControllerProvider = StateNotifierProvider.autoDispose
    .family<GoogleWalletController, GoogleWalletAddState, String>((
      ref,
      ticketId,
    ) {
      return GoogleWalletController(
        ticketId: ticketId,
        passGateway: ref.watch(googleWalletPassGatewayProvider),
        platformGateway: ref.watch(googleWalletPlatformGatewayProvider),
      );
    });

class GoogleWalletController extends StateNotifier<GoogleWalletAddState> {
  GoogleWalletController({
    required String ticketId,
    required GoogleWalletPassGateway passGateway,
    required GoogleWalletPlatformGateway platformGateway,
    Duration timeout = const Duration(seconds: 20),
  }) : _ticketId = ticketId,
       _passGateway = passGateway,
       _platformGateway = platformGateway,
       _timeout = timeout,
       super(const GoogleWalletAddState());

  final String _ticketId;
  final GoogleWalletPassGateway _passGateway;
  final GoogleWalletPlatformGateway _platformGateway;
  final Duration _timeout;
  bool _adding = false;

  Future<void> add() async {
    if (_adding) return;
    if (!ConnectivityService.isOnline) {
      state = const GoogleWalletAddState(
        phase: GoogleWalletAddPhase.failed,
        failure: GoogleWalletFailure(GoogleWalletFailureKind.offline),
      );
      return;
    }
    _adding = true;
    state = const GoogleWalletAddState(phase: GoogleWalletAddPhase.adding);
    try {
      final available = await _platformGateway.isAvailable().timeout(_timeout);
      if (!available) {
        throw const GoogleWalletFailure(GoogleWalletFailureKind.unavailable);
      }
      final jwt = await _passGateway.issueSaveJwt(_ticketId).timeout(_timeout);
      final result = await _platformGateway.savePassJwt(jwt).timeout(_timeout);
      state = GoogleWalletAddState(
        phase: result == GoogleWalletSaveResult.saved
            ? GoogleWalletAddPhase.added
            : GoogleWalletAddPhase.cancelled,
      );
    } catch (error) {
      state = GoogleWalletAddState(
        phase: GoogleWalletAddPhase.failed,
        failure: GoogleWalletFailure.fromError(error),
      );
    } finally {
      _adding = false;
    }
  }
}
