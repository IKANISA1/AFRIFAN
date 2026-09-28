import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<List<Map<String, dynamic>>> loadGikundiroPublicShop(
  SupabaseClient source,
) async {
  final clubId = await gikundiroPublicClubId(source);
  final results = await Future.wait([
    source
        .from('marketplace_products')
        .select(
          'id,name,description,price_rwf,category_id,image_asset_id,'
          'verification_status,variant_options,sort_order',
        )
        .eq('club_id', clubId)
        .eq('approval_status', 'approved')
        .eq('active', true)
        .eq('visibility', 'public')
        .order('sort_order')
        .limit(100),
    source
        .from('marketplace_categories')
        .select('id,name,label')
        .eq('club_id', clubId)
        .eq('active', true)
        .limit(100),
  ]);
  final products = results[0];
  final categories = {for (final row in results[1]) row['id']?.toString(): row};
  final assetIds = products
      .map((row) => row['image_asset_id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
  final assets = assetIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await source
            .from('media_assets')
            .select(
              'id,asset_url,storage_bucket,storage_path,usage_rights,'
              'usage_scopes',
            )
            .eq('club_id', clubId)
            .eq('approval_status', 'approved')
            .eq('active', true)
            .eq('visibility', 'public')
            .inFilter('id', assetIds);
  final assetById = {
    for (final asset in assets) asset['id']?.toString(): asset,
  };
  return products
      .map(
        (row) => mapGikundiroPublicProduct(
          row,
          assetById[row['image_asset_id']?.toString()],
          categories[row['category_id']?.toString()],
        ),
      )
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

Map<String, dynamic>? mapGikundiroPublicProduct(
  Map<String, dynamic> row,
  Map<String, dynamic>? asset,
  Map<String, dynamic>? category, {
  DateTime? now,
}) {
  final current = (now ?? DateTime.now()).toUtc();
  final startYear = current.month >= 7 ? current.year : current.year - 1;
  final seasonStatus =
      'current_media_verified_${startYear}_'
      '${((startYear + 1) % 100).toString().padLeft(2, '0')}';
  final rights = (asset?['usage_rights'] ?? '').toString().toLowerCase();
  final mediaUrl = Uri.tryParse((asset?['asset_url'] ?? '').toString());
  final scopes = asset?['usage_scopes'];
  if (row['verification_status'] != seasonStatus ||
      asset?['storage_bucket'] != 'gikundiro-media' ||
      (asset?['storage_path'] ?? '').toString().trim().isEmpty ||
      mediaUrl?.scheme != 'https' ||
      mediaUrl?.host.isNotEmpty != true ||
      rights.isEmpty ||
      RegExp(
        r'generated|pending|review-before-commercial-reuse|unverified',
      ).hasMatch(rights) ||
      scopes is! List ||
      !scopes.contains('shop')) {
    return null;
  }
  final id = (row['id'] ?? '').toString().trim();
  final name = (row['name'] ?? '').toString().trim();
  final price = row['price_rwf'];
  if (id.isEmpty || name.isEmpty || price is! num || price <= 0) return null;
  final variants = row['variant_options'];
  final sizes = variants is Map && variants['sizes'] is List
      ? List<String>.from(variants['sizes'] as List)
      : <String>[];
  return <String, dynamic>{
    'id': 'gikundiro-$id',
    'name': name,
    'subtitle': (row['description'] ?? '').toString(),
    'description': (row['description'] ?? '').toString(),
    'category': (category?['label'] ?? category?['name'] ?? 'Merchandise')
        .toString(),
    'price': price,
    'currency': 'RWF',
    'available_sizes': sizes,
    'is_active': true,
    'image_url': mediaUrl.toString(),
    'image_provenance_id': asset!['id'].toString(),
    'image_rights_approved': true,
    'commerce_mode': 'enquiry',
    'enquiry_phone': '250795588248',
  };
}
