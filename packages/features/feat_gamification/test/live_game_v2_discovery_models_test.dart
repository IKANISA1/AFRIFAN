import 'package:feat_gamification/src/models/live_game_v2_discovery_models.dart';
import 'package:feat_gamification/src/models/live_game_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParticipantGameDiscoveryFeed', () {
    test('parses eligible live and scheduled sessions without a code', () {
      final feed = ParticipantGameDiscoveryFeed.fromJson(
        _feedJson(),
        expectedClubId: 'club-1',
      );

      expect(feed.publicAlias, '240731');
      expect(feed.sessions, hasLength(2));
      expect(
        feed.sessions.first.availability,
        ParticipantDiscoveryAvailability.liveNow,
      );
      expect(
        feed.sessions.last.availability,
        ParticipantDiscoveryAvailability.scheduled,
      );
      expect(_allKeys(_feedJson()), isNot(contains('join_code')));
      expect(_allKeys(_feedJson()), isNot(contains('tv_code')));
    });

    test('GAME-MOB-01 preserves governed home and venue discovery sources', () {
      final homeJson = _feedJson();
      final homeSessions = List<Map<String, Object?>>.from(
        homeJson['sessions']! as List,
      )..first['source'] = 'home_owner';
      homeJson['sessions'] = homeSessions;
      final venueJson = _feedJson();
      final venueSessions = List<Map<String, Object?>>.from(
        venueJson['sessions']! as List,
      )..first['source'] = 'venue';
      venueJson['sessions'] = venueSessions;

      expect(
        ParticipantGameDiscoveryFeed.fromJson(
          homeJson,
          expectedClubId: 'club-1',
        ).sessions.first.source,
        ParticipantDiscoverySource.homeOwner,
      );
      expect(
        ParticipantGameDiscoveryFeed.fromJson(
          venueJson,
          expectedClubId: 'club-1',
        ).sessions.first.source,
        ParticipantDiscoverySource.venue,
      );
    });

    test('rejects sessions outside the expected club scope', () {
      final json = _feedJson();
      final sessions = List<Map<String, Object?>>.from(
        json['sessions']! as List,
      );
      sessions.first['club_id'] = 'club-2';
      json['sessions'] = sessions;

      expect(
        () => ParticipantGameDiscoveryFeed.fromJson(
          json,
          expectedClubId: 'club-1',
        ),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('rejects ineligible sessions rather than exposing them', () {
      final json = _feedJson();
      final sessions = List<Map<String, Object?>>.from(
        json['sessions']! as List,
      );
      sessions.first['eligibility'] = false;
      json['sessions'] = sessions;

      expect(
        () => ParticipantGameDiscoveryFeed.fromJson(
          json,
          expectedClubId: 'club-1',
        ),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('rejects a nested TV code', () {
      final json = _feedJson();
      final sessions = List<Map<String, Object?>>.from(
        json['sessions']! as List,
      );
      sessions.first['metadata'] = <String, Object?>{'tv_code': '123456'};
      json['sessions'] = sessions;

      expect(
        () => ParticipantGameDiscoveryFeed.fromJson(
          json,
          expectedClubId: 'club-1',
        ),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('rejects a nested pairing challenge', () {
      final json = _feedJson();
      final sessions = List<Map<String, Object?>>.from(
        json['sessions']! as List,
      );
      sessions.first['metadata'] = <String, Object?>{
        'pairing_challenge': '123456',
      };
      json['sessions'] = sessions;

      expect(
        () => ParticipantGameDiscoveryFeed.fromJson(
          json,
          expectedClubId: 'club-1',
        ),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('rejects arbitrary participant identity fields', () {
      final json = _feedJson()..['display_name'] = 'A real person';

      expect(
        () => ParticipantGameDiscoveryFeed.fromJson(
          json,
          expectedClubId: 'club-1',
        ),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('requires an availability time for scheduled sessions', () {
      final json = _feedJson();
      final sessions = List<Map<String, Object?>>.from(
        json['sessions']! as List,
      );
      sessions.last.remove('available_from');
      json['sessions'] = sessions;

      expect(
        () => ParticipantGameDiscoveryFeed.fromJson(
          json,
          expectedClubId: 'club-1',
        ),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('rejects completed sessions from active discovery', () {
      final json = _feedJson();
      final sessions = List<Map<String, Object?>>.from(
        json['sessions']! as List,
      );
      sessions.first['phase'] = 'completed';
      json['sessions'] = sessions;

      expect(
        () => ParticipantGameDiscoveryFeed.fromJson(
          json,
          expectedClubId: 'club-1',
        ),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('rejects duplicate session identities', () {
      final json = _feedJson();
      final sessions = List<Map<String, Object?>>.from(
        json['sessions']! as List,
      );
      sessions.last['session_id'] = sessions.first['session_id'];
      json['sessions'] = sessions;

      expect(
        () => ParticipantGameDiscoveryFeed.fromJson(
          json,
          expectedClubId: 'club-1',
        ),
        throwsA(isA<LiveGameContractViolation>()),
      );
    });

    test('resolves deep-link recovery by session identity', () {
      final feed = ParticipantGameDiscoveryFeed.fromJson(
        _feedJson(),
        expectedClubId: 'club-1',
      );

      expect(feed.sessionById('session-live')?.title, 'Live trivia');
      expect(feed.sessionById('unknown'), isNull);
      expect(feed.sessionById('  '), isNull);
    });

    test('compares feed versions only within the same club scope', () {
      final current = ParticipantGameDiscoveryFeed.fromJson(
        _feedJson(),
        expectedClubId: 'club-1',
      );
      final newer = ParticipantGameDiscoveryFeed.fromJson(
        _feedJson(feedVersion: 4),
        expectedClubId: 'club-1',
      );
      final otherClub = ParticipantGameDiscoveryFeed(
        clubId: 'club-2',
        feedVersion: 99,
        serverTime: current.serverTime,
        publicAlias: current.publicAlias,
        sessions: const <ParticipantGameDiscoveryItem>[],
      );

      expect(newer.isNewerThan(current), isTrue);
      expect(otherClub.isNewerThan(current), isFalse);
    });
  });
}

Map<String, Object?> _feedJson({int feedVersion = 3}) {
  return <String, Object?>{
    'club_id': 'club-1',
    'feed_version': feedVersion,
    'server_time': '2026-07-30T08:00:00Z',
    'public_alias': '240731',
    'sessions': <Map<String, Object?>>[
      <String, Object?>{
        'club_id': 'club-1',
        'session_id': 'session-live',
        'title': 'Live trivia',
        'phase': 'question_open',
        'source': 'club_membership',
        'session_version': 7,
        'available_from': '2026-07-30T07:55:00Z',
        'eligibility': true,
      },
      <String, Object?>{
        'club_id': 'club-1',
        'session_id': 'session-scheduled',
        'title': 'Saturday quiz',
        'phase': 'scheduled',
        'source': 'invitation',
        'session_version': 2,
        'available_from': '2026-08-01T14:00:00Z',
        'eligibility': true,
      },
    ],
  };
}

Set<String> _allKeys(Object? value) {
  final keys = <String>{};
  if (value is Map) {
    for (final entry in value.entries) {
      keys.add(entry.key.toString());
      keys.addAll(_allKeys(entry.value));
    }
  } else if (value is Iterable) {
    for (final item in value) {
      keys.addAll(_allKeys(item));
    }
  }
  return keys;
}
