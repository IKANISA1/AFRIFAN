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
  Future<Map<String, dynamic>> activateFreeMembership();

  Future<Map<String, dynamic>> submitPhysicalApplication({
    required String tier,
    required String paymentReference,
    String? chapter,
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
  Future<Map<String, dynamic>> activateFreeMembership() async {
    final response = await _invoke('activate_free_fan_membership');
    return _requireRow(response, operation: 'activate free membership');
  }

  @override
  Future<Map<String, dynamic>> submitPhysicalApplication({
    required String tier,
    required String paymentReference,
    String? chapter,
  }) async {
    final normalizedTier = tier.trim().toLowerCase();
    final normalizedReference = paymentReference.trim();
    final normalizedChapter = chapter?.trim();
    if (normalizedTier.isEmpty || normalizedReference.isEmpty) {
      throw ArgumentError(
        'Membership tier and payment reference must not be empty.',
      );
    }

    final response = await _invoke(
      'submit_membership_application',
      params: <String, dynamic>{
        'p_tier': normalizedTier,
        'p_payment_reference': normalizedReference,
        'p_chapter': normalizedChapter == null || normalizedChapter.isEmpty
            ? null
            : normalizedChapter,
      },
    );
    return _requireRow(response, operation: 'submit membership application');
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
