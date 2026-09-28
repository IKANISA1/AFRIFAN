import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clubPublicLinkProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, path) async {
      if (!validPublicEntityPath(path)) return null;
      final client = ref.watch(supabaseClientProvider);
      final scope = await ClubScopeResolver(client: client).requireResolved();
      final result = await client
          .rpc(
            'resolve_club_public_link_v1',
            params: {'p_club_id': scope.requiredClubId, 'p_source_path': path},
          )
          .timeout(const Duration(seconds: 12));
      final target = result is String ? result : null;
      return target != null && validNativeEntityPath(target) ? target : null;
    });

bool validPublicEntityPath(String path) =>
    !path.contains('%') &&
    !path.contains('..') &&
    RegExp(
      r'^/(squad/(player|staff)|news|shop/product|fanclubs|tickets/match|partners)/[a-zA-Z0-9_-]+$',
    ).hasMatch(path);

bool validNativeEntityPath(String path) => RegExp(
  r'^/(club/(team|news|fixtures|partners)|shop/product|fan-clubs|tickets/detail)/[a-zA-Z0-9_-]+$',
).hasMatch(path);

/// Unresolved website records stay in the corresponding native collection.
String nativeCollectionForPublicPath(String path) {
  if (path.startsWith('/squad/')) return '/club/team';
  if (path.startsWith('/news/')) return '/club/news';
  if (path.startsWith('/tickets/')) return '/club/fixtures';
  if (path.startsWith('/shop/')) return '/shop';
  if (path.startsWith('/fanclubs/')) return '/fan-clubs';
  if (path.startsWith('/partners/')) return '/club/partners';
  return '/club';
}
