import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/biopay_enrollment_draft.dart';
import '../models/biopay_handoff_resolution.dart';
import '../models/biopay_handoff_token.dart';
import '../models/biopay_liveness_challenge.dart';
import '../models/biopay_match_result.dart';
import '../models/biopay_payment_intent.dart';
import '../models/biopay_profile.dart';
import '../services/biopay_rate_limiter.dart';

typedef BiopayAppCheckTokenProvider = Future<String> Function();

/// Central repository for BioPay backend operations.
///
/// Interacts with Supabase edge functions:
/// - `biopay-enroll` — register a new face
/// - `biopay-match` — search for a matching face
/// - `biopay-revoke` — deactivate an enrollment
/// - `biopay-create-payment-intent` — generate a server-issued payment intent
class BiopayRepository {
  BiopayRepository({
    required SupabaseClient client,
    OperationalHealthService? healthService,
    BiopayRateLimiter? rateLimiter,
    BiopayAppCheckTokenProvider? appCheckTokenProvider,
  }) : _client = client,
       _healthService =
           healthService ?? OperationalHealthService(client: client),
       _rateLimiter = rateLimiter ?? BiopayRateLimiter(),
       _appCheckTokenProvider =
           appCheckTokenProvider ??
           (() =>
               AppCheckService.requireLimitedUseToken(featureName: 'BioPay'));

  final SupabaseClient _client;
  final OperationalHealthService _healthService;
  final BiopayRateLimiter _rateLimiter;
  final BiopayAppCheckTokenProvider _appCheckTokenProvider;

  Future<Map<String, String>> _buildAttestedHeaders() async {
    final token = await _appCheckTokenProvider();
    return <String, String>{'X-Firebase-AppCheck': token};
  }

  // ─── Enrollment ─────────────────────────────────────────────

  Future<BiopayLivenessChallenge> createLivenessChallenge({
    required String mode,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError(
        'BioPay liveness challenge requires an authenticated user.',
      );
    }

    try {
      final headers = await _buildAttestedHeaders();
      final response = await _client.functions.invoke(
        'biopay-create-liveness-challenge',
        body: <String, dynamic>{'mode': mode},
        headers: headers,
      );
      final data = _extractDataEnvelope(
        response,
        'biopay-create-liveness-challenge',
      );
      return BiopayLivenessChallenge.fromApiResponse(data);
    } catch (error) {
      await _recordFailure('create_liveness_challenge', error, userId: userId);
      rethrow;
    }
  }

  // ─── Enrollment ─────────────────────────────────────────────

  /// Enroll a new face with the given embedding and draft data.
  Future<BiopayProfile> enroll({
    required List<double> embedding,
    required BiopayEnrollmentDraft draft,
    Map<String, Object?>? livenessMetadata,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('BioPay enrollment requires an authenticated user.');
    }

    // Rate limit check
    final rateLimitMsg = _rateLimiter.checkEnrollmentAllowed();
    if (rateLimitMsg != null) {
      await _recordFailure(
        'enroll_rate_limited',
        StateError(rateLimitMsg),
        userId: userId,
      );
      throw StateError(rateLimitMsg);
    }
    _rateLimiter.recordEnrollmentAttempt();

    try {
      final headers = await _buildAttestedHeaders();
      final response = await _client.functions.invoke(
        'biopay-enroll',
        body: <String, dynamic>{
          ...draft.toPayload(embedding, liveness: livenessMetadata),
        },
        headers: headers,
      );

      final data = _extractDataEnvelope(response, 'biopay-enroll');
      return BiopayProfile.fromJson(data);
    } catch (error) {
      await _recordFailure('enroll', error, userId: userId);
      rethrow;
    }
  }

  // ─── Matching ───────────────────────────────────────────────

  /// Match a face embedding against enrolled profiles.
  Future<BiopayMatchResult> match({
    required List<double> embedding,
    double? threshold,
    Map<String, Object?>? livenessMetadata,
  }) async {
    final userId = _client.auth.currentUser?.id;

    // Rate limit check
    final rateLimitMsg = _rateLimiter.checkMatchAllowed();
    if (rateLimitMsg != null) {
      await _recordFailure(
        'match_rate_limited',
        StateError(rateLimitMsg),
        userId: userId,
      );
      throw StateError(rateLimitMsg);
    }
    _rateLimiter.recordMatchAttempt();

    try {
      final headers = await _buildAttestedHeaders();
      final response = await _client.functions.invoke(
        'biopay-match',
        body: <String, dynamic>{
          'embedding': embedding,
          if (threshold != null) 'threshold': threshold,
          ...?(livenessMetadata == null
              ? null
              : <String, dynamic>{'liveness': livenessMetadata}),
        },
        headers: headers,
      );

      final data = _extractDataEnvelope(response, 'biopay-match');
      return BiopayMatchResult.fromApiResponse(data);
    } catch (error) {
      await _recordFailure('match', error, userId: userId);
      rethrow;
    }
  }

  // ─── Revocation ─────────────────────────────────────────────

