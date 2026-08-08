import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_answer_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_discovery_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_entry_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_participant_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_reconciler.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_synchronizer.dart';
import 'package:feat_gamification/src/live_game_v2_providers.dart';
import 'package:feat_gamification/src/models/live_game_v2_discovery_models.dart';
import 'package:feat_gamification/src/models/live_game_v2_models.dart';
import 'package:feat_gamification/src/screens/participant_live_games_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldenKey = ValueKey<String>('participant-live-game-golden');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  final crossClientFixture = _loadCrossClientFixture();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('discovery is code-free and separates live and scheduled games', (
    tester,
  ) async {
    final harness = await _Harness.create(
      sessions: <ParticipantGameDiscoveryItem>[
        _item(),
        _item(
          sessionId: 'scheduled-1',
          title: 'Friday club quiz',
          phase: LiveGamePhase.scheduled,
        ),
      ],
    );
    addTearDown(harness.dispose);

    await _pump(tester, harness: harness);

    expect(find.text('Live games'), findsOneWidget);
    expect(find.text('Live Now'), findsWidgets);
    expect(find.text('SCHEDULED'), findsWidgets);
    expect(find.text('Live trivia'), findsOneWidget);
    expect(find.text('Friday club quiz'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('game-session-code-field')),
      findsNothing,
    );
    expect(harness.controller.state.acceptsParticipantCode, isFalse);
  });

  testWidgets('deep link opens the eligible synchronized question', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await _pump(
      tester,
      harness: harness,
      initialLocation: '/fanzone/game/session-live',
    );

    expect(
      find.byKey(const ValueKey<String>('participant-game-live')),
      findsOneWidget,
    );
    expect(find.text('Who scored first?'), findsOneWidget);
    expect(find.text('Player A'), findsOneWidget);
    expect(harness.runtimeFactory.createdSessionIds, <String>['session-live']);
    expect(harness.discovery.requestedSessionIds, contains('session-live'));
  });

  testWidgets('answer submission adopts the authoritative confirmation', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await _pump(tester, harness: harness);

    await tester.tap(
      find.byKey(const ValueKey<String>('participant-game-session-live')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('participant-answer-b')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Answer confirmed'), findsOneWidget);
    expect(harness.runtimeFactory.answerGateways.single.requests, hasLength(1));
    expect(
      harness.runtimeFactory.answerGateways.single.requests.single.optionKey,
      'b',
    );
  });

  testWidgets('offline state retains the question and blocks answer actions', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await _pump(tester, harness: harness);
    await tester.tap(
      find.byKey(const ValueKey<String>('participant-game-session-live')),
    );
    await tester.pumpAndSettle();

    ConnectivityService.setOnlineForTest(false);
    await tester.pump();

    expect(find.text('Who scored first?'), findsOneWidget);
    expect(find.text('Live games require a connection'), findsOneWidget);
    expect(find.textContaining('Last update'), findsOneWidget);
    final option = tester.widget<AfriButton>(
      find.byKey(const ValueKey<String>('participant-answer-a')),
    );
    expect(option.enabled, isFalse);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile(
        'goldens/participant_live_game_offline_dark_390x844.png',
      ),
    );

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();
    expect(
      harness.runtimeFactory.syncGateways.single.fetchCalls,
      greaterThanOrEqualTo(2),
    );
  });

  testWidgets(
    'GAME-MOB-05 full-screen live route respects safe area without bottom navigation',
    (tester) async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);

      await _pump(
        tester,
        harness: harness,
        initialLocation: '/fanzone/game/session-live',
        viewPadding: const EdgeInsets.fromLTRB(0, 44, 0, 34),
      );

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(SafeArea), findsWidgets);
      expect(
        tester
            .getBottomLeft(
              find.byKey(const ValueKey<String>('participant-live-games-back')),
            )
            .dy,
        greaterThanOrEqualTo(44),
      );
    },
  );

  for (final locale in const <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('rw'),
  ]) {
    testWidgets(
      'GAME-MOB-05 ${locale.languageCode} live game reflows at 200 percent',
      (tester) async {
        final harness = await _Harness.create();
        addTearDown(harness.dispose);
        await _pump(
          tester,
          harness: harness,
          initialLocation: '/fanzone/game/session-live',
          locale: locale,
          textScale: 2,
          size: const Size(320, 720),
        );

        expect(find.text('Who scored first?'), findsOneWidget);
        expect(find.byType(Scrollable), findsWidgets);
        expect(tester.takeException(), isNull);
        if (locale.languageCode == 'en') {
          await expectLater(
            find.byKey(_goldenKey),
            matchesGoldenFile(
              'goldens/participant_live_game_large_text_dark_320x720.png',
            ),
          );
        }
      },
    );
  }

  testWidgets('GAME-MOB-05 keyboard inset keeps gameplay reachable', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await _pump(
      tester,
      harness: harness,
      initialLocation: '/fanzone/game/session-live',
      size: const Size(320, 720),
      viewInsets: const EdgeInsets.only(bottom: 300),
    );

    final answer = find.byKey(const ValueKey<String>('participant-answer-a'));
    await tester.ensureVisible(answer);
    await tester.pumpAndSettle();
    expect(answer, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('GAME-MOB-05 ${brightness.name} theme renders live gameplay', (
      tester,
    ) async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      await _pump(
        tester,
        harness: harness,
        initialLocation: '/fanzone/game/session-live',
        brightness: brightness,
      );

      expect(
        Theme.of(
          tester.element(find.byType(ParticipantLiveGamesScreen)),
        ).brightness,
        brightness,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile(
          'goldens/participant_live_game_${brightness.name}_390x844.png',
        ),
      );
    });
  }

  testWidgets('GAME-MOB-05 reduced motion reaches live gameplay', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await _pump(
      tester,
      harness: harness,
      initialLocation: '/fanzone/game/session-live',
      reducedMotion: true,
    );

    expect(
      MediaQuery.disableAnimationsOf(
        tester.element(find.byType(ParticipantLiveGamesScreen)),
      ),
      isTrue,
    );
  });

  testWidgets('GAME-MOB-05 discovery permission denial fails closed', (
    tester,
  ) async {
    final harness = await _Harness.create(
      discoveryError: const ParticipantDiscoveryFailure(
        ParticipantDiscoveryFailureKind.permissionDenied,
      ),
    );
    addTearDown(harness.dispose);
    await _pump(tester, harness: harness);

    expect(find.text('Live game access unavailable'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('participant-game-live')),
      findsNothing,
    );
  });

  testWidgets('GAME-MOB-05 discovery timeout is privacy safe and retryable', (
    tester,
  ) async {
    final harness = await _Harness.create(
      discoveryError: const ParticipantDiscoveryFailure(
        ParticipantDiscoveryFailureKind.timeout,
      ),
    );
    addTearDown(harness.dispose);
    await _pump(tester, harness: harness);

    expect(find.text('Secure refresh timed out'), findsOneWidget);
    expect(find.textContaining('player-secret'), findsNothing);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('resume resynchronizes the active game projection', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await _pump(tester, harness: harness);
    await tester.tap(
      find.byKey(const ValueKey<String>('participant-game-session-live')),
    );
    await tester.pumpAndSettle();
    final gateway = harness.runtimeFactory.syncGateways.single;
    final beforeResume = gateway.fetchCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(gateway.fetchCalls, beforeResume + 1);
    expect(
      find.byKey(const ValueKey<String>('participant-game-live')),
      findsOneWidget,
    );
  });

  for (final locale in const <Locale>[Locale('fr'), Locale('rw')]) {
    testWidgets(
      '${locale.languageCode} discovery reflows at 200 percent text',
      (tester) async {
        final harness = await _Harness.create();
        addTearDown(harness.dispose);
        await _pump(
          tester,
          harness: harness,
          locale: locale,
          textScale: 2,
          size: const Size(320, 720),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(ParticipantLiveGamesScreen), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
      },
    );
  }

  for (final state in crossClientFixture.states) {
    testWidgets(
      'GAME-QA-02 participant renders ${state.id} authoritative state',
      (tester) async {
        final projection = _crossClientProjection(crossClientFixture, state);
        final harness = await _Harness.create(
          sessions: <ParticipantGameDiscoveryItem>[
            _item(
              sessionId: crossClientFixture.sessionId,
              sessionVersion: state.sessionVersion,
            ),
          ],
          projections: <ParticipantGameProjection>[projection],
        );
        addTearDown(harness.dispose);

        await _pump(
          tester,
          harness: harness,
          initialLocation: '/fanzone/game/${crossClientFixture.sessionId}',
        );

        final renderedText = tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .whereType<String>()
            .toList(growable: false);
        expect(
          find.text(state.participantRenderText),
          findsWidgets,
          reason: 'Rendered text for ${state.id}: $renderedText',
        );
        expect(
          projection.version.sessionVersion,
          state.sessionVersion,
          reason: state.id,
        );
        expect(
          projection.version.questionVersion,
          state.questionVersion,
          reason: state.id,
        );
        if (state.questionPrompt != null) {
          final answer = find.byKey(
            const ValueKey<String>('participant-answer-a'),
          );
          if (state.phase == 'question_open' || state.phase == 'reveal') {
            expect(answer, findsOneWidget);
            expect(
              tester.widget<AfriButton>(answer).enabled,
              state.participantSubmitEnabled,
            );
          } else {
            expect(answer, findsNothing);
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Harness {
  _Harness({
    required this.controller,
    required this.discovery,
    required this.runtimeFactory,
  });

  final ParticipantGameEntryController controller;
  final _DiscoveryGateway discovery;
  final _RuntimeFactory runtimeFactory;

  static Future<_Harness> create({
    List<ParticipantGameDiscoveryItem>? sessions,
    List<ParticipantGameProjection>? projections,
    Object? discoveryError,
  }) async {
    final discovery = _DiscoveryGateway(
      _feed(sessions: sessions ?? <ParticipantGameDiscoveryItem>[_item()]),
      error: discoveryError,
    );
    final runtimeFactory = _RuntimeFactory(projections: projections);
    final controller = ParticipantGameEntryController(
      discoveryGateway: discovery,
      runtimeFactory: runtimeFactory,
      expectedClubId: 'club-1',
      autoStart: false,
    );
    await controller.start();
    return _Harness(
      controller: controller,
      discovery: discovery,
      runtimeFactory: runtimeFactory,
    );
  }

  Future<void> dispose() async {
    controller.dispose();
    await runtimeFactory.dispose();
  }
}

class _DiscoveryGateway implements ParticipantDiscoveryGateway {
  _DiscoveryGateway(this.feed, {this.error});

  final ParticipantGameDiscoveryFeed feed;
  final Object? error;
  final List<String?> requestedSessionIds = <String?>[];
  int fetchCalls = 0;

  @override
  Future<ParticipantGameDiscoveryFeed> fetchEligibleSessions({
    String? sessionId,
  }) async {
    fetchCalls += 1;
    requestedSessionIds.add(sessionId);
    if (error case final failure?) throw failure;
    return feed;
  }
}

class _RuntimeFactory implements ParticipantLiveGameRuntimeFactory {
  _RuntimeFactory({this.projections});

  final List<ParticipantGameProjection>? projections;
  final List<String> createdSessionIds = <String>[];
  final List<_SyncGateway> syncGateways = <_SyncGateway>[];
  final List<_AnswerGateway> answerGateways = <_AnswerGateway>[];

  @override
  ParticipantLiveGameController create({
    required String clubId,
    required String sessionId,
  }) {
    createdSessionIds.add(sessionId);
    final configured = projections;
    final sync = _SyncGateway(
      configured == null
          ? <ParticipantGameProjection>[
              _projection(clubId: clubId, sessionId: sessionId),
              _projection(
                clubId: clubId,
                sessionId: sessionId,
                sessionVersion: 5,
              ),
            ]
          : List<ParticipantGameProjection>.of(configured),
    );
    final answer = _AnswerGateway(
      configured?.last ??
          _projection(
            clubId: clubId,
            sessionId: sessionId,
            sessionVersion: 6,
            answerState: 'accepted',
            allowedActions: const <String>[],
          ),
    );
    syncGateways.add(sync);
    answerGateways.add(answer);
    return ParticipantLiveGameController(
      syncGateway: sync,
      answerGateway: answer,
      expectedClubId: clubId,
      sessionId: sessionId,
      autoStart: false,
    );
  }

  Future<void> dispose() async {
    for (final gateway in syncGateways) {
      await gateway.dispose();
    }
  }
}

class _SyncGateway implements ParticipantLiveGameGateway {
  _SyncGateway(this.projections);

  final List<ParticipantGameProjection> projections;
  final StreamController<LiveGameInvalidationHint> hints =
      StreamController<LiveGameInvalidationHint>.broadcast(sync: true);
  int fetchCalls = 0;

  @override
  Future<ParticipantGameProjection> fetchProjection() async {
    fetchCalls += 1;
    if (projections.length > 1) return projections.removeAt(0);
    return projections.single;
  }

  @override
  Stream<LiveGameInvalidationHint> watchInvalidationHints() => hints.stream;

  Future<void> dispose() => hints.close();
}

class _AnswerGateway implements ParticipantAnswerSubmissionGateway {
  _AnswerGateway(this.response);

  final ParticipantGameProjection response;
  final List<ParticipantAnswerSubmissionRequest> requests =
      <ParticipantAnswerSubmissionRequest>[];

  @override
  Future<ParticipantGameProjection> submitAnswer(
    ParticipantAnswerSubmissionRequest request,
  ) async {
    requests.add(request);
    return response;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _Harness harness,
  String initialLocation = '/fanzone/game',
  Locale locale = const Locale('en'),
  double textScale = 1,
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.dark,
  bool reducedMotion = false,
  EdgeInsets viewPadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/fanzone/game',
        builder: (_, _) => const ParticipantLiveGamesScreen(),
      ),
      GoRoute(
        path: '/fanzone/game/:sessionId',
        builder: (_, state) => ParticipantLiveGamesScreen(
          initialSessionId: state.pathParameters['sessionId'],
        ),
      ),
      GoRoute(path: '/fanzone', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        participantGameEntryControllerProvider.overrideWith(
          (ref) => harness.controller,
        ),
      ],
      child: MaterialApp.router(
        builder: (context, child) => AfriLocalizationsScope(
          locale: locale,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewPadding: viewPadding,
              viewInsets: viewInsets,
              disableAnimations: reducedMotion,
              accessibleNavigation: reducedMotion,
            ),
            child: RepaintBoundary(
              key: _goldenKey,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
        theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ParticipantGameDiscoveryFeed _feed({
  required List<ParticipantGameDiscoveryItem> sessions,
}) {
  return ParticipantGameDiscoveryFeed(
    clubId: 'club-1',
    feedVersion: 4,
    serverTime: DateTime.utc(2026, 7, 30, 8),
    publicAlias: 'Lion 42',
    sessions: sessions,
  );
}

ParticipantGameDiscoveryItem _item({
  String sessionId = 'session-live',
  String title = 'Live trivia',
  LiveGamePhase phase = LiveGamePhase.questionOpen,
  int sessionVersion = 4,
}) {
  return ParticipantGameDiscoveryItem(
    clubId: 'club-1',
    sessionId: sessionId,
    title: title,
    phase: phase,
    source: ParticipantDiscoverySource.clubMembership,
    sessionVersion: sessionVersion,
    availableFrom: DateTime.utc(2026, 8, 1, 18),
    eligible: true,
  );
}

ParticipantGameProjection _projection({
  required String clubId,
  required String sessionId,
  int sessionVersion = 4,
  String answerState = 'not_answered',
  List<String> allowedActions = const <String>['submit_answer'],
}) {
  return ParticipantGameProjection.fromJson(<String, Object?>{
    'club_id': clubId,
    'session_id': sessionId,
    'phase': 'question_open',
    'session_version': sessionVersion,
    'event_sequence': 0,
    'server_time': '2026-07-30T08:00:00Z',
    'phase_deadline': '2026-07-30T08:00:15Z',
    'question_version': 2,
    'freshness': <String, Object?>{
      'state': 'current',
      'last_event_at': '2026-07-30T08:00:00Z',
    },
    'eligibility': true,
    'public_alias': 'Lion 42',
    'answer_state': answerState,
    'allowed_actions': allowedActions,
    'question': <String, Object?>{
      'id': 'question-1',
      'prompt': 'Who scored first?',
      'options': <Map<String, String>>[
        <String, String>{'key': 'a', 'label': 'Player A'},
        <String, String>{'key': 'b', 'label': 'Player B'},
      ],
    },
    'leader_summary': <Map<String, Object>>[
      <String, Object>{'rank': 1, 'public_alias': 'Lion 42', 'score': 10},
    ],
  }, expectedClubId: clubId);
}

ParticipantGameProjection _crossClientProjection(
  _CrossClientFixture fixture,
  _CrossClientState state,
) {
  return ParticipantGameProjection.fromJson(<String, Object?>{
    'club_id': 'club-1',
    'session_id': fixture.sessionId,
    'phase': state.phase,
    'session_version': state.sessionVersion,
    'event_sequence': state.eventSequence,
    'server_time': '2026-08-01T14:00:0${state.eventSequence}Z',
    'phase_deadline': state.phase == 'question_open'
        ? '2026-08-01T14:00:30Z'
        : null,
    'question_version': state.questionVersion,
    'freshness': <String, Object?>{
      'state': 'current',
      'last_event_at': '2026-08-01T14:00:0${state.eventSequence}Z',
    },
    'eligibility': true,
    'public_alias': 'Lion 42',
    'answer_state': state.correctOptionKey == null
        ? 'not_answered'
        : 'revealed',
    'allowed_actions': state.participantSubmitEnabled
        ? <String>['submit_answer', 'retry_projection']
        : <String>['retry_projection'],
    'question': state.questionPrompt == null
        ? null
        : <String, Object?>{
            'id': 'question-${state.questionOrdinal}',
            'prompt': state.questionPrompt,
            'options': const <Map<String, String>>[
              <String, String>{'key': 'a', 'label': 'Player A'},
              <String, String>{'key': 'b', 'label': '1968'},
            ],
            if (state.correctOptionKey != null)
              'correct_option_key': state.correctOptionKey,
          },
    'leader_summary': <Map<String, Object?>>[
      <String, Object?>{
        'rank': 1,
        'public_alias': 'Fan 042',
        'score': state.eventSequence * 10,
      },
    ],
  }, expectedClubId: 'club-1');
}

_CrossClientFixture _loadCrossClientFixture() {
  final json =
      jsonDecode(_findCrossClientFixture().readAsStringSync())
          as Map<String, dynamic>;
  return _CrossClientFixture(
    sessionId: json['session_id']! as String,
    states: (json['states']! as List<dynamic>)
        .map(
          (value) => _CrossClientState.fromJson(value as Map<String, dynamic>),
        )
        .toList(growable: false),
  );
}

File _findCrossClientFixture() {
  var directory = Directory.current.absolute;
  while (true) {
    final candidate = File(
      '${directory.path}/docs/architecture/'
      'live-games-v2-cross-client-fixtures.json',
    );
    if (candidate.existsSync()) return candidate;
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Unable to locate the GAME-QA-02 fixture.');
    }
    directory = parent;
  }
}

class _CrossClientFixture {
  const _CrossClientFixture({required this.sessionId, required this.states});

  final String sessionId;
  final List<_CrossClientState> states;
}

class _CrossClientState {
  const _CrossClientState({
    required this.id,
    required this.phase,
    required this.sessionVersion,
    required this.questionVersion,
    required this.eventSequence,
    required this.questionOrdinal,
    required this.questionPrompt,
    required this.correctOptionKey,
    required this.participantSubmitEnabled,
    required this.participantRenderText,
  });

  factory _CrossClientState.fromJson(Map<String, dynamic> json) {
    return _CrossClientState(
      id: json['id']! as String,
      phase: json['phase']! as String,
      sessionVersion: json['session_version']! as int,
      questionVersion: json['question_version']! as int,
      eventSequence: json['event_sequence']! as int,
      questionOrdinal: json['question_ordinal'] as int?,
      questionPrompt: json['question_prompt'] as String?,
      correctOptionKey: json['correct_option_key'] as String?,
      participantSubmitEnabled: json['participant_submit_enabled']! as bool,
      participantRenderText: json['participant_render_text']! as String,
    );
  }

  final String id;
  final String phase;
  final int sessionVersion;
  final int questionVersion;
  final int eventSequence;
  final int? questionOrdinal;
  final String? questionPrompt;
  final String? correctOptionKey;
  final bool participantSubmitEnabled;
  final String participantRenderText;
}
