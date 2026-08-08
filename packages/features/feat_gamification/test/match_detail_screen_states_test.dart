import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/models/partner_pool_models.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/providers/match_detail_provider.dart';
import 'package:feat_gamification/src/screens/match_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldenPaths = <String, String>{
  'loading': 'goldens/match_detail_state_loading_dark_390x844.png',
  'empty': 'goldens/match_detail_state_empty_dark_390x844.png',
  'error': 'goldens/match_detail_state_error_dark_390x844.png',
  'offline': 'goldens/match_detail_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/match_detail_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/match_detail_state_disabled_dark_390x844.png',
  'focused': 'goldens/match_detail_state_focused_dark_390x844.png',
  'pressed': 'goldens/match_detail_state_pressed_dark_390x844.png',
  'selected': 'goldens/match_detail_state_selected_dark_390x844.png',
  'large_text': 'goldens/match_detail_state_large_text_dark_320x720.png',
  'reduced_motion':
      'goldens/match_detail_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/match_detail_state_dark_dark_390x844.png',
  'light': 'goldens/match_detail_state_light_light_390x844.png',
  'syncing': 'goldens/match_detail_state_syncing_dark_390x844.png',
  'conflict': 'goldens/match_detail_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/match_detail_state_security_timeout_dark_390x844.png',
};

class _NoopMatchDetailGateway implements MatchDetailGateway {
  @override
  Future<PartnerPoolMutationResult> joinPool({
    required String poolId,
    required PartnerPoolOutcome selectedOutcome,
    required String idempotencyKey,
  }) async {
    return const PartnerPoolMutationResult(status: 'success');
  }

  @override
  Future<FixtureSummary?> loadFixture(String fixtureId) async => _fixture();

  @override
  Future<PredictionMatchCenter?> loadMatchCenter(String fixtureId) async =>
      null;

  @override
  Future<List<PartnerPredictionPool>> loadPools() async =>
      <PartnerPredictionPool>[_pool()];
}

class _ControlledMatchDetailController extends MatchDetailController {
  _ControlledMatchDetailController(AsyncValue<MatchDetailState> value)
    : super(_NoopMatchDetailGateway(), 'fixture-1', autoLoad: false) {
    state = value;
  }

