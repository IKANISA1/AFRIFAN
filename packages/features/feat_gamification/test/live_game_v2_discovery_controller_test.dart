import 'dart:async';

import 'package:feat_gamification/src/controllers/live_game_v2_discovery_controller.dart';
import 'package:feat_gamification/src/models/live_game_v2_discovery_models.dart';
import 'package:feat_gamification/src/models/live_game_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParticipantDiscoveryController', () {
    test('loads eligible sessions and resolves a session identity', () async {
      final gateway = _Gateway()..feeds.add(_feed());
      final controller = _controller(gateway);
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.state.status, ParticipantDiscoveryStatus.ready);
      expect(
        controller.resolveSessionIdentity('session-live')?.sessionId,
        'session-live',
      );
      expect(gateway.fetchCalls, 1);
    });

    test('authorizes a deep-link identity through a targeted fetch', () async {
      final gateway = _Gateway()
        ..feeds.add(_feed(sessions: const <ParticipantGameDiscoveryItem>[]))
        ..targetedFeeds['session-deep-link'] = _feed(
          feedVersion: 4,
          sessions: <ParticipantGameDiscoveryItem>[
            ParticipantGameDiscoveryItem(
              clubId: 'club-1',
              sessionId: 'session-deep-link',
              title: 'Invited trivia',
              phase: LiveGamePhase.questionOpen,
              source: ParticipantDiscoverySource.deepLink,
              sessionVersion: 4,
              availableFrom: DateTime.utc(2026, 7, 30, 8),
              eligible: true,
            ),
          ],
        );
      final controller = _controller(gateway);
      addTearDown(controller.dispose);
      await controller.start();

      final authorized = await controller.authorizeSessionIdentity(
        'session-deep-link',
      );

      expect(authorized?.source, ParticipantDiscoverySource.deepLink);
      expect(controller.state.status, ParticipantDiscoveryStatus.ready);
      expect(gateway.requestedSessionIds, <String?>[null, 'session-deep-link']);
    });

    test('reports an empty eligible feed without requesting a code', () async {
      final gateway = _Gateway()
        ..feeds.add(_feed(sessions: const <ParticipantGameDiscoveryItem>[]));
      final controller = _controller(gateway);
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.state.status, ParticipantDiscoveryStatus.empty);
      expect(controller.state.feed?.isEmpty, isTrue);
    });

    test('does not roll a discovery feed backward', () async {
      final gateway = _Gateway()
        ..feeds.addAll(<ParticipantGameDiscoveryFeed>[
          _feed(feedVersion: 4),
          _feed(feedVersion: 3, title: 'Stale title'),
        ]);
      final controller = _controller(gateway);
      addTearDown(controller.dispose);
      await controller.start();

      await controller.refresh();

      expect(controller.state.feed?.feedVersion, 4);
      expect(controller.state.feed?.sessions.single.title, 'Live trivia');
    });

    test('coalesces overlapping discovery refreshes', () async {
      final pending = Completer<ParticipantGameDiscoveryFeed>();
      final gateway = _Gateway()..pendingFeed = pending;
      final controller = _controller(gateway);
      addTearDown(controller.dispose);

      final start = controller.start();
      final refresh = controller.refresh();
      pending.complete(_feed());
      await Future.wait(<Future<void>>[start, refresh]);

      expect(gateway.fetchCalls, 1);
    });

    test(
      'retains discovery while offline and refreshes on reconnect',
      () async {
        final gateway = _Gateway()
          ..feeds.addAll(<ParticipantGameDiscoveryFeed>[
            _feed(),
            _feed(feedVersion: 4, title: 'Updated trivia'),
          ]);
        final controller = _controller(gateway);
        addTearDown(controller.dispose);
        await controller.start();

        controller.markOffline();
        expect(controller.state.status, ParticipantDiscoveryStatus.offline);
        expect(controller.state.hasRetainedFeed, isTrue);

        await controller.reconnect();

        expect(controller.state.status, ParticipantDiscoveryStatus.ready);
        expect(controller.state.feed?.sessions.single.title, 'Updated trivia');
      },
    );

    test('rejects a typed feed outside the expected club scope', () async {
      final gateway = _Gateway()..feeds.add(_feed(clubId: 'club-2'));
      final controller = _controller(gateway);
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.state.status, ParticipantDiscoveryStatus.failure);
      expect(
        controller.state.failureKind,
        ParticipantDiscoveryFailureKind.permissionDenied,
      );
      expect(controller.state.feed, isNull);
    });

    test('rejects a manually constructed ineligible session', () async {
      final gateway = _Gateway()
        ..feeds.add(
          _feed(
            sessions: <ParticipantGameDiscoveryItem>[
              ParticipantGameDiscoveryItem(
                clubId: 'club-1',
                sessionId: 'session-hidden',
                title: 'Hidden trivia',
                phase: LiveGamePhase.scheduled,
                source: ParticipantDiscoverySource.invitation,
                sessionVersion: 1,
                availableFrom: DateTime.utc(2026, 8, 1, 14),
                eligible: false,
              ),
            ],
          ),
        );
      final controller = _controller(gateway);
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.state.status, ParticipantDiscoveryStatus.failure);
      expect(
        controller.state.failureKind,
        ParticipantDiscoveryFailureKind.permissionDenied,
      );
      expect(controller.state.feed, isNull);
    });

    test('maps a timeout while retaining the prior eligible feed', () async {
      final gateway = _Gateway()..feeds.add(_feed());
      final controller = ParticipantDiscoveryController(
        gateway: gateway,
        expectedClubId: 'club-1',
        fetchTimeout: const Duration(milliseconds: 2),
      );
      addTearDown(controller.dispose);
      await controller.start();
      gateway.pendingFeed = Completer<ParticipantGameDiscoveryFeed>();

      await controller.refresh();

      expect(controller.state.status, ParticipantDiscoveryStatus.failure);
      expect(
        controller.state.failureKind,
        ParticipantDiscoveryFailureKind.timeout,
      );
      expect(controller.state.hasRetainedFeed, isTrue);
    });

    test('sanitizes raw gateway failures', () async {
      final gateway = _Gateway()
        ..fetchError = StateError('private-invitation-token');
      final controller = _controller(gateway);
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.state.status, ParticipantDiscoveryStatus.failure);
      expect(
        controller.state.failureKind,
        ParticipantDiscoveryFailureKind.unknown,
      );
      expect(controller.state.toString(), isNot(contains('private')));
    });

    test('disposal prevents controller reuse', () async {
      final gateway = _Gateway()..feeds.add(_feed());
      final controller = _controller(gateway);
      await controller.start();

      await controller.dispose();

      expect(controller.state.status, ParticipantDiscoveryStatus.disposed);
      expect(controller.refresh, throwsStateError);
    });
  });
}