  /// Revoke (deactivate) a BioPay enrollment.
  Future<void> revoke({String? reason}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('BioPay revocation requires an authenticated user.');
    }

    try {
      final headers = await _buildAttestedHeaders();
      final response = await _client.functions.invoke(
        'biopay-revoke',
        body: <String, dynamic>{if (reason != null) 'reason': reason},
        headers: headers,
      );
      _extractDataEnvelope(response, 'biopay-revoke');
    } catch (error) {
      await _recordFailure('revoke', error, userId: userId);
      rethrow;
    }
  }

  // ─── Payment Intent ─────────────────────────────────────────

  /// Create a server-issued payment intent bound to a biometric match.
  Future<BiopayPaymentIntent> createPaymentIntent({
    required String matchReceipt,
    int? amount,
  }) async {
    final userId = _client.auth.currentUser?.id;

    // Rate limit check
    final rateLimitMsg = _rateLimiter.checkPaymentIntentAllowed();
    if (rateLimitMsg != null) {
      await _recordFailure(
        'payment_intent_rate_limited',
        StateError(rateLimitMsg),
        userId: userId,
      );
      throw StateError(rateLimitMsg);
    }
    _rateLimiter.recordPaymentIntentAttempt();

    try {
      final headers = await _buildAttestedHeaders();
      final response = await _client.functions.invoke(
        'biopay-create-payment-intent',
        body: <String, dynamic>{
          'match_receipt': matchReceipt,
          if (amount != null) 'amount': amount,
        },
        headers: headers,
      );

      final data = _extractDataEnvelope(
        response,
        'biopay-create-payment-intent',
      );
      return BiopayPaymentIntent.fromApiResponse(data);
    } catch (error) {
      await _recordFailure('create_payment_intent', error, userId: userId);
      rethrow;
    }
  }

  // ─── QR / NFC Handoff ──────────────────────────────────────

  Future<BiopayHandoffToken> createHandoffToken({
    required String channel,
    int? amount,
    String? reference,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError(
        'BioPay handoff generation requires an authenticated user.',
      );
    }

    try {
      final headers = await _buildAttestedHeaders();
      final response = await _client.functions.invoke(
        'biopay-create-handoff-token',
        body: <String, dynamic>{
          'channel': channel,
          if (amount != null) 'amount': amount,
          if (reference != null && reference.trim().isNotEmpty)
            'reference': reference.trim(),
        },
        headers: headers,
      );

      final data = _extractDataEnvelope(
        response,
        'biopay-create-handoff-token',
      );
      return BiopayHandoffToken.fromApiResponse(data);
    } catch (error) {
      await _recordFailure('create_handoff_token', error, userId: userId);
      rethrow;
    }
  }

  Future<BiopayHandoffResolution> resolveHandoffToken({
    required String token,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'biopay-resolve-handoff',
        body: <String, dynamic>{'token': token},
      );
      final data = _extractDataEnvelope(response, 'biopay-resolve-handoff');
      return BiopayHandoffResolution.fromApiResponse(data);
    } catch (error) {
      await _recordFailure('resolve_handoff_token', error);
      rethrow;
    }
  }

  // ─── Profile Query ──────────────────────────────────────────

  /// Fetch the current user's BioPay profile (if enrolled).
  Future<BiopayProfile?> fetchCurrentUserProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return null;

    try {
      final row = await _client
          .from('biopay_profiles')
          .select()
          .eq('user_id', userId)
          .eq('active', true)
          .order('created_at', ascending: false)
          .maybeSingle();

      if (row != null) {
        return BiopayProfile.fromJson(Map<String, dynamic>.from(row));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── Intent Lifecycle ───────────────────────────────────────

  /// Mark a payment intent as dialed (one-time use consumed).
  Future<void> markIntentDialed(String intentId) async {
    try {
      await _client
          .from('biopay_payment_intents')
          .update(<String, dynamic>{
            'status': 'dialed',
            'dialed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', intentId)
          .eq('status', 'pending');
    } catch (error) {
      await _recordFailure('mark_intent_dialed', error);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────

  Map<String, dynamic> _extractDataEnvelope(
    FunctionResponse response,
    String fn,
  ) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['success'] == true && data['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      if (data['error'] != null) {
        throw StateError('BioPay $fn error: ${data['error']}');
      }
      if (data['message'] != null) {
        throw StateError('BioPay $fn error: ${data['message']}');
      }
    }
    throw StateError('BioPay $fn returned unexpected data type.');
  }

  Future<void> _recordFailure(
    String operation,
    Object error, {
    String? userId,
  }) async {
    try {
      await _healthService.recordEvent(
        service: 'biopay',
        component: operation,
        message: error.toString(),
        status: OperationalHealthStatus.error,
        userId: userId,
        metadata: <String, dynamic>{
          'operation': operation,
          'error_type': error.runtimeType.toString(),
        },
      );
    } catch (_) {
      debugPrint('[BiopayRepository] Failed to record health event.');
    }
  }
}
