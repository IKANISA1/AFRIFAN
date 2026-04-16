import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/biopay_enrollment_draft.dart';
import '../models/biopay_handoff_resolution.dart';
import '../models/biopay_handoff_token.dart';
import '../models/biopay_liveness_challenge.dart';
import '../models/biopay_match_result.dart';
import '../models/biopay_payment_intent.dart';
import '../models/biopay_profile.dart';
import '../services/biopay_rate_limiter.dart';

typedef BioPayAppCheckTokenProvider = Future<String> Function();

/// Central repository for BioPay backend operations.
///
/// Interacts with Supabase edge functions:
/// - `BioPay-enroll` — register a new face
/// - `BioPay-match` — search for a matching face
/// - `BioPay-revoke` — deactivate an enrollment
/// - `BioPay-create-payment-intent` — generate a server-issued payment intent
class BioPayRepository {
  BioPayRepository({
    required SupabaseClient client,
    OperationalHealthService? healthService,
    BioPayRateLimiter? rateLimiter,
    BioPayAppCheckTokenProvider? appCheckTokenProvider,
  }) : _client = client,
       _healthService =
           healthService ?? OperationalHealthService(client: client),
       _rateLimiter = rateLimiter ?? BioPayRateLimiter(),
       _appCheckTokenProvider =
           appCheckTokenProvider ??
           (() =>
               AppCheckService.requireLimitedUseToken(featureName: 'BioPay'));

  static const _tag = 'BioPayRepository';

  final SupabaseClient _client;
  final OperationalHealthService _healthService;
  final BioPayRateLimiter _rateLimiter;
  final BioPayAppCheckTokenProvider _appCheckTokenProvider;

  Future<Map<String, String>> _buildAttestedHeaders() async {
    final token = await _appCheckTokenProvider();
    return <String, String>{'X-Firebase-AppCheck': token};
  }

  // ─── Enrollment ─────────────────────────────────────────────

  Future<BioPayLivenessChallenge> createLivenessChallenge({
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
      final response = await _invokeFunction(
        'BioPay-create-liveness-challenge',
        body: <String, dynamic>{'mode': mode},
        headers: headers,
      );
      final data = _extractDataEnvelope(
        response,
        'BioPay-create-liveness-challenge',
      );
      return BioPayLivenessChallenge.fromApiResponse(data);
    } catch (error) {
      await _recordFailure('create_liveness_challenge', error, userId: userId);
      rethrow;
    }
  }

  // ─── Enrollment ─────────────────────────────────────────────

  /// Enroll a new face with the given embedding and draft data.
  Future<BioPayProfile> enroll({
    required List<double> embedding,
    required BioPayEnrollmentDraft draft,
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
      final response = await _invokeFunction(
        'BioPay-enroll',
        body: <String, dynamic>{
          ...draft.toPayload(embedding, liveness: livenessMetadata),
        },
        headers: headers,
      );

      final data = _extractDataEnvelope(response, 'BioPay-enroll');
      return BioPayProfile.fromJson(data);
    } catch (error) {
      await _recordFailure('enroll', error, userId: userId);
      rethrow;
    }
  }

  // ─── Matching ───────────────────────────────────────────────

  /// Match a face embedding against enrolled profiles.
  Future<BioPayMatchResult> match({
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
      final response = await _invokeFunction(
        'BioPay-match',
        body: <String, dynamic>{
          'embedding': embedding,
          if (threshold != null) 'threshold': threshold,
          ...?(livenessMetadata == null
              ? null
              : <String, dynamic>{'liveness': livenessMetadata}),
        },
        headers: headers,
      );

      final data = _extractDataEnvelope(response, 'BioPay-match');
      return BioPayMatchResult.fromApiResponse(data);
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
      final response = await _invokeFunction(
        'BioPay-revoke',
        body: <String, dynamic>{if (reason != null) 'reason': reason},
        headers: headers,
      );
      _extractDataEnvelope(response, 'BioPay-revoke');
    } catch (error) {
      await _recordFailure('revoke', error, userId: userId);
      rethrow;
    }
  }

  // ─── Payment Intent ─────────────────────────────────────────

