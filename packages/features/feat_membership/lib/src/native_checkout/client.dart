import 'dart:convert';
import 'history.dart';
import 'models.dart';
import 'ports.dart';

/// Opt-in adapter for the current native-bearer gateway. Not Supabase credentials.
final class NativeMembershipClient
    implements NativeMembershipApi, NativeMembershipHistoryApi {
  NativeMembershipClient({
    required this.origin,
    required this.clubId,
    required this.credentials,
    required this.transport,
    this.enabled = false,
    this.timeout = const Duration(seconds: 15),
  }) {
    final uri = Uri.parse(origin);
    requireContract(
      uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          !uri.hasQuery &&
          !uri.hasFragment &&
          uri.path.isEmpty &&
          uri.origin == origin,
      'invalid_origin',
    );
    requireContract(
      clubId > 0 &&
          clubId <= 9007199254740991 &&
          timeout.inMilliseconds > 0 &&
          timeout.inMilliseconds <= 30000,
      'invalid_configuration',
    );
  }
  final String origin;
  final int clubId;
  final Future<String> Function() credentials;
  final NativeMembershipTransport transport;
  final bool enabled;
  final Duration timeout;
  void _actor(MembershipSession a) => requireContract(
    isUuid(a.userId) && isUuid(a.sessionId) && a.clubId == clubId,
    'session_changed',
  );
  Future<Object?> _call(
    String method,
    String suffix, {
    MembershipSession? actor,
    String? tier,
    String? key,
    Map<String, String>? payload,
    String? historyCursor,
  }) async {
    requireContract(enabled, 'membership_client_disabled');
    String token;
    try {
      token = await credentials().timeout(timeout);
    } catch (_) {
      throw const NativeMembershipException('credentials_unavailable');
    }
    final parts = token.split('.');
    requireContract(
      parts.length == 2 &&
          isUuid(parts[0]) &&
          matchesWire(r'^[A-Za-z0-9_-]{43}$', parts[1]),
      'credentials_unavailable',
    );
    if (actor != null) {
      _actor(actor);
      requireContract(parts[0] == actor.sessionId, 'session_changed');
    }
    final request = NativeWireRequest(
      Uri.parse('$origin/v1/supporter/clubs/$clubId/$suffix'),
      method,
      {
        if (historyCursor != null) 'x-africlub-history-cursor': historyCursor,
        'authorization': 'Bearer $token',
        'x-africlub-client': 'native-v1',
        if (actor != null) 'x-africlub-session': actor.sessionId,
        if (tier != null || payload != null) 'content-type': 'application/json',
        if (key != null) 'idempotency-key': key,
      },
      payload != null
          ? jsonEncode(payload)
          : tier == null
          ? null
          : jsonEncode({'tier': tier}),
    );
    final unknown = suffix.contains('/handoffs/')
        ? 'handoff_outcome_unknown'
        : 'checkout_outcome_unknown';
    try {
      final response = await transport.send(request, timeout).timeout(timeout);
      requireContract(
        response.body.length <= 16384 &&
            utf8.encode(response.body).length <= 16384,
      );
      requireContract(
        (response.headers['content-type'] ?? '')
                .split(';')
                .first
                .trim()
                .toLowerCase() ==
            'application/json',
      );
      final value = decodeWire(response.body);
      if (response.status != 200) {
        if (method == 'POST' &&
            response.status == 503 &&
            value is Map &&
            value['error'] == unknown) {
          final e = exactObject(value, [
            'schemaVersion',
            'error',
            'outcome',
            'requestId',
          ]);
          requireContract(
            e['schemaVersion'] == 1 &&
                e['outcome'] == 'unknown' &&
                e['requestId'] == key,
          );
          throw NativeMembershipException(unknown, RequestOutcome.unknown);
        }
        final e = exactObject(value, ['schemaVersion', 'error']);
        const errors = {
          'unauthenticated',
          'permission_denied',
          'rate_limited',
          'service_disabled',
          'service_unavailable',
          'identity_unavailable',
          'handoff_disabled',
          'handoff_unavailable',
          'not_found',
          'receipt_not_available',
          'session_changed',
          'invalid_request',
          'staging_only',
          'invalid_configuration',
          'invalid_origin',
          'native_transport_required',
          'ingress_unverified',
          'unsupported_media_type',
          'payload_too_large',
          'upstream_timeout',
          'upstream_contract_invalid',
          'method_not_allowed',
        };
        requireContract(
          e['schemaVersion'] == 1 &&
              errors.contains(e['error']) &&
              [
                400,
                401,
                403,
                404,
                405,
                409,
                413,
                415,
                429,
                503,
              ].contains(response.status),
        );
        throw NativeMembershipException(
          e['error']! as String,
          RequestOutcome.rejected,
        );
      }
      return value;
    } catch (error) {
      if (error is NativeMembershipException &&
          error.outcome != RequestOutcome.notSent) {
        rethrow;
      }
      throw NativeMembershipException(
        method == 'POST' ? unknown : 'read_unavailable',
        method == 'POST' ? RequestOutcome.unknown : RequestOutcome.notSent,
      );
    }
  }

  @override
  Future<MembershipHistoryPage> history(
    MembershipSession actor, {
    String? cursor,
  }) async {
    _actor(actor);
    MembershipHistoryCursor.parse(cursor, actor);
    return MembershipHistoryPage.parse(
      await _call(
        'GET',
        'membership/history',
        actor: actor,
        historyCursor: cursor,
      ),
      actor,
      cursor: cursor,
    );
  }

  @override
  Future<HistoricalMembershipReceipt> historicalReceipt(
    MembershipSession actor,
    String orderId,
  ) async {
    _actor(actor);
    requireContract(isUuid(orderId), 'invalid_request');
    final v = exactObject(
      await _call('GET', 'membership/history/$orderId', actor: actor),
      ['schemaVersion', 'clubId', 'userId', 'observedAt', 'receipt'],
    );
    requireContract(
      v['schemaVersion'] == 1 &&
          v['clubId'] == clubId &&
          v['userId'] == actor.userId &&
          isTimestamp(v['observedAt']),
    );
    final receipt = HistoricalMembershipReceipt.parse(
      v['receipt'],
      clubId,
      orderId,
    );
    requireContract(receipt.recordedAt <= (v['observedAt']! as int));
    return receipt;
  }

  @override
  Future<MembershipSession> session() async =>
      MembershipSession.parse(await _call('GET', 'session'), clubId);
  @override
  Future<PreparedCheckout> prepare(
    MembershipSession actor,
    String requestId,
    String tier,
  ) async {
    _actor(actor);
    requireContract(isUuid(requestId) && isTier(tier), 'invalid_request');
    final value = await _call(
      'POST',
      'membership/checkouts',
      actor: actor,
      tier: tier,
      key: requestId,
    );
    try {
      return PreparedCheckout.parse(value, clubId, requestId, tier);
    } catch (_) {
      throw const NativeMembershipException(
        'checkout_outcome_unknown',
        RequestOutcome.unknown,
      );
    }
  }

  @override
  Future<CurrentCheckout> read(MembershipSession actor, String orderId) async {
    _actor(actor);
    requireContract(isUuid(orderId), 'invalid_request');
    return CurrentCheckout.parse(
      await _call('GET', 'membership/checkouts/$orderId', actor: actor),
      clubId,
      orderId,
    );
  }

  @override
  Future<ServerHandoffStatus> handoffCurrent(MembershipSession actor) async {
    _actor(actor);
    return ServerHandoffStatus.parse(
      await _call('GET', 'membership/handoffs/current', actor: actor),
      clubId,
    );
  }

  @override
  Future<ServerHandoffStatus> reserveHandoff(
    MembershipSession actor,
    String orderId,
    String requestId,
  ) async {
    _actor(actor);
    requireContract(isUuid(orderId) && isUuid(requestId), 'invalid_request');
    final value = await _call(
      'POST',
      'membership/handoffs/reservations',
      actor: actor,
      key: requestId,
      payload: {'orderId': orderId},
    );
    try {
      final result = ServerHandoffStatus.parse(value, clubId);
      requireContract(result.handoff?.orderId == orderId);
      return result;
    } catch (_) {
      throw const NativeMembershipException(
        'handoff_outcome_unknown',
        RequestOutcome.unknown,
      );
    }
  }

  @override
  Future<ServerHandoffStatus> releaseHandoff(
    MembershipSession actor,
    String handoffId,
    String requestId,
  ) async {
    _actor(actor);
    requireContract(isUuid(handoffId) && isUuid(requestId), 'invalid_request');
    final value = await _call(
      'POST',
      'membership/handoffs/releases',
      actor: actor,
      key: requestId,
      payload: {'handoffId': handoffId},
    );
    try {
      final result = ServerHandoffStatus.parse(value, clubId);
      requireContract(
        result.handoff?.handoffId == handoffId &&
            ['released', 'allocated'].contains(result.handoff?.phase) &&
            !result.mayOpenDialer,
      );
      return result;
    } catch (_) {
      throw const NativeMembershipException(
        'handoff_outcome_unknown',
        RequestOutcome.unknown,
      );
    }
  }

  @override
  Future<ServerHandoffStatus> claimHandoff(
    MembershipSession actor,
    String handoffId,
    String requestId,
  ) async {
    _actor(actor);
    requireContract(isUuid(handoffId) && isUuid(requestId), 'invalid_request');
    final value = await _call(
      'POST',
      'membership/handoffs/claims',
      actor: actor,
      key: requestId,
      payload: {'handoffId': handoffId},
    );
    try {
      final result = ServerHandoffStatus.parse(value, clubId, claim: true);
      requireContract(result.handoff?.handoffId == handoffId);
      return result;
    } catch (_) {
      throw const NativeMembershipException(
        'handoff_outcome_unknown',
        RequestOutcome.unknown,
      );
    }
  }

  @override
  Future<HistoricalMembershipReceipt> receipt(
    MembershipSession actor,
    String orderId,
  ) async {
    _actor(actor);
    requireContract(isUuid(orderId), 'invalid_request');
    return HistoricalMembershipReceipt.parse(
      await _call('GET', 'membership/checkouts/$orderId/receipt', actor: actor),
      clubId,
      orderId,
    );
  }
}
