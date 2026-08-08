import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_answer_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_discovery_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_entry_controller.dart';
import 'package:feat_gamification/src/controllers/live_game_v2_participant_controller.dart';
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

const _goldenKey = ValueKey<String>('participant-route-state-golden');
const _discoveryActionKey = ValueKey<String>('participant-game-session-live');
const _liveActionKey = ValueKey<String>('participant-answer-a');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final state in _discoveryStates) {
    testWidgets('participant discovery $state route state', (tester) async {
      await _pumpRouteState(
        tester,
        route: _RouteSurface.discovery,
        state: state,
      );
    });
  }

  for (final state in _sessionStates) {
    testWidgets('participant session $state route state', (tester) async {
      await _pumpRouteState(tester, route: _RouteSurface.session, state: state);
    });
  }
}

const _discoveryStates = <String>[
  'loading',
  'empty',
  'error',
  'offline',
  'permission_denied',
  'disabled',
  'focused',
  'pressed',
  'large_text',
  'reduced_motion',
  'dark',
  'light',
  'syncing',
  'conflict',
  'security_timeout',
];

const _sessionStates = <String>[
  'loading',
  'empty',
  'error',
  'offline',
  'permission_denied',
  'disabled',
  'focused',
  'pressed',
  'selected',
  'large_text',
  'reduced_motion',
  'dark',
  'light',
  'syncing',
  'conflict',
  'security_timeout',
];

enum _RouteSurface { discovery, session }