  /// Create a server-issued payment intent bound to a biometric match.
  Future<BioPayPaymentIntent> createPaymentIntent({
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
      final response = await _invokeFunction(
        'BioPay-create-payment-intent',
        body: <String, dynamic>{
          'match_receipt': matchReceipt,
          if (amount != null) 'amount': amount,
        },
        headers: headers,
      );

      final data = _extractDataEnvelope(
        response,
        'BioPay-create-payment-intent',
      );
      return BioPayPaymentIntent.fromApiResponse(data);
    } catch (error) {
      await _recordFailure('create_payment_intent', error, userId: userId);
      rethrow;
    }
  }

  // ─── QR / NFC Handoff ──────────────────────────────────────

  Future<BioPayHandoffToken> createHandoffToken({
    required String channel,
    int? amount,
    String? reference,
    PaymentRecipientType? routeType,
    String? recipientValue,
    String? countryCode,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError(
        'BioPay handoff generation requires an authenticated user.',
      );
    }

    try {
      final headers = await _buildAttestedHeaders();
      final response = await _invokeFunction(
        'BioPay-create-handoff-token',
        body: <String, dynamic>{
          'channel': channel,
          if (amount != null) 'amount': amount,
          if (reference != null && reference.trim().isNotEmpty)
            'reference': reference.trim(),
          if (routeType != null) 'route_type': _serializeRouteType(routeType),
          if (recipientValue != null && recipientValue.trim().isNotEmpty)
            'recipient_value': recipientValue.trim(),
          if (countryCode != null && countryCode.trim().isNotEmpty)
            'country_code': countryCode.trim().toUpperCase(),
        },
        headers: headers,
      );

      final data = _extractDataEnvelope(
        response,
        'BioPay-create-handoff-token',
      );
      return BioPayHandoffToken.fromApiResponse(data);
    } catch (error) {
      await _recordFailure('create_handoff_token', error, userId: userId);
      rethrow;
    }
  }

  Future<BioPayHandoffResolution> resolveHandoffToken({
    required String token,
  }) async {
    try {
      final response = await _invokeFunction(
        'BioPay-resolve-handoff',
        body: <String, dynamic>{'token': token},
        maxAttempts: 3,
      );
      final data = _extractDataEnvelope(response, 'BioPay-resolve-handoff');
      return BioPayHandoffResolution.fromApiResponse(data);
    } catch (error) {
      await _recordFailure('resolve_handoff_token', error);
      rethrow;
    }
  }

  // ─── Profile Query ──────────────────────────────────────────

  /// Fetch the current user's BioPay profile (if enrolled).
  Future<BioPayProfile?> fetchCurrentUserProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return null;

    try {
      final result = await SafeRpc.query<dynamic>(
        () => _client
            .from('biopay_profiles')
            .select()
            .eq('user_id', userId)
            .eq('active', true)
            .order('created_at', ascending: false)
            .maybeSingle(),
        tag: _tag,
        description: 'fetchCurrentUserProfile',
        maxAttempts: 3,
      );
      if (!result.isSuccess) {
        return null;
      }
      final row = result.data;

      if (row != null) {
        return BioPayProfile.fromJson(Map<String, dynamic>.from(row));
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
      final result = await SafeRpc.query<bool>(
        () async {
          await _client
              .from('biopay_payment_intents')
              .update(<String, dynamic>{
                'status': 'dialed',
                'dialed_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', intentId)
              .eq('status', 'pending');
          return true;
        },
        tag: _tag,
        description: 'markIntentDialed',
      );
      if (!result.isSuccess) {
        throw StateError(
          result.error ?? 'Could not mark the intent as dialed.',
        );
      }
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

  String _serializeRouteType(PaymentRecipientType value) {
    return switch (value) {
      PaymentRecipientType.phoneNumber => 'phone_number',
      PaymentRecipientType.code => 'code',
    };
  }

  Future<FunctionResponse> _invokeFunction(
    String functionName, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    int maxAttempts = 1,
  }) async {
    final result = await SafeRpc.query<FunctionResponse>(
      () =>
          _client.functions.invoke(functionName, body: body, headers: headers),
      tag: _tag,
      description: functionName,
      maxAttempts: maxAttempts,
    );
    if (result.isSuccess) {
      return result.requireData;
    }
    throw StateError(result.error ?? '$functionName failed.');
  }

  Future<void> _recordFailure(
    String operation,
    Object error, {
    String? userId,
  }) async {
    try {
      await _healthService.recordEvent(
        service: 'BioPay',
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
      AfriLogger.warn('BioPayRepository', 'Failed to record health event.');
    }
  }
}
