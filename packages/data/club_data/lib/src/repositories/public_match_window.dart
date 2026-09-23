import 'package:supabase_flutter/supabase_flutter.dart';

/// Independently bounded live, upcoming and recent results. Historical seasons
/// cannot consume the upcoming quota. All instants are compared in UTC.
class PublicMatchWindow {
  PublicMatchWindow(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> load({
    required int clubId,
    int limitPerSection = 40,
    DateTime? now,
  }) async {
    final instant = (now ?? DateTime.now()).toUtc();
    final timestamp = instant.toIso8601String();
    final day = timestamp.substring(0, 10);
    final time = timestamp.substring(11, 19);
    const live = [
      'live',
      'in_progress',
      'halftime',
      '1h',
      'ht',
      '2h',
      'et',
      'p',
    ];
    const finished = [
      'completed',
      'finished',
      'fulltime',
      'full_time',
      'ft',
      'aet',
      'pen',
    ];
    final limit = limitPerSection.clamp(1, 80);
    final batches = await Future.wait([
      client
          .from('unified_matches')
          .select()
          .eq('club_id', clubId)
          .inFilter('match_status', live)
          .order('match_date', ascending: true)
          .limit(limit),
      client
          .from('unified_matches')
          .select()
          .eq('club_id', clubId)
          .not(
            'match_status',
            'in',
            '(completed,finished,fulltime,full_time,ft,aet,pen,cancelled,postponed,live,in_progress,halftime,1h,ht,2h,et,p)',
          )
          .or(
            'kickoff_at.gte.$timestamp,and(kickoff_at.is.null,or(match_date.gt.$day,and(match_date.eq.$day,kickoff_time.gte.$time)))',
          )
          .order('match_date', ascending: true)
          .order('kickoff_time', ascending: true)
          .limit(limit),
      client
          .from('unified_matches')
          .select()
          .eq('club_id', clubId)
          .inFilter('match_status', finished)
          .order('match_date', ascending: false)
          .order('kickoff_time', ascending: false)
          .limit(limit),
    ]);
    final seen = <String>{};
    return batches
        .expand((rows) => rows)
        .where((row) => seen.add(row['id'].toString()))
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
