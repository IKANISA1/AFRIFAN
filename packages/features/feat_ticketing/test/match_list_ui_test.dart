import 'dart:async';

import 'package:club_data/club_data.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_ticketing/src/screens/match_list_screen.dart';
import 'package:feat_ticketing/src/ticketing_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';
import 'package:test_support/touch_target_audit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));

  test('ticket failures sanitize known backend categories', () {
    expect(
      TicketMatchesFailure.fromError(
        StateError('RLS permission denied for private-ticket-row-4482'),
      ).kind,
      TicketMatchesFailureKind.permissionDenied,
    );
    expect(
      TicketMatchesFailure.fromError(
        StateError('revision conflict for fixture secret-4482'),
      ).kind,
      TicketMatchesFailureKind.conflict,
    );
    expect(
      TicketMatchesFailure.fromError(
        TimeoutException('private ticket token 4482'),
      ).kind,
      TicketMatchesFailureKind.securityTimeout,
    );
    expect(
      TicketMatchesFailure.fromError(
        StateError('private ticket token 4482'),
      ).toString(),
      'TicketMatchesFailure(unknown)',
    );
  });

  testWidgets('matches the ticketing match list layout', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith(
          (ref) async => [
            ClubMatch(
              id: 'fixture-1',
              homeTeam: 'Rayon Sports',
              awayTeam: 'APR',
              competition: 'National League',
              venue: 'Amahoro Stadium',
              matchDate: DateTime(2099, 4, 18, 18),
              kickoffTime: '18:00',
              isOnSale: true,
              ticketGeneralPrice: 3000,
              ticketVipPrice: 12000,
              saleStartsAt: DateTime(2099, 4, 10, 9),
              capacity: 18000,
              soldCount: 5400,
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MatchListScreen), findsOneWidget);
    expectTapTargetsMeetMinimum(tester);
  });

  testWidgets('matches the ticketing loading layout', (tester) async {
    _setMobileSurface(tester);
    final pendingMatches = Completer<List<ClubMatch>>();
    addTearDown(() {
      if (!pendingMatches.isCompleted) {
        pendingMatches.complete(const <ClubMatch>[]);
      }
    });

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith((ref) => pendingMatches.future),
      ),
    );
    await tester.pump();

    expect(find.byType(MatchListScreen), findsOneWidget);
  });

  testWidgets('matches the ticketing empty layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith((ref) async => const <ClubMatch>[]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MatchListScreen), findsOneWidget);
  });

  testWidgets('renders the empty ticket journey in English', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith((ref) async => const <ClubMatch>[]),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('No upcoming ticketed fixtures'), findsOneWidget);
    expect(find.text('Refresh'), findsWidgets);
  });

  testWidgets('renders the empty ticket journey in English', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith((ref) async => const <ClubMatch>[]),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('No upcoming ticketed fixtures'), findsOneWidget);
    expect(find.text('Refresh'), findsWidgets);
  });

  testWidgets('matches the ticketing error layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith(
          (ref) async => throw StateError('ticketing unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MatchListScreen), findsOneWidget);
  });

  testWidgets('matches the ticketing match list at 200 percent text', (
    tester,
  ) async {
    _setMobileSurface(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _buildTicketingApp(
        ticketMatchesProvider.overrideWith((ref) async => [_fixture()]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MatchListScreen), findsOneWidget);
  });

  testWidgets('golden Tickets route loading state', (tester) async {
    final pendingMatches = Completer<List<ClubMatch>>();
    addTearDown(() {
      if (!pendingMatches.isCompleted) {
        pendingMatches.complete(const <ClubMatch>[]);
      }
    });
    await _pumpTicketStateGolden(
      tester,
      id: 'loading',
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) => pendingMatches.future,
      ),
      settle: false,
    );
  });

  testWidgets('golden Tickets route empty state', (tester) async {
    await _pumpTicketStateGolden(
      tester,
      id: 'empty',
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) async => const <ClubMatch>[],
      ),
    );
  });

  testWidgets('golden Tickets route error state', (tester) async {
    await _pumpTicketStateGolden(
      tester,
      id: 'error',
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) async => throw StateError('ticketing unavailable'),
      ),
    );
  });

  testWidgets('golden Tickets route offline state', (tester) async {
    await _pumpTicketStateGolden(
      tester,
      id: 'offline',
      online: false,
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) async => throw StateError('ticketing unavailable offline'),
      ),
    );
  });

  testWidgets('golden Tickets route large-text state', (tester) async {
    await _pumpTicketStateGolden(
      tester,
      id: 'large_text',
      size: const Size(320, 720),
      textScale: 2,
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) async => <ClubMatch>[_fixture()],
      ),
    );
  });

  testWidgets('golden Tickets route selected state', (tester) async {
    await _pumpTicketStateGolden(
      tester,
      id: 'selected',
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) async => <ClubMatch>[_pastFixture()],
      ),
      afterPump: (tester) async {
        await tester.tap(find.text('Past'));
        await tester.pumpAndSettle();
      },
    );

    final selectedTab = find.text('Past');
    final semantics = tester.getSemantics(selectedTab);
    expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);
  });

  testWidgets('golden Tickets route disabled state', (tester) async {
    await _pumpTicketStateGolden(
      tester,
      id: 'disabled',
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) async => <ClubMatch>[_soldOutFixture()],
      ),
    );

    final action = tester.widget<AfriButton>(
      find.byKey(const ValueKey<String>('ticket-action-fixture-sold-out')),
    );
    expect(action.enabled, isFalse);
    expect(action.label, 'Sold out');
  });

  testWidgets('golden Tickets route focused state', (tester) async {
    await _pumpTicketStateGolden(
      tester,
      id: 'focused',
      autofocusMatchId: 'fixture-1',
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) async => <ClubMatch>[_fixture()],
      ),
    );

    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
  });

  testWidgets('golden Tickets route pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpTicketStateGolden(
      tester,
      id: 'pressed',
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) async => <ClubMatch>[_fixture()],
      ),
      afterPump: (tester) async {
        heldGesture = await tester.startGesture(
          tester.getCenter(
            find.byKey(const ValueKey<String>('ticket-action-fixture-1')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      },
      afterCapture: () async {
        await heldGesture?.up();
      },
    );
  });

  testWidgets('golden Tickets route permission-denied state', (tester) async {
    await _pumpTicketStateGolden(
      tester,
      id: 'permission_denied',
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) async => throw const TicketMatchesFailure(
          TicketMatchesFailureKind.permissionDenied,
        ),
      ),
    );

    expect(find.text('Ticket access not available'), findsOneWidget);
    expect(find.textContaining('private-ticket-row-4482'), findsNothing);
  });

  testWidgets('golden Tickets route syncing state', (tester) async {
    final refreshCompleter = Completer<List<ClubMatch>>();
    var invocationCount = 0;
    addTearDown(() {
      if (!refreshCompleter.isCompleted) {
        refreshCompleter.complete(<ClubMatch>[_fixture()]);
      }
    });

    await _pumpTicketStateGolden(
      tester,
      id: 'syncing',
      ticketMatchesOverride: ticketMatchesProvider.overrideWith((ref) {
        invocationCount += 1;
        if (invocationCount == 1) {
          return Future<List<ClubMatch>>.value(<ClubMatch>[_fixture()]);
        }
        return refreshCompleter.future;
      }),
      afterPump: (tester) async {
        await tester.tap(find.byTooltip('Refresh matches'));
        await tester.pump();
        expect(find.text('Refreshing ticket inventory'), findsOneWidget);
      },
      afterCapture: () async {
        if (!refreshCompleter.isCompleted) {
          refreshCompleter.complete(<ClubMatch>[_fixture()]);
        }
        await tester.pump();
      },
    );
  });

  testWidgets('golden Tickets route conflict state', (tester) async {
    await _pumpTicketStateGolden(
      tester,
      id: 'conflict',
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) async =>
            throw const TicketMatchesFailure(TicketMatchesFailureKind.conflict),
      ),
    );

    expect(find.text('Ticket inventory changed'), findsOneWidget);
  });

  testWidgets('golden Tickets route security-timeout state', (tester) async {
    await _pumpTicketStateGolden(
      tester,
      id: 'security_timeout',
      ticketMatchesOverride: ticketMatchesProvider.overrideWith(
        (ref) async => throw const TicketMatchesFailure(
          TicketMatchesFailureKind.securityTimeout,
        ),
      ),
    );

    expect(find.text('Ticket security check timed out'), findsOneWidget);
  });
}

