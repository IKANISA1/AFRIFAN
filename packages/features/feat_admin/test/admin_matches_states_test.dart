import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/match_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldenViewport = Size(390, 844);
const _goldenViewportId = '390x844';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  setUp(() {
    ConnectivityService.setOnlineForTest(true);
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDown(() {
    ConnectivityService.setOnlineForTest(true);
    TypographyTokens.debugUseFallbackFonts = false;
    ColorTokens.setBrightness(Brightness.dark);
  });

  testWidgets('renders a truthful loading state', (tester) async {
    final pending = Completer<AdminMatchesSnapshot>();
    await _pumpMatches(
      tester,
      gateway: _Gateway(<Object>[pending.future]),
      settle: false,
    );

    expect(find.text('Loading match workspace'), findsOneWidget);
    expect(find.textContaining('APR FC'), findsNothing);
    await _expectStateGolden(tester, 'loading');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('renders a confirmed empty workspace', (tester) async {
    await _pumpMatches(
      tester,
      gateway: _Gateway(const <Object>[AdminMatchesSnapshot.empty()]),
    );

    expect(find.text('No fixtures configured'), findsOneWidget);
    expect(find.textContaining('confirmed partner scope'), findsOneWidget);
    await _expectStateGolden(tester, 'empty');
  });

  testWidgets('renders a privacy-safe unknown error', (tester) async {
    await _pumpMatches(
      tester,
      gateway: _Gateway(<Object>[
        StateError('provider row private-account-991 failed'),
      ]),
    );

    expect(find.text('Match workspace unavailable'), findsOneWidget);
    expect(find.textContaining('private-account-991'), findsNothing);
    await _expectStateGolden(tester, 'error');
  });

  testWidgets('renders offline without private fixtures', (tester) async {
    await _pumpMatches(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      online: false,
    );

    expect(find.text('Match workspace offline'), findsOneWidget);
    expect(find.textContaining('APR FC'), findsNothing);
    await _expectStateGolden(tester, 'offline');
  });

  testWidgets('permission denial clears fixture information', (tester) async {
    await _pumpMatches(
      tester,
      gateway: _Gateway(const <Object>[
        AdminMatchesFailure(AdminMatchesFailureKind.permissionDenied),
      ]),
    );

    expect(find.text('Match access unavailable'), findsOneWidget);
    expect(find.textContaining('APR FC'), findsNothing);
    await _expectStateGolden(tester, 'permission_denied');
  });

  testWidgets('renders the feature-disabled state', (tester) async {
    await _pumpMatches(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      enabled: false,
    );

    expect(find.text('Match management unavailable'), findsOneWidget);
    expect(
      find.textContaining('disabled for this controlled build'),
      findsOneWidget,
    );
    await _expectStateGolden(tester, 'disabled');
  });

  testWidgets('selected filter exposes current selection', (tester) async {
    await _pumpMatches(tester, gateway: _Gateway(<Object>[_workspace]));

    await tester.tap(find.widgetWithText(AfriChoiceChip, 'LIVE'));
    await tester.pumpAndSettle();

    final selected = tester.widget<AfriChoiceChip>(
      find.widgetWithText(AfriChoiceChip, 'LIVE'),
    );
    expect(selected.selected, isTrue);
    expect(find.textContaining('POLICE FC'), findsOneWidget);
    expect(find.textContaining('APR FC'), findsNothing);
    await _expectStateGolden(tester, 'selected');
  });

  testWidgets('fixture card supports held press and keyboard focus', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'fixture-card');
    addTearDown(focusNode.dispose);
    final previousStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpMatches(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      firstActionFocusNode: focusNode,
    );
    final action = find.byKey(const ValueKey<String>('admin-match-match-1'));

    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(action));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 100));
    await _expectStateGolden(tester, 'pressed');
    await gesture.cancel();
    await tester.pumpAndSettle();

    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    await _expectStateGolden(tester, 'focused');
  });

  testWidgets('supports 200 percent text without horizontal overflow', (
    tester,
  ) async {
    await _pumpMatches(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
    await _expectStateGolden(tester, 'large_text');
  });

  testWidgets('respects reduced motion', (tester) async {
    await _pumpMatches(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      reduceMotion: true,
    );

    final context = tester.element(find.byType(MatchManagerScreen));
    expect(AfriMotion.reduceMotion(context), isTrue);
    expect(tester.takeException(), isNull);
    await _expectStateGolden(tester, 'reduced_motion');
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    testWidgets('renders the ${brightness.name} theme', (tester) async {
      await _pumpMatches(
        tester,
        gateway: _Gateway(<Object>[_workspace]),
        brightness: brightness,
      );

      expect(find.text('MATCHES'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(MatchManagerScreen))).brightness,
        brightness,
      );
      expect(tester.takeException(), isNull);
      await _expectStateGolden(tester, brightness.name);
    });
  }

  testWidgets('syncing retains confirmed fixture information', (tester) async {
    final pending = Completer<AdminMatchesSnapshot>();
    final gateway = _Gateway(<Object>[_workspace, pending.future]);
    final container = await _pumpMatches(tester, gateway: gateway);

    unawaited(container.read(adminMatchesProvider.notifier).refresh());
    await tester.pump();

    expect(find.text('Checking fixture information'), findsOneWidget);
    expect(find.textContaining('APR FC'), findsOneWidget);
    await _expectStateGolden(tester, 'syncing');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('conflict retains fixtures and explains recovery', (
    tester,
  ) async {
    final gateway = _Gateway(<Object>[
      _workspace,
      const AdminMatchesFailure(AdminMatchesFailureKind.conflict),
    ]);
    final container = await _pumpMatches(tester, gateway: gateway);

    await container.read(adminMatchesProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Fixture information changed'), findsOneWidget);
    expect(find.textContaining('APR FC'), findsOneWidget);
    expect(find.textContaining('Controls are paused'), findsOneWidget);
    await _expectStateGolden(tester, 'conflict');
  });

  testWidgets('security timeout retains fixtures and hides diagnostics', (
    tester,
  ) async {
    final gateway = _Gateway(<Object>[
      _workspace,
      TimeoutException('private-admin-id timed out'),
    ]);
    final container = await _pumpMatches(tester, gateway: gateway);

    await container.read(adminMatchesProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Security check timed out'), findsOneWidget);
    expect(find.textContaining('APR FC'), findsOneWidget);
    expect(find.textContaining('private-admin-id'), findsNothing);
    await _expectStateGolden(tester, 'security_timeout');
  });
}

Future<ProviderContainer> _pumpMatches(
  WidgetTester tester, {
  required AdminMatchesGateway gateway,
  bool enabled = true,
  bool online = true,
  bool settle = true,
  bool reduceMotion = false,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  FocusNode? firstActionFocusNode,
}) async {
  tester.view.physicalSize = _goldenViewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reduceMotion,
        accessibleNavigation: reduceMotion,
      );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  ConnectivityService.setOnlineForTest(online);
  ColorTokens.setBrightness(brightness);

  final router = GoRouter(
    initialLocation: '/admin/matches',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/matches',
        builder: (_, _) =>
            MatchManagerScreen(firstActionFocusNode: firstActionFocusNode),
      ),
    ],
  );
  addTearDown(router.dispose);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminMatchesGatewayProvider.overrideWithValue(gateway),
        adminMatchesEnabledProvider.overrideWithValue(enabled),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          container = ProviderScope.containerOf(context);
          return ClubConfigScope(
            config: ClubConfig.fallback(),
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(
                    disableAnimations: reduceMotion,
                    accessibleNavigation: reduceMotion,
                  ),
                  child: child!,
                );
              },
              theme: ClubTheme.from(
                ClubConfig.fallback(),
                brightness: brightness,
              ),
              routerConfig: router,
            ),
          );
        },
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return container;
}

