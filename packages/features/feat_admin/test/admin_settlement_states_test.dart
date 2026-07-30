import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/fixture_settlement_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _size = Size(390, 844);

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

  testWidgets('loading', (tester) async {
    final pending = Completer<AdminSettlementSnapshot>();
    await _pump(tester, _Gateway(<Object>[pending.future]), settle: false);
    expect(find.text('Loading settlement workspace'), findsOneWidget);
    await _golden(tester, 'loading');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('empty', (tester) async {
    await _pump(
      tester,
      _Gateway(const <Object>[AdminSettlementSnapshot.empty()]),
    );
    expect(find.text('No fixtures in this view'), findsOneWidget);
    await _golden(tester, 'empty');
  });

  testWidgets('error is private', (tester) async {
    await _pump(tester, _Gateway(<Object>[StateError('private-id')]));
    expect(find.text('Settlement workspace unavailable'), findsOneWidget);
    expect(find.textContaining('private-id'), findsNothing);
    await _golden(tester, 'error');
  });

  testWidgets('offline', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]), online: false);
    expect(find.text('Settlement workspace offline'), findsOneWidget);
    await _golden(tester, 'offline');
  });

  testWidgets('permission denied', (tester) async {
    await _pump(
      tester,
      _Gateway(const <Object>[
        AdminSettlementFailure(AdminSettlementFailureKind.permissionDenied),
      ]),
    );
    expect(find.text('Settlement access unavailable'), findsOneWidget);
    await _golden(tester, 'permission_denied');
  });

  testWidgets('disabled', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]), enabled: false);
    expect(find.text('Settlement management unavailable'), findsOneWidget);
    await _golden(tester, 'disabled');
  });

  testWidgets('selected finished filter', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]));
    await tester.tap(find.widgetWithText(AfriChoiceChip, 'FINISHED'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AfriChoiceChip>(
            find.widgetWithText(AfriChoiceChip, 'FINISHED'),
          )
          .selected,
      isTrue,
    );
    expect(find.text('SETTLED'), findsOneWidget);
    await _golden(tester, 'selected');
  });

  testWidgets('press and focus', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final previousStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pump(tester, _Gateway(<Object>[_workspace]), focusNode: node);
    final action = find.byKey(
      const ValueKey<String>(
        'admin-settlement-fixture-'
        '11111111-1111-4111-8111-111111111111',
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(action));
    await tester.pump(const Duration(milliseconds: 300));
    await _golden(tester, 'pressed');
    await gesture.cancel();
    node.requestFocus();
    await tester.pumpAndSettle();
    expect(node.hasFocus, isTrue);
    await _golden(tester, 'focused');
  });

  testWidgets('large text', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]), scale: 2);
    expect(tester.takeException(), isNull);
    await _golden(tester, 'large_text');
  });

  testWidgets('reduced motion', (tester) async {
    await _pump(tester, _Gateway(<Object>[_workspace]), reduced: true);
    expect(
      AfriMotion.reduceMotion(
        tester.element(find.byType(FixtureSettlementScreen)),
      ),
      isTrue,
    );
    await _golden(tester, 'reduced_motion');
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    testWidgets(brightness.name, (tester) async {
      await _pump(
        tester,
        _Gateway(<Object>[_workspace]),
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await _golden(tester, brightness.name);
    });
  }

  testWidgets('syncing retains fixtures', (tester) async {
    final pending = Completer<AdminSettlementSnapshot>();
    final container = await _pump(
      tester,
      _Gateway(<Object>[_workspace, pending.future]),
    );
    unawaited(container.read(adminSettlementProvider.notifier).refresh());
    await tester.pump();
    expect(find.text('Checking fixture results'), findsOneWidget);
    expect(
      container.read(adminSettlementProvider).requireValue.fixtures,
      hasLength(2),
    );
    await _golden(tester, 'syncing');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('conflict retains fixtures', (tester) async {
    final container = await _pump(
      tester,
      _Gateway(<Object>[
        _workspace,
        const AdminSettlementFailure(AdminSettlementFailureKind.conflict),
      ]),
    );
    await container.read(adminSettlementProvider.notifier).refresh();
    await tester.pump();
    expect(find.text('Fixture result changed'), findsOneWidget);
    expect(
      container.read(adminSettlementProvider).requireValue.fixtures,
      hasLength(2),
    );
    await _golden(tester, 'conflict');
  });

  testWidgets('timeout retains fixtures', (tester) async {
    final container = await _pump(
      tester,
      _Gateway(<Object>[_workspace, TimeoutException('private-id')]),
    );
    await container.read(adminSettlementProvider.notifier).refresh();
    await tester.pump();
    expect(find.text('Security check timed out'), findsOneWidget);
    expect(find.textContaining('private-id'), findsNothing);
    expect(
      container.read(adminSettlementProvider).requireValue.fixtures,
      hasLength(2),
    );
    await _golden(tester, 'security_timeout');
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  AdminSettlementGateway gateway, {
  bool enabled = true,
  bool online = true,
  bool settle = true,
  bool reduced = false,
  double scale = 1,
  Brightness brightness = Brightness.dark,
  FocusNode? focusNode,
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reduced,
        accessibleNavigation: reduced,
      );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  ConnectivityService.setOnlineForTest(online);
  ColorTokens.setBrightness(brightness);
  final router = GoRouter(
    initialLocation: '/admin/settle',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/settle',
        builder: (_, _) =>
            FixtureSettlementScreen(firstActionFocusNode: focusNode),
      ),
    ],
  );
  addTearDown(router.dispose);
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminSettlementGatewayProvider.overrideWithValue(gateway),
        adminSettlementEnabledProvider.overrideWithValue(enabled),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return ClubConfigScope(
            config: ClubConfig.fallback(),
            child: MaterialApp.router(
              theme: ClubTheme.from(
                ClubConfig.fallback(),
                brightness: brightness,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduced,
                  accessibleNavigation: reduced,
                ),
                child: child!,
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

Future<void> _golden(WidgetTester tester, String state) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/admin_settlement_state_${state}_390x844.png'),
);

const _scheduledFixtureId = '11111111-1111-4111-8111-111111111111';

final _workspace = AdminSettlementSnapshot.fromRaw(<Object>[
  _fixture(),
  _fixture(
    id: '55555555-5555-4555-8555-555555555555',
    status: 'finished',
    homeScore: 2,
    awayScore: 1,
  ),
]);

Map<String, dynamic> _fixture({
  String id = _scheduledFixtureId,
  String status = 'scheduled',
  int? homeScore,
  int? awayScore,
}) {
  return <String, dynamic>{
    'id': id,
    'status': status,
    'kickoff_at': '2026-08-12T16:00:00Z',
    'stage_name': 'Regular season',
    'group_name': null,
    'venue_city': 'Kigali',
    'home_score': homeScore,
    'away_score': awayScore,
    'home_team': const <String, dynamic>{
      'id': '22222222-2222-4222-8222-222222222222',
      'name': 'Rayon Sports',
      'short_name': 'RAY',
    },
    'away_team': const <String, dynamic>{
      'id': '33333333-3333-4333-8333-333333333333',
      'name': 'APR FC',
      'short_name': 'APR',
    },
    'competition': const <String, dynamic>{
      'id': '44444444-4444-4444-8444-444444444444',
      'name': 'Rwanda Premier League',
      'short_name': 'RPL',
    },
  };
}

final _receipt = AdminSettlementReceipt.fromRaw(const <String, dynamic>{
  'status': 'success',
  'fixture_id': _scheduledFixtureId,
  'score': '3-1',
  'markets_settled': 12,
  'total_won': 7,
  'total_lost': 5,
});

class _Gateway implements AdminSettlementGateway {
  _Gateway(this.outcomes);

  final List<Object> outcomes;
  var loadCount = 0;

  @override
  Future<AdminSettlementSnapshot> load() async {
    final outcome = outcomes[loadCount.clamp(0, outcomes.length - 1)];
    loadCount += 1;
    if (outcome is Future<AdminSettlementSnapshot>) return outcome;
    if (outcome is AdminSettlementSnapshot) return outcome;
    throw outcome;
  }

  @override
  Future<AdminSettlementReceipt> settle(AdminSettlementDraft draft) async {
    return _receipt;
  }
}
