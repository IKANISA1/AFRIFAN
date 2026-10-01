import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/predict/predict_pick_screen.dart';
import 'package:feat_gamification/src/providers/prediction_detail_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

import '../../../testing/test_support/test/fixtures/local_route_state_assertions.dart';

const _goldenPaths = <String, String>{
  'loading': 'goldens/prediction_detail_state_loading_dark_390x844.png',
  'empty': 'goldens/prediction_detail_state_empty_dark_390x844.png',
  'error': 'goldens/prediction_detail_state_error_dark_390x844.png',
  'offline': 'goldens/prediction_detail_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/prediction_detail_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/prediction_detail_state_disabled_dark_390x844.png',
  'focused': 'goldens/prediction_detail_state_focused_dark_390x844.png',
  'pressed': 'goldens/prediction_detail_state_pressed_dark_390x844.png',
  'selected': 'goldens/prediction_detail_state_selected_dark_390x844.png',
  'large_text': 'goldens/prediction_detail_state_large_text_dark_320x720.png',
  'reduced_motion':
      'goldens/prediction_detail_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/prediction_detail_state_dark_dark_390x844.png',
  'light': 'goldens/prediction_detail_state_light_light_390x844.png',
  'syncing': 'goldens/prediction_detail_state_syncing_dark_390x844.png',
  'conflict': 'goldens/prediction_detail_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/prediction_detail_state_security_timeout_dark_390x844.png',
};

class _NoopPredictionDetailGateway implements PredictionDetailGateway {
  @override
  Future<PredictionPlaceResult> cancel(String predictionId) {
    return Future.value(
      const PredictionPlaceResult(status: 'cancelled', message: 'Cancelled.'),
    );
  }

  @override
  Future<PredictionDetail?> load(String predictionId) {
    return Future.value(_pendingDetail());
  }
}

class _ControlledPredictionDetailController extends PredictionDetailController {
  _ControlledPredictionDetailController(AsyncValue<PredictionDetailState> value)
    : super(_NoopPredictionDetailGateway(), 'prediction-1', autoLoad: false) {
    state = value;
  }