Future<void> _pumpRouteState(
  WidgetTester tester, {
  required _RouteSurface route,
  required String state,
}) async {
  final largeText = state == 'large_text';
  final reducedMotion = state == 'reduced_motion';
  final brightness = state == 'light' ? Brightness.light : Brightness.dark;
  final size = largeText ? const Size(320, 720) : const Size(390, 844);
  final controller = ParticipantGameEntryController(
    discoveryGateway: _StaticDiscoveryGateway(),
    runtimeFactory: const _UnusedRuntimeFactory(),
    expectedClubId: 'club-1',
    autoStart: false,
    initialState: _stateFor(route, state),
  );
  addTearDown(controller.dispose);
  TestGesture? heldGesture;

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  tester.platformDispatcher.textScaleFactorTestValue = largeText ? 2 : 1;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  if (state == 'focused') {
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
  }

  final initialLocation = route == _RouteSurface.discovery
      ? '/fanzone/game'
      : '/fanzone/game/session-live';
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/fanzone/game',
        builder: (_, _) => ParticipantLiveGamesScreen(
          autofocusPrimaryAction: state == 'focused',
          autoOpenInitialSession: false,
        ),
      ),
      GoRoute(
        path: '/fanzone/game/:sessionId',
        builder: (_, routeState) => ParticipantLiveGamesScreen(
          initialSessionId: routeState.pathParameters['sessionId'],
          autofocusPrimaryAction: state == 'focused',
          autoOpenInitialSession: false,
        ),
      ),
      GoRoute(path: '/fanzone', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  addTearDown(router.dispose);

  final clubConfig = ClubConfig.fallback();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        participantGameEntryControllerProvider.overrideWith(
          (ref) => controller,
        ),
      ],
      child: AfriLocalizationsScope(
        locale: const Locale('en'),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ClubTheme.from(clubConfig, brightness: brightness),
          routerConfig: router,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                disableAnimations: reducedMotion,
                accessibleNavigation: reducedMotion,
              ),
              child: ClubConfigScope(
                config: clubConfig,
                child: RepaintBoundary(
                  key: _goldenKey,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();

  final actionKey = route == _RouteSurface.discovery
      ? _discoveryActionKey
      : _liveActionKey;
  if (<String>{'focused', 'pressed'}.contains(state)) {
    final action = find.byKey(actionKey);
    await tester.ensureVisible(action);
    await tester.pump(const Duration(milliseconds: 500));
    final detector = find
        .descendant(of: action, matching: find.byType(GestureDetector))
        .first;
    if (state == 'focused') {
      expect(Focus.of(tester.element(detector)).hasFocus, isTrue);
    } else {
      heldGesture = await tester.startGesture(tester.getCenter(action));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widgetList<ScaleTransition>(
              find.descendant(
                of: action,
                matching: find.byType(ScaleTransition),
              ),
            )
            .any((transition) => transition.scale.value < 1),
        isTrue,
      );
    }
  }

  final l10n = lookupAfriLocalizations(const Locale('en'));
  if (state == 'loading') {
    expect(
      find.text(
        route == _RouteSurface.discovery
            ? l10n.gameDiscoveringSessions
            : l10n.gameSyncing,
      ),
      findsOneWidget,
    );
  }
  if (state == 'empty') {
    expect(find.text(l10n.gameNoEligibleSessions), findsOneWidget);
  }
  if (state == 'error') {
    expect(find.text(l10n.gameDiscoveryUnavailable), findsOneWidget);
  }
  if (state == 'offline') {
    expect(find.text(l10n.gameLiveGamesConnectionRequired), findsOneWidget);
  }
  if (state == 'permission_denied') {
    expect(find.text(l10n.gameLiveAccessDeniedV2), findsOneWidget);
  }
  if (state == 'syncing') {
    expect(
      find.text(
        route == _RouteSurface.discovery
            ? l10n.gameDiscoveryRefreshing
            : l10n.gameSyncing,
      ),
      findsOneWidget,
    );
  }
  if (state == 'conflict') {
    expect(
      find.text(
        route == _RouteSurface.discovery
            ? l10n.gameDiscoveryConflict
            : l10n.gameLiveSessionConflict,
      ),
      findsOneWidget,
    );
  }
  if (state == 'security_timeout') {
    expect(find.text(l10n.gameLiveSessionTimeout), findsOneWidget);
  }
  final terminalDiscoveryState =
      route == _RouteSurface.discovery &&
      <String>{
        'loading',
        'empty',
        'error',
        'permission_denied',
        'security_timeout',
      }.contains(state);
  final terminalSessionState =
      route == _RouteSurface.session &&
      <String>{'loading', 'empty', 'error'}.contains(state);
  if (!terminalDiscoveryState && !terminalSessionState) {
    final confirmedContent = find.text('Club derby live trivia');
    expect(
      confirmedContent,
      findsOneWidget,
      reason: '$route $state must render confirmed route content',
    );
    final contentRect = tester.getRect(confirmedContent);
    expect(
      contentRect.bottom > 0 && contentRect.top < size.height,
      isTrue,
      reason:
          '$route $state must keep confirmed content in the captured viewport',
    );
  }
  if (state == 'disabled') {
    if (route == _RouteSurface.discovery) {
      expect(
        tester.widget<AfriSurfaceCard>(find.byKey(actionKey)).enabled,
        isFalse,
      );
    } else {
      expect(tester.widget<AfriButton>(find.byKey(actionKey)).enabled, isFalse);
    }
  }
  if (state == 'selected') {
    final semantics = tester.widget<Semantics>(
      find
          .ancestor(of: find.byKey(actionKey), matching: find.byType(Semantics))
          .first,
    );
    expect(semantics.properties.selected, isTrue);
  }
  if (largeText) {
    expect(find.byType(Scrollable), findsWidgets);
  }
  if (reducedMotion) {
    expect(
      AfriMotion.reduceMotion(tester.element(find.byKey(_goldenKey))),
      isTrue,
    );
  }
  expect(tester.takeException(), isNull);

  final surfaceName = route == _RouteSurface.discovery
      ? 'participant_games_discovery'
      : 'participant_live_game';
  final themeName = brightness == Brightness.light ? 'light' : 'dark';
  final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
  await expectLater(
    find.byKey(_goldenKey),
    matchesGoldenFile(
      'goldens/${surfaceName}_state_${state}_${themeName}_$dimensions.png',
    ),
  );

  await heldGesture?.cancel();
}