  int refreshCount = 0;

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

FixtureSummary _fixture() {
  return FixtureSummary(
    id: 'fixture-1',
    competitionSlug: 'rpl',
    competitionName: 'Rwanda Premier League',
    seasonLabel: '2026/27',
    matchday: 2,
    homeTeamSlug: 'rayon-sports',
    homeTeamName: 'Rayon Sports Football Club',
    homeTeamShort: 'RAY',
    awayTeamSlug: 'apr',
    awayTeamName: 'APR Football Club',
    awayTeamShort: 'APR',
    kickoffAt: DateTime.utc(2026, 8, 2, 15),
    venueName: 'Amahoro Stadium',
    status: 'scheduled',
  );
}

PartnerPredictionPool _pool() {
  return PartnerPredictionPool(
    id: 'pool-1',
    clubId: 24,
    partnerId: 'partner-1',
    partnerName: 'Visit Rwanda',
    partnerSlug: 'visit-rwanda',
    fixtureId: 'fixture-1',
    title: 'Derby WDW Pool',
    partnerStakeFet: 5000,
    fanEntryFet: 100,
    eligibilityMode: 'open_to_all',
    status: 'open',
    lockAt: DateTime.utc(2026, 8, 2, 15),
    totalEntries: 12,
    totalFanEntryFet: 1200,
  );
}

MatchDetailState _readyState({
  MatchDetailPhase phase = MatchDetailPhase.ready,
  MatchDetailMutation mutation = MatchDetailMutation.idle,
  MatchDetailFailure? failure,
}) {
  return MatchDetailState(
    fixture: _fixture(),
    partnerPools: <PartnerPredictionPool>[_pool()],
    phase: phase,
    mutation: mutation,
    failure: failure,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Match detail refreshes automatically after reconnect', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _ControlledMatchDetailController(
      const AsyncError<MatchDetailState>(
        MatchDetailFailure(MatchDetailFailureKind.offline),
        StackTrace.empty,
      ),
    );

    await _pumpRoute(
      tester,
      controller: controller,
      capture: false,
      settle: true,
    );
    expect(find.text('Match details offline'), findsOneWidget);

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();

    expect(controller.refreshCount, 1);
    expect(find.text('Connection restored'), findsOneWidget);
  });

  testWidgets('golden Match detail loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<MatchDetailState>(),
      settle: false,
    );
  });

  testWidgets('golden Match detail empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<MatchDetailState>(MatchDetailState()),
      beforeCapture: (tester) async {
        expect(find.text('Match not found'), findsOneWidget);
        expect(find.text('Back to Fan Zone'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Match detail error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<MatchDetailState>(
        MatchDetailFailure(MatchDetailFailureKind.unknown),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Match unavailable'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Match detail offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<MatchDetailState>(_readyState()),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Showing saved match'), findsOneWidget);
        expect(find.text('Join round'), findsNothing);
      },
    );
  });

  testWidgets('golden Match detail permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<MatchDetailState>(
        MatchDetailFailure(MatchDetailFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Match access unavailable'), findsOneWidget);
        expect(find.text('Refresh'), findsNothing);
      },
    );
  });

  testWidgets('golden Match detail disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<MatchDetailState>(_readyState()),
      actionsEnabled: false,
      beforeCapture: (tester) async {
        expect(find.text('Match actions unavailable'), findsOneWidget);
        expect(find.text('Join round'), findsNothing);
      },
    );
  });

  testWidgets('golden Match detail focused state', (tester) async {
    final focusNode = FocusNode(debugLabel: 'match-detail-join-focus');
    addTearDown(focusNode.dispose);
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    await _pumpState(
      tester,
      id: 'focused',
      value: AsyncData<MatchDetailState>(_readyState()),
      joinFocusNode: focusNode,
      beforeCapture: (tester) async {
        await tester.tap(find.text('Join round'));
        await tester.pumpAndSettle();
        focusNode.requestFocus();
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Match detail pressed state', (tester) async {
    TestGesture? heldGesture;
    addTearDown(() async => heldGesture?.up());

    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<MatchDetailState>(_readyState()),
      beforeCapture: (tester) async {
        await tester.tap(find.text('Join round'));
        await tester.pumpAndSettle();
        final action = find.byKey(
          const ValueKey<String>('match-detail-join-submit'),
        );
        heldGesture = await tester.startGesture(tester.getCenter(action));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 120));
      },
    );
  });

  testWidgets('golden Match detail selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<MatchDetailState>(_readyState()),
      beforeCapture: (tester) async {
        await tester.tap(find.text('Join round'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Draw'));
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.selected == true &&
                widget.properties.label == 'Selected Draw',
          ),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden Match detail large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<MatchDetailState>(_readyState()),
      size: const Size(320, 720),
      textScale: 2,
      beforeCapture: (tester) async {
        expect(find.text('Match'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  for (final localeCase
      in const <({Locale locale, String title, String stats})>[
        (locale: Locale('fr'), title: 'Match', stats: 'Stats'),
        (locale: Locale('rw'), title: 'Umukino', stats: 'Imibare'),
      ]) {
    testWidgets(
      'Match detail ${localeCase.locale.languageCode} reflows at 200 percent',
      (tester) async {
        await _pumpRoute(
          tester,
          controller: _ControlledMatchDetailController(
            AsyncData<MatchDetailState>(_readyState()),
          ),
          capture: false,
          size: const Size(320, 720),
          textScale: 2,
          locale: localeCase.locale,
        );

        expect(find.text(localeCase.title), findsOneWidget);
        expect(find.text(localeCase.stats), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('golden Match detail reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<MatchDetailState>(_readyState()),
      reducedMotion: true,
      beforeCapture: (tester) async {
        expect(
          MediaQuery.of(
            tester.element(find.byType(TabBarView)),
          ).disableAnimations,
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Match detail dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<MatchDetailState>(_readyState()),
    );
  });

  testWidgets('golden Match detail light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<MatchDetailState>(_readyState()),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden Match detail syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<MatchDetailState>(
        _readyState(
          phase: MatchDetailPhase.syncing,
          mutation: MatchDetailMutation.joiningPool,
        ),
      ),
      settle: false,
      beforeCapture: (tester) async {
        expect(find.text('Joining partner pool'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Match detail conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<MatchDetailState>(
        _readyState(
          phase: MatchDetailPhase.degraded,
          failure: const MatchDetailFailure(MatchDetailFailureKind.conflict),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Match data changed'), findsOneWidget);
        expect(find.text('REFRESH MATCH'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Match detail security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncError<MatchDetailState>(
        MatchDetailFailure(MatchDetailFailureKind.securityTimeout),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Match security check timed out'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<MatchDetailState> value,
  bool online = true,
  bool actionsEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  Locale locale = const Locale('en'),
  FocusNode? joinFocusNode,
  bool settle = true,
  Future<void> Function(WidgetTester tester)? beforeCapture,
}) async {
  ConnectivityService.setOnlineForTest(online);
  final controller = _ControlledMatchDetailController(value);
  await _pumpRoute(
    tester,
    controller: controller,
    actionsEnabled: actionsEnabled,
    brightness: brightness,
    size: size,
    textScale: textScale,
    reducedMotion: reducedMotion,
    locale: locale,
    joinFocusNode: joinFocusNode,
    settle: settle,
    beforeCapture: beforeCapture,
    goldenPath: _goldenPaths[id]!,
  );
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required _ControlledMatchDetailController controller,
  bool capture = true,
  bool actionsEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  Locale locale = const Locale('en'),
  FocusNode? joinFocusNode,
  bool settle = true,
  Future<void> Function(WidgetTester tester)? beforeCapture,
  String? goldenPath,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

  final router = GoRouter(
    initialLocation: '/fanzone/match/fixture-1',
    routes: <RouteBase>[
      GoRoute(
        path: '/fanzone/match/:fixtureId',
        builder: (context, state) => MatchDetailScreen(
          fixtureId: state.pathParameters['fixtureId']!,
          joinFocusNode: joinFocusNode,
        ),
      ),
      GoRoute(
        path: '/fanzone',
        builder: (context, state) => const Scaffold(body: Text('Fan Zone')),
        routes: <RouteBase>[
          GoRoute(
            path: 'league/:slug',
            builder: (context, state) => const Scaffold(body: Text('League')),
          ),
          GoRoute(
            path: 'team/:slug',
            builder: (context, state) => const Scaffold(body: Text('Team')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        matchDetailProvider.overrideWith((ref, fixtureId) => controller),
        matchDetailActionsEnabledProvider.overrideWithValue(actionsEnabled),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return AfriLocalizationsScope(
            locale: locale,
            child: MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: reducedMotion,
              ),
              child: child!,
            ),
          );
        },
        routerConfig: router,
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  await beforeCapture?.call(tester);
  if (capture) {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenPath!));
  }
}
