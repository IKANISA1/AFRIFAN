import 'package:supabase_flutter/supabase_flutter.dart';

/// Reuses club-published CMS media for the matching project. This is a read-only
/// publication reference, not a claim about independent media-rights approval.
Future<Map<String, String>> loadPublishedProjectImages(
  SupabaseClient client, {
  required int clubId,
  required Iterable<String> groupIds,
}) async {
  final routes = <String, String>{
    for (final id in groupIds)
      '/contribute/group/${Uri.encodeComponent(id)}': id,
    for (final id in groupIds) '/club/projects/${Uri.encodeComponent(id)}': id,
  };
  if (routes.isEmpty) return const {};
  try {
    final rows = await client
        .from('home_banners')
        .select('route,image_url')
        .eq('club_id', clubId)
        .eq('is_active', true)
        .inFilter('distribution', ['app', 'both'])
        .inFilter('route', routes.keys.toList())
        .order('sort_order').timeout(const Duration(seconds: 3));
    final images = <String, String>{};
    for (final row in rows) {
      final id = routes[row['route']];
      final uri = Uri.tryParse(row['image_url']?.toString() ?? '');
      if (id != null &&
          uri?.scheme == 'https' &&
          uri!.host.isNotEmpty &&
          uri.userInfo.isEmpty) {
        images.putIfAbsent(id, uri.toString);
      }
    }
    return images;
  } on Object {
    // Optional artwork must never hide financial totals or block a journey.
    return const {};
  }
}