ParticipantGameEntryState _stateFor(_RouteSurface route, String state) {
  if (route == _RouteSurface.discovery) return _discoveryStateFor(state);
  return _sessionStateFor(state);
}

ParticipantGameEntryState _discoveryStateFor(String state) {
  if (state == 'loading') {
    return const ParticipantGameEntryState(
      status: ParticipantGameEntryStatus.discovering,
    );
  }
  if (state == 'empty') {
    return ParticipantGameEntryState(
      status: ParticipantGameEntryStatus.empty,
      feed: _feed(sessions: const <ParticipantGameDiscoveryItem>[]),
    );
  }
  if (state == 'error' || state == 'security_timeout') {
    return ParticipantGameEntryState(
      status: ParticipantGameEntryStatus.failure,
      discoveryFailureKind: state == 'security_timeout'
          ? ParticipantDiscoveryFailureKind.timeout
          : ParticipantDiscoveryFailureKind.unavailable,
    );
  }
  if (state == 'permission_denied') {
    return const ParticipantGameEntryState(
      status: ParticipantGameEntryStatus.failure,
      discoveryFailureKind: ParticipantDiscoveryFailureKind.permissionDenied,
    );
  }
  if (state == 'conflict') {
    return ParticipantGameEntryState(
      status: ParticipantGameEntryStatus.failure,
      feed: _feed(),
      discoveryFailureKind: ParticipantDiscoveryFailureKind.contract,
    );
  }
  if (state == 'offline' || state == 'disabled') {
    return ParticipantGameEntryState(
      status: ParticipantGameEntryStatus.offline,
      feed: _feed(),
    );
  }
  if (state == 'syncing') {
    return ParticipantGameEntryState(
      status: ParticipantGameEntryStatus.discovering,
      feed: _feed(),
    );
  }
  return ParticipantGameEntryState(
    status: ParticipantGameEntryStatus.ready,
    feed: _feed(),
  );
}

ParticipantGameEntryState _sessionStateFor(String state) {
  if (state == 'empty') {
    return ParticipantGameEntryState(
      status: ParticipantGameEntryStatus.empty,
      feed: _feed(sessions: const <ParticipantGameDiscoveryItem>[]),
    );
  }
  if (state == 'error') {
    return const ParticipantGameEntryState(
      status: ParticipantGameEntryStatus.failure,
      entryFailureKind: ParticipantGameEntryFailureKind.unavailable,
    );
  }

  final selected = _item();
  final projection = _projection(
    allowedActions: state == 'disabled' || state == 'selected'
        ? const <String>[]
        : const <String>['submit_answer'],
    answerState: state == 'selected' ? 'accepted' : 'not_answered',
  );
  if (state == 'loading') {
    return ParticipantGameEntryState(
      status: ParticipantGameEntryStatus.entering,
      feed: _feed(),
      selectedSession: selected,
      runtime: const ParticipantLiveGameRuntimeState.initial(),
    );
  }

  final syncStatus = switch (state) {
    'offline' => LiveGameSyncStatus.offline,
    'permission_denied' || 'security_timeout' => LiveGameSyncStatus.failure,
    'syncing' => LiveGameSyncStatus.refreshing,
    _ => LiveGameSyncStatus.ready,
  };
  final syncFailureKind = switch (state) {
    'permission_denied' => LiveGameSyncFailureKind.permissionDenied,
    'security_timeout' => LiveGameSyncFailureKind.timeout,
    _ => null,
  };
  final entryFailureKind = switch (state) {
    'permission_denied' => ParticipantGameEntryFailureKind.permissionDenied,
    'conflict' => ParticipantGameEntryFailureKind.aliasMismatch,
    'security_timeout' => ParticipantGameEntryFailureKind.unavailable,
    _ => null,
  };
  final status = switch (state) {
    'offline' => ParticipantGameEntryStatus.offline,
    'syncing' => ParticipantGameEntryStatus.entering,
    'permission_denied' ||
    'conflict' ||
    'security_timeout' => ParticipantGameEntryStatus.failure,
    _ => ParticipantGameEntryStatus.live,
  };
  return ParticipantGameEntryState(
    status: status,
    feed: _feed(),
    selectedSession: selected,
    entryFailureKind: entryFailureKind,
    runtime: ParticipantLiveGameRuntimeState(
      syncStatus: syncStatus,
      answerStatus: state == 'selected'
          ? ParticipantAnswerSubmissionStatus.accepted
          : ParticipantAnswerSubmissionStatus.idle,
      projection: projection,
      syncFailureKind: syncFailureKind,
      selectedOptionKey: state == 'selected' ? 'a' : null,
    ),
  );
}

