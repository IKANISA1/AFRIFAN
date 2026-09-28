import 'package:core_network/core_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'official_fanclub_register.dart';

Future<List<Map<String, dynamic>>> loadGikundiroPublicFanclubs(
  SupabaseClient source,
) async {
  final rows = await source
      .from('fanclubs')
      .select(
        'id,slug,name,official_name,chapter_type,status,country,'
        'province,district,city,accepting_members,member_count_public,'
        'show_member_count,activities,impact_summary,community_activity,'
        'source_label,verification_status,sort_order',
      )
      .eq('club_id', await gikundiroPublicClubId(source))
      .eq('approval_status', 'approved')
      .eq('active', true)
      .eq('visibility', 'public')
      .order('sort_order')
      .limit(100);
  return rows.map(mapGikundiroPublicFanclub).toList(growable: false);
}

Map<String, dynamic> mapGikundiroPublicFanclub(Map<String, dynamic> row) {
  final publicRow = <String, dynamic>{
    ...row,
    'id': 'gikundiro-${row['id']}',
    'approval_status': 'approved',
    'active': true,
    'visibility': 'public',
    'member_count_public': row['show_member_count'] == true
        ? row['member_count_public']
        : 'Pending confirmation',
    'banner_image_url': null,
  };
  return normalizeFanclubRow(publicRow);
}
