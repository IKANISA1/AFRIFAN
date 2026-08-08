import 'dart:async';
import 'dart:io';

import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rayon_sports_tv/main.dart';

const _config = RayonSportsConfig();
final _now = DateTime.utc(2026, 7, 30, 18);
final _credential = List<String>.filled(64, 'a').join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ColorTokens.init(_config.colors);
    RuntimeBranding.configure(
      appName: '${_config.appName} TV',
      clubName: _config.clubName,
      countryCode: _config.countryCode,
      currencyCode: _config.currency,
      currencySymbol: _config.currencySymbol,
      homeVenueName: 'Kigali Pele Stadium',
      primaryCompetitionName: 'Matchday live',
    );
  });

  group('projection validation', () {
    test('rejects sensitive values anywhere in a TV projection', () {
      expect(
        () => TvGameProjection.fromJson(<String, dynamic>{
          ..._emptyProjectionJson(),
          'nested': <String, dynamic>{'device_credential': _credential},
        }),
        throwsA(
          isA<TvRuntimeFailure>().having(
            (failure) => failure.kind,
            'kind',
            TvRuntimeFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test(
      'rejects correct answers before reveal and accepts them at reveal',
      () {
        final question = <String, dynamic>{
          'id': 'question-1',
          'ordinal': 1,
          'prompt': 'Who scored first?',
          'options': <Map<String, dynamic>>[
            <String, dynamic>{'key': 'a', 'label': 'Player A'},
            <String, dynamic>{'key': 'b', 'label': 'Player B'},
          ],
          'correct_option_key': 'a',
        };

        expect(
          () => TvQuestionProjection.fromJson(question, phase: 'question_open'),
          throwsA(isA<TvRuntimeFailure>()),
        );
        expect(
          TvQuestionProjection.fromJson(
            question,
            phase: 'reveal',
          ).correctOptionKey,
          'a',
        );
      },
    );

    test('rejects cross-club projections', () {
      expect(
        () => TvGameProjection.fromJson(
          _emptyProjectionJson(),
          expectedClubId: 'club-2',
        ),
        throwsA(isA<TvRuntimeFailure>()),
      );
    });

    test('requires the authoritative retry and freshness contract', () {
      final projection = TvGameProjection.fromJson(_emptyProjectionJson());
      expect(projection.allowedActions, <String>{'retry_projection'});
      expect(projection.freshness?.state, 'current');
      expect(projection.freshness?.lastEventAt, _now);

      final missingFreshness = _emptyProjectionJson()..remove('freshness');
      expect(
        () => TvGameProjection.fromJson(missingFreshness),
        throwsA(isA<TvRuntimeFailure>()),
      );
    });

    test('accepts only complete supported TV lifecycle projections', () {
      final scheduled = TvGameProjection.fromJson(
        _readyProjectionJson(phase: 'scheduled', includeQuestion: false),
      );
      expect(scheduled.phase, 'scheduled');

      for (final phase in <String>['activated_lobby', 'paused', 'cancelled']) {
        expect(
          TvGameProjection.fromJson(
            _readyProjectionJson(phase: phase, includeQuestion: false),
          ).phase,
          phase,
        );
      }

      for (final phase in <String>['question_open', 'reveal', 'completed']) {
        expect(
          TvGameProjection.fromJson(_readyProjectionJson(phase: phase)).phase,
          phase,
        );
      }

      expect(
        () => TvGameProjection.fromJson(
          _readyProjectionJson(phase: 'claim_result'),
        ),
        throwsA(isA<TvRuntimeFailure>()),
      );
      expect(
        () => TvGameProjection.fromJson(
          _readyProjectionJson(phase: 'question_open', includeQuestion: false),
        ),
        throwsA(isA<TvRuntimeFailure>()),
      );
      expect(
        () => TvGameProjection.fromJson(
          _readyProjectionJson(phase: 'reveal', includeCorrectAnswer: false),
        ),
        throwsA(isA<TvRuntimeFailure>()),
      );
    });

    test('requires contiguous privacy-safe public standings', () {
      final projection = TvGameProjection.fromJson(
        _readyProjectionJson(phase: 'completed'),
      );
      expect(
        projection.leaderboard.map((entry) => entry.rank),
        orderedEquals(<int>[1, 2]),
      );
      expect(
        projection.leaderboard.map((entry) => entry.publicAlias),
        orderedEquals(<String>['Fan 042', 'Blue 118']),
      );

      final skippedRank = _readyProjectionJson(phase: 'completed');
      final secondStanding =
          (skippedRank['leaderboard']! as List<dynamic>)[1]
              as Map<String, dynamic>;
      secondStanding['rank'] = 3;
      expect(
        () => TvGameProjection.fromJson(skippedRank),
        throwsA(isA<TvRuntimeFailure>()),
      );
    });

    test('validates owner deep-link pairing payloads and credentials', () {
      final challenge = TvBootstrapChallenge.fromJson(<String, dynamic>{
        'status': 'pending_owner_claim',
        'challenge': 'TV4K8M2Q',
        'expires_at': _now.add(const Duration(minutes: 5)).toIso8601String(),
        'qr_payload': 'africlub://my-tvs/pair?challenge=TV4K8M2Q',
      });
      expect(challenge.challenge, 'TV4K8M2Q');
      expect(challenge.qrPayload, 'africlub://my-tvs/pair?challenge=TV4K8M2Q');
      expect(
        () => TvBootstrapChallenge.fromJson(<String, dynamic>{
          'status': 'pending_owner_claim',
          'challenge': 'TV4K8M2Q',
          'expires_at': _now.add(const Duration(minutes: 5)).toIso8601String(),
          'qr_payload': 'https://example.com/pair?challenge=TV4K8M2Q',
        }),
        throwsA(isA<TvRuntimeFailure>()),
      );
      expect(isValidTvCredential(List<String>.filled(64, 'z').join()), isFalse);
      expect(isValidTvCredential(_credential), isTrue);
    });

    test('validates least-privilege Realtime identity and event scope', () {
      final identity = TvRealtimeIdentity.fromJson(<String, dynamic>{
        'status': 'ready',
        'display_id': 'display-1',
        'club_id': 'club-1',
        'authorization': 'assigned_session_events_only',
      }, expectedClubId: 'club-1');
      expect(identity.displayId, 'display-1');

      final signal = TvRealtimeSignal.invalidation(
        _invalidationJson(),
        expectedClubId: 'club-1',
        expectedSessionId: 'session-1',
      );
      expect(signal.eventSequence, 9);

      expect(
        () => TvRealtimeSignal.invalidation(
          <String, dynamic>{
            ..._invalidationJson(),
            'topic': 'club-2:game_session:session-1',
          },
          expectedClubId: 'club-1',
          expectedSessionId: 'session-1',
        ),
        throwsA(isA<TvRuntimeFailure>()),
      );
    });

    test(
      'rejects duplicate options and a reveal answer outside the options',
      () {
        Map<String, dynamic> question(String correct) => <String, dynamic>{
          'id': 'question-1',
          'ordinal': 1,
          'prompt': 'Who scored first?',
          'options': <Map<String, dynamic>>[
            <String, dynamic>{'key': 'a', 'label': 'Player A'},
            <String, dynamic>{'key': 'a', 'label': 'Player B'},
          ],
          'correct_option_key': correct,
        };
        expect(
          () => TvQuestionProjection.fromJson(question('a'), phase: 'reveal'),
          throwsA(isA<TvRuntimeFailure>()),
        );
        final missingCorrectOption = question('c');
        missingCorrectOption['options'] = <Map<String, dynamic>>[
          <String, dynamic>{'key': 'a', 'label': 'Player A'},
          <String, dynamic>{'key': 'b', 'label': 'Player B'},
        ];
        expect(
          () => TvQuestionProjection.fromJson(
            missingCorrectOption,
            phase: 'reveal',
          ),
          throwsA(isA<TvRuntimeFailure>()),
        );
      },
    );

    test('reconciler ignores older server time and event sequence', () {
      final reconciler = TvProjectionReconciler();
      final current = _projection(eventSequence: 8);
      final olderSequence = _projection(eventSequence: 7);
      final olderTime = _projection(
        eventSequence: 9,
        serverTime: _now.subtract(const Duration(seconds: 1)),
      );

      expect(reconciler.accept(current), same(current));
      expect(reconciler.accept(olderSequence), same(current));
      expect(reconciler.accept(olderTime), same(current));
      expect(reconciler.current, same(current));
    });

    test('reconciler rejects lower and duplicate session versions', () {
      final reconciler = TvProjectionReconciler();
      final current = _projection(sessionVersion: 4, eventSequence: 8);
      final lower = _projection(sessionVersion: 3, eventSequence: 12);
      final duplicate = _projection(sessionVersion: 4, eventSequence: 8);
      final newer = _projection(sessionVersion: 5, eventSequence: 1);

      expect(reconciler.accept(current), same(current));
      expect(reconciler.accept(lower), same(current));
      expect(reconciler.accept(duplicate), same(current));
      expect(reconciler.accept(newer), same(newer));
    });
  });

  group('secure runtime controller', () {
    test(
      'GAME-QA-04 TV restart restores credential and authoritative snapshot',
      () async {
        final store = _MemoryStore(
          values: <String, String>{
            tvInstallationNonceStorageKey: List<String>.filled(64, 'b').join(),
            tvCredentialStorageKey: _credential,
          },
        );
        final firstGateway = _FakeGateway(
          projections: <TvGameProjection>[_projection()],
        );
        final firstController = _controller(firstGateway, store);
        await firstController.start();
        firstController.dispose();
        await firstGateway.dispose();

        final restartedGateway = _FakeGateway(
          projections: <TvGameProjection>[
            _projection(sessionVersion: 5, eventSequence: 9),
          ],
        );
        final restartedController = _controller(restartedGateway, store);
        addTearDown(restartedController.dispose);
        addTearDown(restartedGateway.dispose);

        await restartedController.start();

        expect(restartedController.state.status, TvRuntimeStatus.ready);
        expect(restartedController.state.projection?.sessionVersion, 5);
        expect(restartedGateway.createCalls, 0);
        expect(restartedGateway.exchangeCalls, 0);
        expect(restartedGateway.bindIdentityCalls, 1);
        expect(restartedGateway.fetchCalls, 1);
      },
    );

    test(
      'first run persists an installation nonce and creates a challenge',
      () async {
        final store = _MemoryStore();
        final gateway = _FakeGateway();
        final controller = _controller(gateway, store);
        addTearDown(controller.dispose);

        await controller.start();

        expect(controller.state.status, TvRuntimeStatus.awaitingOwner);
        expect(controller.state.challenge?.challenge, 'TV4K8M2Q');
        expect(store.values[tvInstallationNonceStorageKey], hasLength(64));
        expect(gateway.prepareIdentityCalls, 1);
        expect(gateway.createCalls, 1);
        expect(store.values[tvCredentialStorageKey], isNull);
      },
    );

    test('pending owner claim keeps the same challenge', () async {
      final store = _MemoryStore();
      final gateway = _FakeGateway(
        exchanges: <TvCredentialExchange>[
          TvCredentialExchange.fromJson(<String, dynamic>{
            'status': 'pending_owner_claim',
            'expires_at': _now
                .add(const Duration(minutes: 5))
                .toIso8601String(),
          }),
        ],
      );
      final controller = _controller(gateway, store);
      addTearDown(controller.dispose);

      await controller.start();
      await controller.pollPairing();

      expect(controller.state.status, TvRuntimeStatus.awaitingOwner);
      expect(controller.state.challenge?.challenge, 'TV4K8M2Q');
      expect(gateway.exchangeCalls, 1);
    });

    test(
      'new-code action creates a new challenge without exchanging',
      () async {
        final store = _MemoryStore();
        final gateway = _FakeGateway();
        final controller = _controller(gateway, store);
        addTearDown(controller.dispose);

        await controller.start();
        await controller.renewPairingChallenge();

        expect(gateway.createCalls, 2);
        expect(gateway.exchangeCalls, 0);
        expect(controller.state.status, TvRuntimeStatus.awaitingOwner);
      },
    );

    test(
      'owner claim exchanges once, stores credential, and fetches projection',
      () async {
        final store = _MemoryStore();
        final gateway = _FakeGateway(
          exchanges: <TvCredentialExchange>[_pairedExchange()],
          projections: <TvGameProjection>[_projection()],
        );
        final controller = _controller(gateway, store);
        addTearDown(controller.dispose);

        await controller.start();
        await controller.pollPairing();

        expect(controller.state.status, TvRuntimeStatus.ready);
        expect(controller.state.challenge, isNull);
        expect(store.values[tvCredentialStorageKey], _credential);
        expect(gateway.exchangeCalls, 1);
        expect(gateway.bindIdentityCalls, 1);
        expect(gateway.fetchCalls, 1);
      },
    );

    test(
      'Realtime invalidation refreshes only from a newer server version',
      () async {
        final first = _projection();
        final newer = _projection(sessionVersion: 5, eventSequence: 9);
        final store = _MemoryStore(
          values: <String, String>{
            tvInstallationNonceStorageKey: List<String>.filled(64, 'b').join(),
            tvCredentialStorageKey: _credential,
          },
        );
        final gateway = _FakeGateway(
          projections: <TvGameProjection>[first, newer],
        );
        final controller = _controller(gateway, store);
        addTearDown(controller.dispose);
        addTearDown(gateway.dispose);

        await controller.start();
        gateway.emit(
          TvRealtimeSignal.subscribed(clubId: 'club-1', sessionId: 'session-1'),
        );
        gateway.emit(
          TvRealtimeSignal.invalidation(
            _invalidationJson(),
            expectedClubId: 'club-1',
            expectedSessionId: 'session-1',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(controller.realtimeConnected, isTrue);
        expect(
          controller.realtimeSubscriptionKey,
          'club-1:game_session:session-1',
        );
        expect(gateway.fetchCalls, 2);
        expect(controller.state.projection, same(newer));

        gateway.emit(
          TvRealtimeSignal.invalidation(
            <String, dynamic>{
              ..._invalidationJson(),
              'session_version': 4,
              'question_version': 2,
              'event_sequence': 8,
            },
            expectedClubId: 'club-1',
            expectedSessionId: 'session-1',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(gateway.fetchCalls, 2);
      },
    );

    test(
      'Realtime channel failure forces a snapshot and resubscription',
      () async {
        final store = _MemoryStore(
          values: <String, String>{
            tvInstallationNonceStorageKey: List<String>.filled(64, 'b').join(),
            tvCredentialStorageKey: _credential,
          },
        );
        final gateway = _FakeGateway(
          projections: <TvGameProjection>[
            _projection(),
            _projection(sessionVersion: 5, eventSequence: 10),
          ],
        );
        final controller = _controller(gateway, store);
        addTearDown(controller.dispose);
        addTearDown(gateway.dispose);

        await controller.start();
        gateway.emitError(StateError('subscription denied'));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(gateway.fetchCalls, 2);
        expect(gateway.watchCalls, 2);
        expect(controller.state.projection?.eventSequence, 10);
      },
    );

    test(
      'secure-write retry does not exchange a one-time credential twice',
      () async {
        final store = _MemoryStore(failCredentialWrites: true);
        final gateway = _FakeGateway(
          exchanges: <TvCredentialExchange>[_pairedExchange()],
          projections: <TvGameProjection>[_projection()],
        );
        final controller = _controller(gateway, store);
        addTearDown(controller.dispose);

        await controller.start();
        await controller.pollPairing();
        expect(controller.state.status, TvRuntimeStatus.secureStorageFailure);
        expect(gateway.exchangeCalls, 1);

        store.failCredentialWrites = false;
        await controller.retry();

        expect(controller.state.status, TvRuntimeStatus.ready);
        expect(store.values[tvCredentialStorageKey], _credential);
        expect(gateway.exchangeCalls, 1);
        expect(gateway.fetchCalls, 1);
      },
    );

    test('revocation deletes the credential and fails closed', () async {
      final store = _MemoryStore(
        values: <String, String>{
          tvInstallationNonceStorageKey: List<String>.filled(64, 'b').join(),
          tvCredentialStorageKey: _credential,
        },
      );
      final gateway = _FakeGateway(
        fetchFailure: const TvRuntimeFailure(TvRuntimeFailureKind.revoked),
      );
      final controller = _controller(gateway, store);
      addTearDown(controller.dispose);

      await controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, TvRuntimeStatus.revoked);
      expect(store.values[tvCredentialStorageKey], isNull);
      expect(controller.state.projection, isNull);
    });

    test(
      'refresh failure retains only the last confirmed projection',
      () async {
        final confirmed = _projection();
        final store = _MemoryStore(
          values: <String, String>{
            tvInstallationNonceStorageKey: List<String>.filled(64, 'b').join(),
            tvCredentialStorageKey: _credential,
          },
        );
        final gateway = _FakeGateway(
          projections: <TvGameProjection>[confirmed],
        );
        final controller = _controller(gateway, store);
        addTearDown(controller.dispose);

        await controller.start();
        gateway.fetchFailure = const TvRuntimeFailure(
          TvRuntimeFailureKind.unavailable,
        );
        await controller.refreshProjection();

        expect(controller.state.status, TvRuntimeStatus.offline);
        expect(controller.state.projection, same(confirmed));
      },
    );
  });

  group('TV UI and remote contract', () {
    testWidgets(
      'TV shows a generated challenge instead of accepting a secret',
      (tester) async {
        _setTvSurface(tester);
        final challenge = _challenge();

        await tester.pumpWidget(
          RayonSportsTvApp(
            previewState: TvRuntimeState(
              status: TvRuntimeStatus.awaitingOwner,
              challenge: challenge,
            ),
          ),
        );
        await tester.pump();

        expect(find.text(challenge.challenge), findsOneWidget);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('tv-new-pairing-code')),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('remote retry shortcut and focused action are operable', (
      tester,
    ) async {
      _setTvSurface(tester);
      var retries = 0;
      await tester.pumpWidget(
        _localizedSurface(
          locale: const Locale('en'),
          child: RayonSportsTvScreen(
            state: TvRuntimeState(
              status: TvRuntimeStatus.awaitingOwner,
              challenge: _challenge(),
            ),
            onRetry: () => retries += 1,
          ),
        ),
      );
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
      expect(retries, 1);
      expect(TvRemoteControlScope.shortcuts.length, greaterThanOrEqualTo(15));
    });

    testWidgets('question, countdown, and public leaderboard fit at 720p', (
      tester,
    ) async {
      _setTvSurface(tester);
      await tester.pumpWidget(
        _localizedSurface(
          locale: const Locale('en'),
          child: RayonSportsTvScreen(
            state: TvRuntimeState(
              status: TvRuntimeStatus.ready,
              projection: _projection(),
              lastUpdated: _now,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Who scored first?'), findsOneWidget);
      expect(find.text('Fan 042'), findsOneWidget);
      expect(find.textContaining('seconds remaining'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'reveal exposes the correct answer through localized semantics',
      (tester) async {
        _setTvSurface(tester);
        await tester.pumpWidget(
          _localizedSurface(
            locale: const Locale('fr'),
            child: RayonSportsTvScreen(
              state: TvRuntimeState(
                status: TvRuntimeStatus.ready,
                projection: _projection(phase: 'reveal'),
                lastUpdated: _now,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Bonne réponse : Player A',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final locale in const <Locale>[
      Locale('en'),
      Locale('fr'),
      Locale('rw'),
    ]) {
      testWidgets('${locale.languageCode} recovery copy fits at 720p', (
        tester,
      ) async {
        _setTvSurface(tester);
        final l10n = lookupAfriLocalizations(locale);
        await tester.pumpWidget(
          _localizedSurface(
            locale: locale,
            child: RayonSportsTvScreen(
              state: const TvRuntimeState(status: TvRuntimeStatus.revoked),
              onRetry: () {},
            ),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.tvCredentialRevoked), findsOneWidget);
        expect(find.text(l10n.tvRetry), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('large text reflows game and leaderboard without overflow', (
      tester,
    ) async {
      _setTvSurface(tester);
      await tester.pumpWidget(
        _localizedSurface(
          locale: const Locale('rw'),
          textScaler: const TextScaler.linear(1.7),
          child: RayonSportsTvScreen(
            state: TvRuntimeState(
              status: TvRuntimeStatus.ready,
              projection: _projection(phase: 'paused'),
              lastUpdated: _now,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final size in const <Size>[
      Size(1280, 720),
      Size(1920, 1080),
      Size(3840, 2160),
    ]) {
      testWidgets(
        'GAME-QA-05 scales the live game at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          _setTvSurface(tester, size);
          await tester.pumpWidget(
            _localizedSurface(
              locale: const Locale('en'),
              child: RayonSportsTvScreen(
                state: TvRuntimeState(
                  status: TvRuntimeStatus.ready,
                  projection: _projection(),
                  lastUpdated: _now,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Who scored first?'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('GAME-QA-05 keeps actions inside an overscan safe area', (
      tester,
    ) async {
      _setTvSurface(tester);
      const safePadding = EdgeInsets.fromLTRB(64, 36, 64, 36);
      await tester.pumpWidget(
        _localizedSurface(
          locale: const Locale('en'),
          viewPadding: safePadding,
          child: RayonSportsTvScreen(
            state: const TvRuntimeState(status: TvRuntimeStatus.revoked),
            onRetry: () {},
          ),
        ),
      );
      await tester.pump();

      final brandRect = tester.getRect(find.byType(AfriBrandMark));
      final retryRect = tester.getRect(
        find.byKey(const ValueKey<String>('tv-header-retry')),
      );
      expect(brandRect.left, greaterThanOrEqualTo(safePadding.left));
      expect(brandRect.top, greaterThanOrEqualTo(safePadding.top));
      expect(retryRect.right, lessThanOrEqualTo(1280 - safePadding.right));
      expect(tester.takeException(), isNull);
    });

    for (final locale in const <Locale>[
      Locale('en'),
      Locale('fr'),
      Locale('rw'),
    ]) {
      testWidgets(
        'GAME-QA-05 ${locale.languageCode} long copy reflows at 200 percent',
        (tester) async {
          _setTvSurface(tester);
          await tester.pumpWidget(
            _localizedSurface(
              locale: locale,
              textScaler: const TextScaler.linear(2),
              child: RayonSportsTvScreen(
                state: TvRuntimeState(
                  status: TvRuntimeStatus.ready,
                  projection: _projection(
                    sessionTitle:
                        'Rayon Sports international supporters matchday knowledge challenge',
                    questionPrompt:
                        'Which historic moment best represents the club, its supporters, and this matchday competition?',
                  ),
                  lastUpdated: _now,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(SingleChildScrollView), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final brightness in Brightness.values) {
      testWidgets(
        'GAME-QA-05 ${brightness.name} theme renders the current game',
        (tester) async {
          _setTvSurface(tester);
          ColorTokens.setBrightness(brightness);
          addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
          await tester.pumpWidget(
            _localizedSurface(
              locale: const Locale('en'),
              child: RayonSportsTvScreen(
                state: TvRuntimeState(
                  status: TvRuntimeStatus.ready,
                  projection: _projection(),
                  lastUpdated: _now,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Who scored first?'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('GAME-QA-05 D-pad select and back actions are operable', (
      tester,
    ) async {
      _setTvSurface(tester);
      var selected = 0;
      var backed = 0;
      await tester.pumpWidget(
        _localizedSurface(
          locale: const Locale('en'),
          child: TvRemoteControlScope(
            onBack: () => backed += 1,
            child: Column(
              children: [
                Focus(
                  autofocus: true,
                  child: AfriTextButton(
                    onPressed: () {},
                    child: const Text('First'),
                  ),
                ),
                AfriTextButton(
                  onPressed: () => selected += 1,
                  child: const Text('Second'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final initialFocus = FocusManager.instance.primaryFocus;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNot(same(initialFocus)));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(selected, 1);
      expect(
        TvRemoteControlScope.shortcuts,
        contains(const SingleActivator(LogicalKeyboardKey.goBack)),
      );
      expect(
        TvRemoteControlScope.shortcuts,
        contains(const SingleActivator(LogicalKeyboardKey.contextMenu)),
      );
      expect(
        TvRemoteControlScope.shortcuts[const SingleActivator(
          LogicalKeyboardKey.contextMenu,
        )],
        isA<TvContextMenuIntent>(),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('tv-remote-context-menu')),
        findsOneWidget,
      );
      expect(find.text('Display controls'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('tv-remote-context-menu')),
        findsNothing,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(backed, 1);
    });

    testWidgets('GAME-QA-05 reduced motion reaches the TV surface', (
      tester,
    ) async {
      _setTvSurface(tester);
      await tester.pumpWidget(
        _localizedSurface(
          locale: const Locale('en'),
          disableAnimations: true,
          accessibleNavigation: true,
          child: RayonSportsTvScreen(
            state: TvRuntimeState(
              status: TvRuntimeStatus.ready,
              projection: _projection(),
              lastUpdated: _now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(RayonSportsTvScreen));
      expect(MediaQuery.disableAnimationsOf(context), isTrue);
      expect(MediaQuery.of(context).accessibleNavigation, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GAME-QA-05 exposes privacy-safe screen-reader semantics', (
      tester,
    ) async {
      _setTvSurface(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _localizedSurface(
          locale: const Locale('en'),
          child: RayonSportsTvScreen(
            state: TvRuntimeState(
              status: TvRuntimeStatus.ready,
              projection: _projection(phase: 'reveal'),
              lastUpdated: _now,
            ),
          ),
        ),
      );
      await tester.pump();

      final l10n = lookupAfriLocalizations(const Locale('en'));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  l10n.tvBrandMarkSemantic(_config.clubName),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  l10n.tvCorrectAnswerSemantic('Player A'),
        ),
        findsOneWidget,
      );
      final visibleText = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
          .join('\n')
          .toLowerCase();
      for (final forbidden in <String>[
        _credential,
        'phone',
        'email',
        'wallet',
        'access token',
        'device credential',
      ]) {
        expect(visibleText, isNot(contains(forbidden)));
      }
      semantics.dispose();
    });
  });

  test(
    'Android manifest declares the native TV launch and security contract',
    () {
      final manifest = File(
        '${_packageRootPrefix()}android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.software.leanback'));
      expect(manifest, contains('android.intent.category.LEANBACK_LAUNCHER'));
      expect(manifest, contains('android.hardware.touchscreen'));
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
    },
  );

  test('Android release contract rejects debug signing', () {
    final gradle = File(
      '${_packageRootPrefix()}android/app/build.gradle.kts',
    ).readAsStringSync();
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(gradle, contains('TV_ANDROID_KEYSTORE_PATH'));
    expect(gradle, contains('TV release signing credentials are required'));
  });

  test(
    'TV source uses only the authoritative v2 pairing and projection RPCs',
    () {
      final source = File(
        '${_packageRootPrefix()}lib/src/tv_runtime.dart',
      ).readAsStringSync();
      expect(source, contains('create_display_pairing_challenge_v2'));
      expect(source, contains('exchange_display_pairing_challenge_v2'));
      expect(source, contains('get_tv_game_projection_v2'));
      expect(source, contains('bind_tv_realtime_identity_v2'));
      expect(source, contains("schema: 'africlub_game'"));
      expect(source, contains("table: 'game_events'"));
      expect(source, isNot(contains("'exchange_tv_pairing_code'")));
      expect(source, isNot(contains("'get_tv_display_state_with_credential'")));
      expect(source, isNot(contains("String.fromEnvironment('TV_DEVICE_ID')")));
    },
  );
}

TvRuntimeController _controller(_FakeGateway gateway, _MemoryStore store) {
  return TvRuntimeController(
    gateway: gateway,
    store: store,
    configurationAvailable: true,
    enableTimers: false,
    now: () => _now,
  );
}

TvBootstrapChallenge _challenge() {
  return TvBootstrapChallenge(
    challenge: 'TV4K8M2Q',
    expiresAt: _now.add(const Duration(minutes: 5)),
    qrPayload: 'africlub://my-tvs/pair?challenge=TV4K8M2Q',
  );
}

TvCredentialExchange _pairedExchange() {
  return TvCredentialExchange.fromJson(<String, dynamic>{
    'status': 'paired',
    'device_credential': _credential,
    'display_id': 'display-1',
    'club_id': 'club-1',
  });
}

TvGameProjection _projection({
  String phase = 'question_open',
  int sessionVersion = 4,
  int eventSequence = 8,
  DateTime? serverTime,
  String sessionTitle = 'Matchday knowledge challenge',
  String questionPrompt = 'Who scored first?',
}) {
  final reveal = phase == 'reveal' || phase == 'completed';
  return TvGameProjection(
    status: 'ready',
    displayId: 'display-1',
    clubId: 'club-1',
    serverTime: serverTime ?? _now,
    sessionId: 'session-1',
    sessionTitle: sessionTitle,
    phase: phase,
    sessionVersion: sessionVersion,
    questionVersion: 2,
    eventSequence: eventSequence,
    phaseDeadline: phase == 'question_open'
        ? DateTime.now().toUtc().add(const Duration(seconds: 45))
        : null,
    question: TvQuestionProjection(
      id: 'question-1',
      ordinal: 1,
      prompt: questionPrompt,
      options: const <TvQuestionOption>[
        TvQuestionOption(key: 'a', label: 'Player A'),
        TvQuestionOption(key: 'b', label: 'Player B'),
      ],
      correctOptionKey: reveal ? 'a' : null,
    ),
    leaderboard: const <TvLeaderboardEntry>[
      TvLeaderboardEntry(rank: 1, publicAlias: 'Fan 042', score: 120),
      TvLeaderboardEntry(rank: 2, publicAlias: 'Blue 118', score: 95),
    ],
  );
}

Map<String, dynamic> _emptyProjectionJson() => <String, dynamic>{
  'status': 'empty',
  'display_id': 'display-1',
  'club_id': 'club-1',
  'server_time': _now.toIso8601String(),
  'allowed_actions': <String>['retry_projection'],
  'freshness': <String, dynamic>{
    'state': 'current',
    'last_event_at': _now.toIso8601String(),
  },
};

Map<String, dynamic> _readyProjectionJson({
  required String phase,
  bool includeQuestion = true,
  bool includeCorrectAnswer = true,
}) => <String, dynamic>{
  'status': 'ready',
  'display_id': 'display-1',
  'club_id': 'club-1',
  'server_time': _now.toIso8601String(),
  'allowed_actions': <String>['retry_projection'],
  'freshness': <String, dynamic>{
    'state': 'current',
    'last_event_at': _now.toIso8601String(),
  },
  'session_id': 'session-1',
  'session_title': 'Matchday knowledge challenge',
  'phase': phase,
  'session_version': 4,
  'question_version': 2,
  'event_sequence': 8,
  'phase_deadline': phase == 'question_open'
      ? _now.add(const Duration(seconds: 45)).toIso8601String()
      : null,
  'question': !includeQuestion
      ? null
      : <String, dynamic>{
          'id': 'question-1',
          'ordinal': 1,
          'prompt': 'Who scored first?',
          'options': <Map<String, dynamic>>[
            <String, dynamic>{'key': 'a', 'label': 'Player A'},
            <String, dynamic>{'key': 'b', 'label': 'Player B'},
          ],
          if (includeCorrectAnswer &&
              (phase == 'reveal' || phase == 'completed'))
            'correct_option_key': 'a',
        },
  'leaderboard': <Map<String, dynamic>>[
    <String, dynamic>{'rank': 1, 'public_alias': 'Fan 042', 'score': 120},
    <String, dynamic>{'rank': 2, 'public_alias': 'Blue 118', 'score': 95},
  ],
};

Map<String, dynamic> _invalidationJson() => <String, dynamic>{
  'club_id': 'club-1',
  'session_id': 'session-1',
  'topic': 'club-1:game_session:session-1',
  'event_type': 'projection_invalidated',
  'session_version': 5,
  'question_version': 3,
  'event_sequence': 9,
  'payload': <String, dynamic>{'requires_projection_refresh': true},
};

class _FakeGateway implements TvRuntimeGateway {
  _FakeGateway({
    List<TvCredentialExchange>? exchanges,
    List<TvGameProjection>? projections,
    this.fetchFailure,
  }) : exchanges = exchanges ?? <TvCredentialExchange>[],
       projections = projections ?? <TvGameProjection>[];

  final List<TvCredentialExchange> exchanges;
  final List<TvGameProjection> projections;
  final StreamController<TvRealtimeSignal> realtime =
      StreamController<TvRealtimeSignal>.broadcast();
  TvRuntimeFailure? fetchFailure;
  int prepareIdentityCalls = 0;
  int createCalls = 0;
  int exchangeCalls = 0;
  int bindIdentityCalls = 0;
  int fetchCalls = 0;
  int watchCalls = 0;

  @override
  Future<void> prepareDeviceIdentity() async {
    prepareIdentityCalls += 1;
  }

  @override
  Future<TvBootstrapChallenge> createPairingChallenge({
    required String installationNonce,
  }) async {
    createCalls += 1;
    return _challenge();
  }

  @override
  Future<TvCredentialExchange> exchangePairingChallenge({
    required String challenge,
    required String installationNonce,
  }) async {
    exchangeCalls += 1;
    if (exchanges.isEmpty) {
      return TvCredentialExchange.fromJson(<String, dynamic>{
        'status': 'pending_owner_claim',
        'expires_at': _now.add(const Duration(minutes: 5)).toIso8601String(),
      });
    }
    return exchanges.removeAt(0);
  }

  @override
  Future<TvRealtimeIdentity> bindRealtimeIdentity(String credential) async {
    bindIdentityCalls += 1;
    return const TvRealtimeIdentity(displayId: 'display-1', clubId: 'club-1');
  }

  @override
  Future<TvGameProjection> fetchProjection(String credential) async {
    fetchCalls += 1;
    final failure = fetchFailure;
    if (failure != null) throw failure;
    if (projections.isEmpty) {
      return TvGameProjection.fromJson(_emptyProjectionJson());
    }
    return projections.removeAt(0);
  }

  @override
  Stream<TvRealtimeSignal> watchInvalidations({
    required String clubId,
    required String sessionId,
  }) {
    watchCalls += 1;
    return realtime.stream;
  }

  void emit(TvRealtimeSignal signal) => realtime.add(signal);

  void emitError(Object error) => realtime.addError(error);

  Future<void> dispose() => realtime.close();
}

class _MemoryStore implements TvCredentialStore {
  _MemoryStore({Map<String, String>? values, this.failCredentialWrites = false})
    : values = values ?? <String, String>{};

  final Map<String, String> values;
  bool failCredentialWrites;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (key == tvCredentialStorageKey && failCredentialWrites) {
      throw StateError('secure write unavailable');
    }
    values[key] = value;
  }
}

Widget _localizedSurface({
  required Locale locale,
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewPadding = EdgeInsets.zero,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
}) {
  return MaterialApp(
    theme: ClubTheme.from(_config),
    locale: locale.languageCode == 'rw' ? const Locale('en') : locale,
    supportedLocales: const <Locale>[Locale('en'), Locale('fr')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AfriLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, appChild) => AfriLocalizationsScope(
      locale: locale,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          padding: viewPadding,
          viewPadding: viewPadding,
          disableAnimations: disableAnimations,
          accessibleNavigation: accessibleNavigation,
        ),
        child: appChild ?? const SizedBox.shrink(),
      ),
    ),
    home: child,
  );
}

void _setTvSurface(WidgetTester tester, [Size size = const Size(1280, 720)]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

String _packageRootPrefix() {
  return File('apps/rayon_sports_tv/pubspec.yaml').existsSync()
      ? 'apps/rayon_sports_tv/'
      : '';
}