ParticipantDiscoveryController _controller(_Gateway gateway) {
  return ParticipantDiscoveryController(
    gateway: gateway,
    expectedClubId: 'club-1',
  );
}

class _Gateway implements ParticipantDiscoveryGateway {
  final List<ParticipantGameDiscoveryFeed> feeds =
      <ParticipantGameDiscoveryFeed>[];
  final Map<String, ParticipantGameDiscoveryFeed> targetedFeeds =
      <String, ParticipantGameDiscoveryFeed>{};
  final List<String?> requestedSessionIds = <String?>[];

  Completer<ParticipantGameDiscoveryFeed>? pendingFeed;
  Object? fetchError;
  int fetchCalls = 0;

  @override
  Future<ParticipantGameDiscoveryFeed> fetchEligibleSessions({
    String? sessionId,
  }) async {
    fetchCalls += 1;
    requestedSessionIds.add(sessionId);
    final error = fetchError;
    if (error != null) throw error;
    if (sessionId != null) {
      final targeted = targetedFeeds[sessionId];
      if (targeted != null) return targeted;
    }
    final pending = pendingFeed;
    if (pending != null) return pending.future;
    if (feeds.isEmpty) {
      throw const ParticipantDiscoveryFailure(
        ParticipantDiscoveryFailureKind.unavailable,
      );
    }
    return feeds.removeAt(0);
  }
}

ParticipantGameDiscoveryFeed _feed({
  String clubId = 'club-1',
  int feedVersion = 3,
  String title = 'Live trivia',
  List<ParticipantGameDiscoveryItem>? sessions,
}) {
  return ParticipantGameDiscoveryFeed(
    clubId: clubId,
    feedVersion: feedVersion,
    serverTime: DateTime.utc(2026, 7, 30, 8),
    publicAlias: '240731',
    sessions:
        sessions ??
        <ParticipantGameDiscoveryItem>[
          ParticipantGameDiscoveryItem(
            clubId: clubId,
            sessionId: 'session-live',
            title: title,
            phase: LiveGamePhase.questionOpen,
            source: ParticipantDiscoverySource.clubMembership,
            sessionVersion: 7,
            availableFrom: DateTime.utc(2026, 7, 30, 7, 55),
            eligible: true,
          ),
        ],
  );
}
