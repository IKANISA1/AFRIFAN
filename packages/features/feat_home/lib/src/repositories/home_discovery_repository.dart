import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum HomeDiscoveryKind { predictions, partners, fanClubs }

abstract interface class HomeDiscoveryRepository {
  Future<List<Map<String, dynamic>>> load(HomeDiscoveryKind kind);
}

final homeDiscoveryRepositoryProvider = Provider<HomeDiscoveryRepository>(
  (ref) => SupabaseHomeDiscoveryRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storeReleasePolicyProvider),
    publicSource: ref.watch(gikundiroPublicClientProvider),
  ),
);

final homeDiscoveryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, HomeDiscoveryKind>((ref, kind) async {
      Timer? expiry;
      var disposed = false;
      ref.onDispose(() {
        disposed = true;
        expiry?.cancel();
      });
      final rows = await ref
          .watch(homeDiscoveryRepositoryProvider)
          .load(kind)
          .timeout(const Duration(seconds: 12));
      if (kind == HomeDiscoveryKind.predictions && !disposed) {
        final deadlines =
            rows
                .map((row) => DateTime.tryParse('${row['locks_at']}'))
                .whereType<DateTime>()
                .where((time) => time.isAfter(DateTime.now()))
                .toList()
              ..sort();
        if (deadlines.isNotEmpty) {
          expiry = Timer(
            deadlines.first.difference(DateTime.now()),
            ref.invalidateSelf,
          );
        }
      }
      return rows;
    });

/// Public discovery never reads a wallet or awards an engagement entry.
class SupabaseHomeDiscoveryRepository implements HomeDiscoveryRepository {
  SupabaseHomeDiscoveryRepository(
    this.client,
    this.releasePolicy, {
    ClubScopeResolver? scopeResolver,
    this.publicSource,
  }) : scopeResolver = scopeResolver ?? ClubScopeResolver(client: client);
  final ClubScopeResolver scopeResolver;
  final SupabaseClient client;
  final StoreReleasePolicy releasePolicy;
  final SupabaseClient? publicSource;

  @override
  Future<List<Map<String, dynamic>>> load(HomeDiscoveryKind kind) async {
    if (publicSource case final SupabaseClient source) {
      if (kind == HomeDiscoveryKind.partners) {
        return (await loadGikundiroPublicPartners(source)).take(3).toList();
      }
      if (kind == HomeDiscoveryKind.fanClubs) {
        return (await loadGikundiroPublicFanclubs(source)).take(3).toList();
      }
    }
    if (kind == HomeDiscoveryKind.predictions &&
        !releasePolicy.allowsStakedCompetitions) {
      return const [];
    }
    final scope = await scopeResolver.requireResolved();
    final List<dynamic> rows = switch (kind) {
      HomeDiscoveryKind.predictions => await client.rpc(
        'predict_public_preview',
        params: {'p_club_id': scope.requiredClubId},
      ),
      HomeDiscoveryKind.partners =>
        await client
            .from('club_partner_publications')
            .select(
              'id,name,category,description,logo_url,image_url,image_rights_approved,image_provenance_id',
            )
            .eq('club_id', scope.requiredClubId)
            .order('sort_order')
            .limit(3),
      HomeDiscoveryKind.fanClubs =>
        await client
            .from('fan_clubs')
            .select(
              'id,name,region,description,member_count,banner_image_url:published_image_url',
            )
            .eq('club_id', scope.requiredClubId)
            .eq('is_active', true)
            .order('member_count', ascending: false)
            .limit(3),
    };
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }
}