  int refreshCount = 0;

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

PredictionDetail _pendingDetail({
  String selectedOutcome = 'Rayon Sports',
  PredictionStatus status = PredictionStatus.pending,
}) {
  return PredictionDetail(
    id: 'prediction-1',
    fixtureId: 'fixture-1',
    marketSlug: 'match-winner',
    marketName: 'Match winner',
    marketShortName: 'Winner',
    marketGroup: MarketGroup.matchResult,
    difficultyTier: DifficultyTier.mid,
    competitionName: 'Rwanda Premier League',
    homeTeam: 'Rayon Sports Football Club',
    homeTeamShort: 'RAY',
    awayTeam: 'APR Football Club',
    awayTeamShort: 'APR',
    selectedOutcome: selectedOutcome,
    status: status,
    fetPotential: 120,
    fetEarned: status == PredictionStatus.won ? 120 : 0,
    slipId: 'private-slip-supporter-991',
    venueName: 'Amahoro Stadium',
    kickoffAt: DateTime.utc(2026, 7, 30, 18),
    placedAt: DateTime.utc(2026, 7, 28, 9),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('Prediction detail refreshes automatically after reconnect', (
    tester,
  ) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _ControlledPredictionDetailController(
      const AsyncError<PredictionDetailState>(
        PredictionDetailFailure(PredictionDetailFailureKind.offline),
        StackTrace.empty,
      ),
    );

    await _pumpRoute(
      tester,
      controller: controller,
      capture: false,
      settle: true,
    );
    expect(find.text('Activity details offline'), findsOneWidget);

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();

    expect(controller.refreshCount, 1);
    expect(find.text('Connection restored'), findsOneWidget);
  });

  testWidgets('golden Prediction detail loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<PredictionDetailState>(),
      settle: false,
    );
  });

  testWidgets('golden Prediction detail empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<PredictionDetailState>(PredictionDetailState()),
      beforeCapture: (tester) async {
        expect(find.text('Activity not found'), findsOneWidget);
        expect(find.text('Back to predictions'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Prediction detail error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<PredictionDetailState>(
        PredictionDetailFailure(PredictionDetailFailureKind.unknown),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Activity unavailable'), findsOneWidget);
        expect(find.textContaining('supporter-991'), findsNothing);
      },
    );
  });

  testWidgets('golden Prediction detail offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<PredictionDetailState>(
        PredictionDetailState(detail: _pendingDetail()),
      ),
      online: false,
      beforeCapture: (tester) async {
        expect(find.text('Showing saved activity'), findsOneWidget);
        final cancelAction = find.byKey(
          const ValueKey<String>('prediction-detail-cancel-action'),
        );
        await tester.scrollUntilVisible(cancelAction, 260);
        expect(tester.widget<AfriButton>(cancelAction).enabled, isFalse);
      },
    );
  });

  testWidgets('golden Prediction detail permission-denied state', (
    tester,
  ) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<PredictionDetailState>(
        PredictionDetailFailure(PredictionDetailFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Activity access unavailable'), findsOneWidget);
        expect(find.text('Refresh'), findsNothing);
      },
    );
  });

  testWidgets('golden Prediction detail disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<PredictionDetailState>(
        PredictionDetailState(detail: _pendingDetail()),
      ),
      actionsEnabled: false,
      beforeCapture: (tester) async {
        expect(find.text('Activity actions unavailable'), findsOneWidget);
        final cancelAction = find.byKey(
          const ValueKey<String>('prediction-detail-cancel-action'),
        );
        await tester.scrollUntilVisible(cancelAction, 260);
        expect(tester.widget<AfriButton>(cancelAction).enabled, isFalse);
      },
    );
  });

  testWidgets('golden Prediction detail focused state', (tester) async {
    final focusNode = FocusNode(debugLabel: 'prediction-detail-browse-focus');
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
      value: AsyncData<PredictionDetailState>(
        PredictionDetailState(detail: _pendingDetail()),
      ),
      browseFocusNode: focusNode,
      beforeCapture: (tester) async {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey<String>('prediction-detail-browse-action')),
          260,
        );
        focusNode.requestFocus();
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden Prediction detail pressed state', (tester) async {
    TestGesture? heldGesture;
    addTearDown(() async {
      await heldGesture?.up();
    });

    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<PredictionDetailState>(
        PredictionDetailState(detail: _pendingDetail()),
      ),
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('prediction-detail-browse-action'),
        );
        await tester.scrollUntilVisible(action, 260);
        heldGesture = await tester.startGesture(tester.getCenter(action));
        await tester.pump(const Duration(milliseconds: 120));
      },
    );
  });

  testWidgets('golden Prediction detail selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<PredictionDetailState>(
        PredictionDetailState(detail: _pendingDetail(selectedOutcome: 'Draw')),
      ),
      beforeCapture: (tester) async {
        await tester.scrollUntilVisible(find.text('Selection').first, 260);
        final selectedMetric = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.selected == true &&
              widget.properties.label == 'Selected Selection Draw',
          description: 'selected prediction detail metric semantics',
        );
        expect(selectedMetric, findsOneWidget);
      },
    );
  });

  testWidgets('golden Prediction detail large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<PredictionDetailState>(
        PredictionDetailState(detail: _pendingDetail()),
      ),
      size: const Size(320, 720),
      textScale: 2,
      beforeCapture: (tester) async {
        final action = find.byKey(
          const ValueKey<String>('prediction-detail-browse-action'),
        );
        await tester.scrollUntilVisible(action, 220);
        expect(find.text('Browse fixtures'), findsOneWidget);
        expect(find.textContaining('private-slip'), findsNothing);
      },
    );
  });

  for (final localeCase
      in const <({Locale locale, String title, String browse})>[
        (
          locale: Locale('en'),
          title: 'Activity detail',
          browse: 'Browse fixtures',
        ),
        (
          locale: Locale('en'),
          title: 'Activity detail',
          browse: 'Browse fixtures',
        ),
        (
          locale: Locale('en'),
          title: 'Activity detail',
          browse: 'Browse fixtures',
        ),
      ]) {
    testWidgets(
      'Prediction detail ${localeCase.locale.languageCode} reflows at 200 percent',
      (tester) async {
        final controller = _ControlledPredictionDetailController(
          AsyncData<PredictionDetailState>(
            PredictionDetailState(detail: _pendingDetail()),
          ),
        );
        await _pumpRoute(
          tester,
          controller: controller,
          capture: false,
          size: const Size(320, 760),
          textScale: 2,
          locale: localeCase.locale,
        );

        expect(find.text(localeCase.title), findsOneWidget);
        final action = find.byKey(
          const ValueKey<String>('prediction-detail-browse-action'),
        );
        await tester.scrollUntilVisible(action, 220);
        expect(find.text(localeCase.browse), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('golden Prediction detail reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<PredictionDetailState>(
        PredictionDetailState(detail: _pendingDetail()),
      ),
      reducedMotion: true,
      beforeCapture: (tester) async {
        expect(
          MediaQuery.of(
            tester.element(find.byType(CustomScrollView)),
          ).disableAnimations,
          isTrue,
        );
      },
    );
  });

  testWidgets('golden Prediction detail dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<PredictionDetailState>(
        PredictionDetailState(detail: _pendingDetail()),
      ),
    );
  });

  testWidgets('golden Prediction detail light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<PredictionDetailState>(
        PredictionDetailState(detail: _pendingDetail()),
      ),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden Prediction detail syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<PredictionDetailState>(
        PredictionDetailState(
          detail: _pendingDetail(),
          phase: PredictionDetailPhase.syncing,
          mutation: PredictionDetailMutation.cancelling,
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Cancelling pick'), findsOneWidget);
      },
      settle: false,
    );
  });

  testWidgets('golden Prediction detail conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<PredictionDetailState>(
        PredictionDetailState(
          detail: _pendingDetail(),
          phase: PredictionDetailPhase.degraded,
          failure: const PredictionDetailFailure(
            PredictionDetailFailureKind.conflict,
          ),
        ),
      ),
      beforeCapture: (tester) async {
        expect(find.text('Activity data changed'), findsOneWidget);
        expect(find.text('Refresh activity'), findsOneWidget);
      },
    );
  });

  testWidgets('golden Prediction detail security-timeout state', (
    tester,
  ) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncError<PredictionDetailState>(
        PredictionDetailFailure(PredictionDetailFailureKind.securityTimeout),
        StackTrace.empty,
      ),
      beforeCapture: (tester) async {
        expect(find.text('Activity security check timed out'), findsOneWidget);
        expect(find.textContaining('supporter-991'), findsNothing);
      },
    );
  });
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<PredictionDetailState> value,
  bool online = true,
  bool actionsEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  FocusNode? browseFocusNode,
  Locale locale = const Locale('en'),
  bool settle = true,
  Future<void> Function(WidgetTester tester)? beforeCapture,
}) async {
  ConnectivityService.setOnlineForTest(online);
  final controller = _ControlledPredictionDetailController(value);
  await _pumpRoute(
    tester,
    controller: controller,
    actionsEnabled: actionsEnabled,
    brightness: brightness,
    size: size,
    textScale: textScale,
    reducedMotion: reducedMotion,
    browseFocusNode: browseFocusNode,
    locale: locale,
    settle: settle,
    beforeCapture: beforeCapture,
    goldenPath: _goldenPaths[id]!,
  );
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required _ControlledPredictionDetailController controller,
  bool capture = true,
  bool actionsEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  FocusNode? browseFocusNode,
  Locale locale = const Locale('en'),
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
    initialLocation: '/predict/picks/prediction-1',
    routes: <RouteBase>[
      GoRoute(
        path: '/predict/picks/:predictionId',
        builder: (context, state) => PredictPickScreen(
          predictionId: state.pathParameters['predictionId']!,
          browseFocusNode: browseFocusNode,
        ),
      ),
      GoRoute(
        path: '/predict',
        builder: (context, state) => const Scaffold(body: Text('Predict')),
        routes: <RouteBase>[
          GoRoute(
            path: 'fixtures',
            redirect: (context, state) => '/predict?section=league',
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        predictionDetailProvider.overrideWith(
          (ref, predictionId) => controller,
        ),
        predictionDetailActionsEnabledProvider.overrideWithValue(
          actionsEnabled,
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ClubTheme.from(
          localRouteConfigOrFallback(),
          brightness: brightness,
        ),
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
    await expectGoldenOrClubAssertions(
      tester,
      find.byType(MaterialApp),
      goldenPath!,
      route: '/predict/picks/:predictionId',
      kind: 'route',
    );
  }
}
