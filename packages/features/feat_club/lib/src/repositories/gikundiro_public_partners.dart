import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<List<Map<String, dynamic>>> loadGikundiroPublicPartners(
  SupabaseClient source,
) async {
  final clubId = await gikundiroPublicClubId(source);
  final rows = await source
      .from('partners')
      .select(
        'id,name,category,tier,relationship_summary,logo_asset_id,'
        'website_url,sort_order',
      )
      .eq('club_id', clubId)
      .eq('approval_status', 'approved')
      .eq('active', true)
      .eq('visibility', 'public')
      .order('sort_order')
      .limit(100);
  final ids = rows
      .map((row) => row['logo_asset_id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
  if (ids.isEmpty) return [];
  final assets = await source
      .from('media_assets')
      .select('id,asset_url,usage_rights,usage_scopes')
      .eq('club_id', clubId)
      .eq('approval_status', 'approved')
      .eq('active', true)
      .eq('visibility', 'public')
      .inFilter('id', ids);
  final assetById = {
    for (final asset in assets) asset['id']?.toString(): asset,
  };
  return rows
      .map(
        (row) => mapGikundiroPublicPartner(
          row,
          assetById[row['logo_asset_id']?.toString()],
        ),
      )
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

Map<String, dynamic>? mapGikundiroPublicPartner(
  Map<String, dynamic> row,
  Map<String, dynamic>? asset,
) {
  final name = (row['name'] ?? '').toString().trim();
  final logo = Uri.tryParse((asset?['asset_url'] ?? '').toString());
  final scopes = asset?['usage_scopes'];
  if (name.isEmpty ||
      logo?.scheme != 'https' ||
      logo?.host.isNotEmpty != true ||
      scopes is! List ||
      !scopes.contains('partners') ||
      (asset?['usage_rights'] ?? '').toString().trim().isEmpty) {
    return null;
  }
  final website = Uri.tryParse((row['website_url'] ?? '').toString());
  return <String, dynamic>{
    'id': 'gikundiro-${row['id']}',
    'name': name,
    'category': (row['category'] ?? row['tier'] ?? '').toString(),
    'description': (row['relationship_summary'] ?? '').toString(),
    'logo_url': logo.toString(),
    'image_url': null,
    'image_provenance_id': asset!['id'].toString(),
    'image_rights_approved': true,
    'website_url':
        website?.scheme == 'https' && website?.host.isNotEmpty == true
        ? website.toString()
        : null,
  };
}
