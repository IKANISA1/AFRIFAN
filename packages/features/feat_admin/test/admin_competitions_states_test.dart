import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/competition_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final pending = Completer<AdminCompetitionsSnapshot>();
    await _pumpCompetitions(
      tester,
      gateway: _Gateway(<Object>[pending.future]),
      settle: false,
    );

    expect(find.text('Loading competitions'), findsOneWidget);
    expect(find.text('NATIONAL LEAGUE'), findsNothing);
    await _expectStateGolden(tester, 'loading');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('renders a confirmed empty workspace', (tester) async {
    await _pumpCompetitions(
      tester,
      gateway: _Gateway(const <Object>[AdminCompetitionsSnapshot.empty()]),
    );

    expect(find.text('No competitions configured'), findsOneWidget);
    expect(find.text('Add competition'), findsOneWidget);
    await _expectStateGolden(tester, 'empty');
  });

  testWidgets('renders a privacy-safe unknown error', (tester) async {
    await _pumpCompetitions(
      tester,
      gateway: _Gateway(<Object>[
        StateError('provider row private-account-991 failed'),
      ]),
    );

    expect(find.text('Competition workspace unavailable'), findsOneWidget);
    expect(find.textContaining('private-account-991'), findsNothing);
    await _expectStateGolden(tester, 'error');
  });

  testWidgets('renders offline without private records', (tester) async {
    await _pumpCompetitions(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      online: false,
    );

    expect(find.text('Competition workspace offline'), findsOneWidget);
    expect(find.text('NATIONAL LEAGUE'), findsNothing);
    await _expectStateGolden(tester, 'offline');
  });

  testWidgets('permission denial clears records and controls', (tester) async {
    await _pumpCompetitions(
      tester,
      gateway: _Gateway(const <Object>[
        AdminCompetitionsFailure(AdminCompetitionsFailureKind.permissionDenied),
      ]),
    );

    expect(find.text('Competition access unavailable'), findsOneWidget);
    expect(find.text('NATIONAL LEAGUE'), findsNothing);
    expect(find.text('SEASONS'), findsNothing);
    await _expectStateGolden(tester, 'permission_denied');
  });

  testWidgets('renders the feature-disabled state', (tester) async {
    await _pumpCompetitions(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      enabled: false,
    );

    expect(find.text('Competition management unavailable'), findsOneWidget);
    expect(
      find.textContaining('disabled for this controlled build'),
      findsOneWidget,
    );
    expect(find.text('NATIONAL LEAGUE'), findsNothing);
    await _expectStateGolden(tester, 'disabled');
  });

  testWidgets('selected filter exposes current selection semantics', (
    tester,
  ) async {
    await _pumpCompetitions(tester, gateway: _Gateway(<Object>[_workspace]));

    await tester.tap(find.text('EUROPE'));
    await tester.pumpAndSettle();

    expect(find.text('No competitions match'), findsOneWidget);
    final selected = tester.widget<AfriChoiceChip>(
      find.widgetWithText(AfriChoiceChip, 'EUROPE'),
    );
    expect(selected.selected, isTrue);
    await _expectStateGolden(tester, 'selected');
  });

  testWidgets('primary action supports held press and keyboard focus', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'competition-seasons');
    addTearDown(focusNode.dispose);
    final previousStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpCompetitions(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      firstActionFocusNode: focusNode,
    );
    final action = find.byKey(
      const ValueKey<String>('admin-competitions-seasons-competition-1'),
    );
    final button = find.descendant(
      of: action,
      matching: find.byType(TextButton),
    );

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 100));
    await _expectStateGolden(tester, 'pressed');
    await gesture.cancel();
    await tester.pumpAndSettle();

    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    await _expectStateGolden(tester, 'focused');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('2025/2026'), findsOneWidget);
  });

  testWidgets('supports 200 percent text without horizontal overflow', (
    tester,
  ) async {
    await _pumpCompetitions(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
    expect(
      scrollable.axisDirection,
      anyOf(AxisDirection.down, AxisDirection.up),
    );
    await _expectStateGolden(tester, 'large_text');
  });

  testWidgets('respects reduced motion', (tester) async {
    await _pumpCompetitions(
      tester,
      gateway: _Gateway(<Object>[_workspace]),
      reduceMotion: true,
    );

    final context = tester.element(find.byType(CompetitionManagerScreen));
    expect(AfriMotion.reduceMotion(context), isTrue);
    expect(tester.takeException(), isNull);
    await _expectStateGolden(tester, 'reduced_motion');
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    testWidgets('renders the ${brightness.name} theme', (tester) async {
      await _pumpCompetitions(
        tester,
        gateway: _Gateway(<Object>[_workspace]),
        brightness: brightness,
      );

      expect(find.text('COMPETITIONS'), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.byType(CompetitionManagerScreen)),
        ).brightness,
        brightness,
      );
      expect(tester.takeException(), isNull);
      await _expectStateGolden(tester, brightness.name);
    });
  }

  testWidgets('syncing retains confirmed records and pauses actions', (
    tester,
  ) async {
    final pending = Completer<AdminCompetitionsSnapshot>();
    final gateway = _Gateway(<Object>[_workspace, pending.future]);
    final container = await _pumpCompetitions(tester, gateway: gateway);

    unawaited(container.read(adminCompetitionsProvider.notifier).refresh());
    await tester.pump();

    expect(find.text('Refreshing competitions'), findsOneWidget);
    expect(find.text('National League'), findsOneWidget);
    expect(
      tester
          .widget<AfriTextIconButton>(
            find.byKey(
              const ValueKey<String>(
                'admin-competitions-seasons-competition-1',
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    await _expectStateGolden(tester, 'syncing');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('conflict retains records and explains recovery', (tester) async {
    final gateway = _Gateway(<Object>[
      _workspace,
      const AdminCompetitionsFailure(AdminCompetitionsFailureKind.conflict),
    ]);
    final container = await _pumpCompetitions(tester, gateway: gateway);

    await container.read(adminCompetitionsProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Competition data changed'), findsOneWidget);
    expect(find.text('National League'), findsOneWidget);
    expect(find.textContaining('Actions are paused'), findsOneWidget);
    await _expectStateGolden(tester, 'conflict');
  });

  testWidgets('security timeout retains records and hides diagnostics', (
    tester,
  ) async {
    final gateway = _Gateway(<Object>[
      _workspace,
      TimeoutException('private-account-991 timed out'),
    ]);
    final container = await _pumpCompetitions(tester, gateway: gateway);

    await container.read(adminCompetitionsProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Security check timed out'), findsOneWidget);
    expect(find.text('National League'), findsOneWidget);
    expect(find.textContaining('private-account-991'), findsNothing);
    await _expectStateGolden(tester, 'security_timeout');
  });
}

Future<ProviderContainer> _pumpCompetitions(
  WidgetTester tester, {
  required AdminCompetitionsGateway gateway,
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
    initialLocation: '/admin/competitions',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/competitions',
        builder: (_, _) => CompetitionManagerScreen(
          firstActionFocusNode: firstActionFocusNode,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminCompetitionsGatewayProvider.overrideWithValue(gateway),
        adminCompetitionsEnabledProvider.overrideWithValue(enabled),
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
      'goldens/admin_competitions_state_${state}_$_goldenViewportId.png',
    ),
  );
}

final _workspace = AdminCompetitionsSnapshot.fromRawCollections(
  <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'competition-1',
      'slug': 'national-league',
      'name': 'National League',
      'short_name': 'NL',
      'competition_kind': 'league',
      'region': 'africa',
      'country_code': 'RW',
      'country_name': 'Rwanda',
      'organizer': 'League Authority',
      'gender': 'men',
      'format_notes': 'Home and away schedule with controlled match data.',
      'is_active': true,
    },
  ],
  <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'season-1',
      'competition_id': 'competition-1',
      'slug': 'national-league-2025-2026',
      'label': '2025/2026',
      'year_start': 2025,
      'year_end': 2026,
      'status': 'active',
      'is_active': true,
    },
  ],
);

class _Gateway implements AdminCompetitionsGateway {
  _Gateway(this.outcomes);

  final List<Object> outcomes;
  int loadCount = 0;

  @override
  Future<AdminCompetitionsSnapshot> load() async {
    final index = loadCount++;
    final outcome = outcomes[index.clamp(0, outcomes.length - 1)];
    if (outcome is Future<AdminCompetitionsSnapshot>) return outcome;
    if (outcome is AdminCompetitionsSnapshot) return outcome;
    throw outcome;
  }

  @override
  Future<void> createSeason(Map<String, dynamic> payload) async {}

  @override
  Future<void> saveCompetition(
    Map<String, dynamic> payload, {
    String? competitionId,
  }) async {}

  @override
  Future<void> setCompetitionActive(
    String competitionId,
    bool isActive,
  ) async {}

  @override
  Future<void> setSeasonActive(String seasonId, bool isActive) async {}
}