Future<void> _expectStateGolden(WidgetTester tester, String state) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      'goldens/admin_matches_state_${state}_$_goldenViewportId.png',
    ),
  );
}

final _workspace = AdminMatchesSnapshot.fromRaw(<Map<String, dynamic>>[
  _matchRow(),
  _matchRow(
    id: 'match-2',
    awayTeam: 'Police FC',
    status: 'live',
    liveMinute: 67,
    homeScore: 2,
    awayScore: 1,
    isOnSale: true,
  ),
]);

Map<String, dynamic> _matchRow({
  String id = 'match-1',
  String awayTeam = 'APR FC',
  String status = 'scheduled',
  int liveMinute = 0,
  int homeScore = 0,
  int awayScore = 0,
  bool isOnSale = false,
}) {
  return <String, dynamic>{
    'id': id,
    'partner_id': 'partner-1',
    'home_team': 'Rayon Sports',
    'away_team': awayTeam,
    'competition': 'National League',
    'venue': 'Kigali Pelé Stadium',
    'match_date': '2026-08-12',
    'kickoff_time': '18:00:00',
    'is_on_sale': isOnSale,
    'ticket_general_price': 3000,
    'ticket_vip_price': 30000,
    'capacity': 18000,
    'sold_count': 7200,
    'match_status': status,
    'home_score': homeScore,
    'away_score': awayScore,
    'live_minute': liveMinute,
    'match_summary': 'Confirmed fixture information.',
  };
}

class _Gateway implements AdminMatchesGateway {
  _Gateway(this.outcomes);

  final List<Object> outcomes;
  int loadCount = 0;

  @override
  Future<AdminMatchesSnapshot> load() async {
    final index = loadCount++;
    final outcome = outcomes[index.clamp(0, outcomes.length - 1)];
    if (outcome is Future<AdminMatchesSnapshot>) return outcome;
    if (outcome is AdminMatchesSnapshot) return outcome;
    throw outcome;
  }

  @override
  Future<void> save(AdminMatchDraft draft, {String? matchId}) async {}
}