ParticipantGameDiscoveryFeed _feed({
  List<ParticipantGameDiscoveryItem>? sessions,
}) {
  return ParticipantGameDiscoveryFeed(
    clubId: 'club-1',
    feedVersion: 4,
    serverTime: DateTime.utc(2026, 8, 1, 18),
    publicAlias: 'Lion 42',
    sessions:
        sessions ?? <ParticipantGameDiscoveryItem>[_item(), _scheduledItem()],
  );
}

ParticipantGameDiscoveryItem _item() {
  return ParticipantGameDiscoveryItem(
    clubId: 'club-1',
    sessionId: 'session-live',
    title: 'Club derby live trivia',
    phase: LiveGamePhase.questionOpen,
    source: ParticipantDiscoverySource.clubMembership,
    sessionVersion: 4,
    availableFrom: DateTime.utc(2026, 8, 1, 18),
    eligible: true,
  );
}

ParticipantGameDiscoveryItem _scheduledItem() {
  return ParticipantGameDiscoveryItem(
    clubId: 'club-1',
    sessionId: 'session-scheduled',
    title: 'Friday football quiz',
    phase: LiveGamePhase.scheduled,
    source: ParticipantDiscoverySource.clubMembership,
    sessionVersion: 2,
    availableFrom: DateTime.utc(2026, 8, 7, 18),
    eligible: true,
  );
}

ParticipantGameProjection _projection({
  required List<String> allowedActions,
  required String answerState,
}) {
  return ParticipantGameProjection.fromJson(<String, Object?>{
    'club_id': 'club-1',
    'session_id': 'session-live',
    'phase': 'question_open',
    'session_version': 4,
    'event_sequence': 12,
    'server_time': '2026-08-01T18:00:00Z',
    'phase_deadline': '2026-08-01T18:00:30Z',
    'question_version': 2,
    'freshness': <String, Object?>{
      'state': 'current',
      'last_event_at': '2026-08-01T18:00:00Z',
    },
    'eligibility': true,
    'public_alias': 'Lion 42',
    'answer_state': answerState,
    'allowed_actions': allowedActions,
    'question': const <String, Object?>{
      'id': 'question-1',
      'prompt': 'Who scored first in the club derby?',
      'options': <Map<String, String>>[
        <String, String>{'key': 'a', 'label': 'Player A'},
        <String, String>{'key': 'b', 'label': 'Player B'},
      ],
    },
    'leader_summary': const <Map<String, Object>>[
      <String, Object>{'rank': 1, 'public_alias': 'Lion 42', 'score': 10},
    ],
  }, expectedClubId: 'club-1');
}

class _StaticDiscoveryGateway implements ParticipantDiscoveryGateway {
  @override
  Future<ParticipantGameDiscoveryFeed> fetchEligibleSessions({
    String? sessionId,
  }) async => _feed();
}

class _UnusedRuntimeFactory implements ParticipantLiveGameRuntimeFactory {
  const _UnusedRuntimeFactory();

  @override
  ParticipantLiveGameController create({
    required String clubId,
    required String sessionId,
  }) {
    throw StateError('Static route-state tests do not create live runtimes.');
  }
}