Widget _buildTicketingApp(
  Override ticketMatchesOverride, {
  Brightness brightness = Brightness.dark,
  Key? goldenKey,
  String? autofocusMatchId,
  Locale locale = const Locale('en'),
}) {
  final router = GoRouter(
    initialLocation: '/tickets',
    routes: [
      GoRoute(
        path: '/tickets',
        builder: (context, state) => RepaintBoundary(
          key: goldenKey,
          child: MatchListScreen(autofocusMatchId: autofocusMatchId),
        ),
      ),
      GoRoute(
        path: '/tickets/:matchId',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(
        (ref) => const UserProfile(
          id: 'user-1',
          clubId: '24',
          publicUserId: '483912',
        ),
      ),
      ticketMatchesOverride,
    ],
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AfriLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en')],
      theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
      routerConfig: router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return AfriLocalizationsScope(
          locale: locale,
          child: MediaQuery(
            data: mediaQuery.copyWith(disableAnimations: true),
            child: ClubConfigScope(
              config: ClubConfig.fallback(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    ),
  );
}

const _ticketStateGoldenPaths = <String, String>{
  'loading': 'goldens/tickets_state_loading_dark_390x844.png',
  'empty': 'goldens/tickets_state_empty_dark_390x844.png',
  'error': 'goldens/tickets_state_error_dark_390x844.png',
  'offline': 'goldens/tickets_state_offline_dark_390x844.png',
  'large_text': 'goldens/tickets_state_large_text_dark_320x720.png',
  'selected': 'goldens/tickets_state_selected_dark_390x844.png',
  'disabled': 'goldens/tickets_state_disabled_dark_390x844.png',
  'focused': 'goldens/tickets_state_focused_dark_390x844.png',
  'pressed': 'goldens/tickets_state_pressed_dark_390x844.png',
  'permission_denied':
      'goldens/tickets_state_permission_denied_dark_390x844.png',
  'syncing': 'goldens/tickets_state_syncing_dark_390x844.png',
  'conflict': 'goldens/tickets_state_conflict_dark_390x844.png',
  'security_timeout': 'goldens/tickets_state_security_timeout_dark_390x844.png',
};

Future<void> _pumpTicketStateGolden(
  WidgetTester tester, {
  required String id,
  required Override ticketMatchesOverride,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  bool online = true,
  String? autofocusMatchId,
  Future<void> Function(WidgetTester tester)? afterPump,
  Future<void> Function()? afterCapture,
}) async {
  _setGoldenSurface(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(Brightness.dark);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  ConnectivityService.setOnlineForTest(online);
  addTearDown(() => ConnectivityService.setOnlineForTest(true));

  await tester.pumpWidget(
    _buildTicketingApp(
      ticketMatchesOverride,
      goldenKey: const ValueKey<String>('tickets-state-golden'),
      autofocusMatchId: autofocusMatchId,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  await afterPump?.call(tester);

  expect(tester.takeException(), isNull);
  final goldenPath = _ticketStateGoldenPaths[id];
  expect(goldenPath, isNotNull, reason: 'Missing Tickets golden path for $id.');
  await expectLater(
    find.byKey(const ValueKey<String>('tickets-state-golden')),
    matchesGoldenFile(goldenPath!),
  );
  await afterCapture?.call();
}

void _setMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setGoldenSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: true,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

ClubMatch _fixture() {
  return ClubMatch(
    id: 'fixture-1',
    homeTeam: 'Rayon Sports',
    awayTeam: 'APR',
    competition: 'National League',
    venue: 'Amahoro Stadium',
    matchDate: DateTime(2099, 4, 18, 18),
    kickoffTime: '18:00',
    isOnSale: true,
    ticketGeneralPrice: 3000,
    ticketVipPrice: 12000,
    saleStartsAt: DateTime(2099, 4, 10, 9),
    capacity: 18000,
    soldCount: 5400,
  );
}

ClubMatch _pastFixture() {
  return ClubMatch(
    id: 'fixture-past-1',
    homeTeam: 'Rayon Sports',
    awayTeam: 'Police FC',
    competition: 'National League',
    venue: 'Kigali Pelé Stadium',
    matchDate: DateTime(2020, 4, 18, 18),
    kickoffTime: '18:00',
    isOnSale: false,
    ticketGeneralPrice: 3000,
    ticketVipPrice: 12000,
    saleStartsAt: DateTime(2020, 4, 10, 9),
    capacity: 18000,
    soldCount: 18000,
  );
}

ClubMatch _soldOutFixture() {
  return ClubMatch(
    id: 'fixture-sold-out',
    homeTeam: 'Rayon Sports',
    awayTeam: 'Kiyovu Sports',
    competition: 'National League',
    venue: 'Amahoro Stadium',
    matchDate: DateTime(2099, 5, 2, 18),
    kickoffTime: '18:00',
    isOnSale: true,
    ticketGeneralPrice: 3000,
    ticketVipPrice: 12000,
    saleStartsAt: DateTime(2099, 4, 20, 9),
    capacity: 18000,
    soldCount: 18000,
  );
}
