import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef MembershipRpcInvoker =
    Future<dynamic> Function(
      String functionName, {
      Map<String, dynamic>? params,
    });

/// The only supporter-authorized membership mutation surface.
abstract interface class MembershipMutationGateway {
  Future<Map<String, dynamic>> preparePayment({
    required String tier,
    required int clubId,
  });
}

class SupabaseMembershipMutationGateway implements MembershipMutationGateway {
  SupabaseMembershipMutationGateway(SupabaseClient client)
    : this.withInvoker((functionName, {params}) {
        if (params == null) {
          return client.rpc(functionName);
        }
        return client.rpc(functionName, params: params);
      });

  SupabaseMembershipMutationGateway.withInvoker(this._invoke);

  final MembershipRpcInvoker _invoke;

  @override
  Future<Map<String, dynamic>> preparePayment({
    required String tier,
    required int clubId,
  }) async {
    final normalizedTier = tier.trim().toLowerCase();
    if (normalizedTier.isEmpty) {
      throw ArgumentError('Membership tier must not be empty.');
    }
    final response = await _invoke(
      'prepare_membership_payment_for_club',
      params: <String, dynamic>{
        'p_tier': normalizedTier,
        'p_expected_club_id': clubId,
      },
    );
    final row = _requireRow(response, operation: 'prepare membership payment');
    if (row['club_id'] != clubId ||
        row['tier'] != normalizedTier ||
        row['ussd_code'] is! String ||
        !RegExp(r'^\*[0-9*]+#$').hasMatch(row['ussd_code'] as String) ||
        row['amount'] is! int ||
        (row['amount'] as num) <= 0 ||
        row['recipient_code'] is! String ||
        (row['recipient_code'] as String).trim().isEmpty ||
        row['country'] is! String ||
        (row['country'] as String).trim().isEmpty) {
      throw StateError(
        'The server did not return a configured paid membership.',
      );
    }
    return row;
  }

  static Map<String, dynamic> _requireRow(
    dynamic response, {
    required String operation,
  }) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    throw StateError('The server did not return a row for $operation.');
  }
}

final membershipMutationGatewayProvider = Provider<MembershipMutationGateway>(
  (ref) => SupabaseMembershipMutationGateway(ref.watch(supabaseClientProvider)),
);
